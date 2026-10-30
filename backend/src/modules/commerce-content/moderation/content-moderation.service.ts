import {
  BadRequestException,
  ForbiddenException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { EventEmitter2 } from '@nestjs/event-emitter';
import {
  AuditSeverity,
  CommerceAuthorKind,
  CommerceContentCommentStatus,
  CommerceContentModerationStatus,
  CommerceContentStatus,
  ModerationStatus,
  Prisma,
  UserRole,
} from '@prisma/client';
import { PrismaService } from '../../../prisma/prisma.service';
import { AuthUser } from '../../../common/decorators/current-user.decorator';
import { buildMeta, PaginationDto } from '../../../common/dto/pagination.dto';
import { AppEvent } from '../../../common/events/app-events';
import { AuditService } from '../../auth/audit.service';
import { CacheService } from '../../../common/cache/cache.service';
import { commerceContentInclude } from '../commerce-content.repository';

const MODERATOR_ROLES: UserRole[] = [
  UserRole.SUPER_ADMIN,
  UserRole.OPERATIONS_ADMIN,
  UserRole.CONTENT_MODERATOR,
  UserRole.ADMIN,
];

/** Reasons a woman can pick from when reporting. Free text goes in `detail`. */
export const CONTENT_REPORT_REASONS = [
  'immodest',
  'not_the_product',
  'stolen_photo',
  'spam',
  'harassment',
  'counterfeit',
  'other',
] as const;

export type ContentReportReason = (typeof CONTENT_REPORT_REASONS)[number];

/** Same prefix as the anonymous feed cache in `ContentFeedService`. */
const FEED_CACHE_PREFIX = 'commerce-content:feed';

/** The `reason` prefix of a case the word screen opened, not a person. */
export const AUTO_FLAG_REASON_PREFIX = 'auto_flag';

const DEFAULT_DISMISS_NOTE = 'Reviewed by a moderator: no violation found';

/**
 * Taking content down, and the trail that proves who did it and why.
 *
 * Three properties the requirement turns on, all enforced here rather than by
 * convention:
 *
 *   1. **No silent removal.** A takedown writes a
 *      `CommerceContentModerationAction` (reason, from-status, to-status,
 *      moderator), an `AuditLog` at WARNING, and a notification to the woman
 *      who published it. The reason is not optional — the DTO demands it and a
 *      CHECK constraint on the table refuses a row without one.
 *   2. **Nothing is destroyed.** `REMOVED` is a status, not a `DELETE`. The
 *      row, its media, its comments and its history all survive, so an appeal
 *      or an incident review has something to read.
 *   3. **It is reversible.** `reinstate` exists and is audited the same way,
 *      because a moderator acting on a bad report needs a way back that does
 *      not involve the woman re-uploading her photographs.
 */
@Injectable()
export class ContentModerationService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly audit: AuditService,
    private readonly events: EventEmitter2,
    private readonly cache: CacheService,
  ) {}

  /**
   * A takedown has to leave every surface at once. The signed-out home feed is
   * cached for a few seconds, and a removed post must not outlive the decision
   * there either.
   */
  private invalidateFeeds() {
    this.cache.invalidate(FEED_CACHE_PREFIX);
  }

  private assertModerator(user: AuthUser) {
    if (!MODERATOR_ROLES.includes(user.role)) {
      throw new ForbiddenException('Only content moderators can review content');
    }
  }

  // ── Takedown ──────────────────────────────────────────────────────────────

  async remove(user: AuthUser, contentId: string, reason: string) {
    this.assertModerator(user);

    const trimmed = reason?.trim() ?? '';
    // Belt and braces with the DTO and the database CHECK. Three layers,
    // because "the admin must give a reason" is the requirement, and a rule
    // enforced in only one of the three is a rule with two ways around it.
    if (trimmed.length < 10) {
      throw new BadRequestException('REMOVAL_REASON_REQUIRED');
    }

    const content = await this.prisma.commerceContent.findUnique({
      where: { id: contentId },
      select: {
        id: true,
        authorId: true,
        contentType: true,
        status: true,
        moderationStatus: true,
      },
    });
    if (!content) throw new NotFoundException('Content not found');
    if (content.status === CommerceContentStatus.REMOVED) {
      throw new BadRequestException('ALREADY_REMOVED');
    }
    // She already deleted it, so nobody can see it. Removing it on top would
    // record `DELETED` as the status to go back to, and a later reinstate
    // would publish a piece its author chose to take down.
    if (content.status === CommerceContentStatus.DELETED) {
      throw new BadRequestException('ALREADY_DELETED_BY_AUTHOR');
    }

    const action = await this.prisma.$transaction(async (tx) => {
      await tx.commerceContent.update({
        where: { id: contentId },
        data: {
          status: CommerceContentStatus.REMOVED,
          moderationStatus: CommerceContentModerationStatus.REJECTED,
          removedAt: new Date(),
          removedById: user.id,
          removalReason: trimmed,
        },
      });
      // Every open report about it is answered by this decision.
      await tx.moderationCase.updateMany({
        where: { targetType: 'commerce_content', targetId: contentId, status: ModerationStatus.OPEN },
        data: { status: ModerationStatus.APPROVED, resolution: trimmed, assignedTo: user.id },
      });
      return tx.commerceContentModerationAction.create({
        data: {
          contentId,
          moderatorId: user.id,
          fromStatus: content.moderationStatus,
          toStatus: CommerceContentModerationStatus.REJECTED,
          reason: trimmed,
          metadata: { previous_status: content.status } as Prisma.InputJsonValue,
        },
      });
    });

    // The console audits its writes. `CommerceContentService.moderate` did not,
    // which meant the one administrative action with the most obvious need for
    // an incident trail was the one without it.
    await this.audit.record({
      actorId: user.id,
      action: 'content_removed',
      category: 'admin',
      outcome: 'success',
      severity: AuditSeverity.WARNING,
      metadata: {
        content_id: contentId,
        content_type: content.contentType,
        author_id: content.authorId,
        status_from: content.status,
        status_to: CommerceContentStatus.REMOVED,
        reason: trimmed,
      },
    });

    this.invalidateFeeds();

    this.events.emit(AppEvent.ContentRemoved, {
      authorId: content.authorId,
      contentId,
      contentType: content.contentType,
      reason: trimmed,
      moderationActionId: action.id,
    });

    return { removed: true, reason: trimmed, moderation_action_id: action.id };
  }

  async reinstate(user: AuthUser, contentId: string, reason: string) {
    this.assertModerator(user);
    const trimmed = reason?.trim() ?? '';
    if (trimmed.length < 10) {
      throw new BadRequestException('REINSTATEMENT_REASON_REQUIRED');
    }

    const content = await this.prisma.commerceContent.findUnique({
      where: { id: contentId },
      select: { id: true, authorId: true, contentType: true, status: true, moderationStatus: true },
    });
    if (!content) throw new NotFoundException('Content not found');
    if (content.status !== CommerceContentStatus.REMOVED) {
      throw new BadRequestException('NOT_REMOVED');
    }

    const restored = await this.statusBeforeRemoval(contentId);

    const action = await this.prisma.$transaction(async (tx) => {
      await tx.commerceContent.update({
        where: { id: contentId },
        data: {
          status: restored,
          moderationStatus: CommerceContentModerationStatus.APPROVED,
          removedAt: null,
          removedById: null,
          removalReason: null,
          // The reports were answered — wrongly — by the removal. Leaving the
          // count would put the piece straight back at the top of the queue.
          reportsCount: 0,
        },
      });
      await tx.moderationCase.updateMany({
        where: { targetType: 'commerce_content', targetId: contentId, status: ModerationStatus.OPEN },
        data: { status: ModerationStatus.REJECTED, resolution: trimmed, assignedTo: user.id },
      });
      return tx.commerceContentModerationAction.create({
        data: {
          contentId,
          moderatorId: user.id,
          fromStatus: content.moderationStatus,
          toStatus: CommerceContentModerationStatus.APPROVED,
          reason: trimmed,
        },
      });
    });

    await this.audit.record({
      actorId: user.id,
      action: 'content_reinstated',
      category: 'admin',
      outcome: 'success',
      severity: AuditSeverity.WARNING,
      metadata: {
        content_id: contentId,
        author_id: content.authorId,
        status_from: CommerceContentStatus.REMOVED,
        status_to: restored,
        reason: trimmed,
      },
    });

    this.invalidateFeeds();

    this.events.emit(AppEvent.ContentReinstated, {
      authorId: content.authorId,
      contentId,
      contentType: content.contentType,
      reason: trimmed,
      moderationActionId: action.id,
    });

    return { reinstated: true, status: restored };
  }

  /**
   * Keep it: the reports against a piece were looked at and it stays up.
   *
   * Without this decision a reported post could only leave the queue by being
   * removed, so a moderator who disagreed with a report had no way to say so
   * and the "reported" list only ever grew.
   */
  async dismissReports(user: AuthUser, contentId: string, note?: string) {
    this.assertModerator(user);
    const trimmed = note?.trim() || DEFAULT_DISMISS_NOTE;
    if (trimmed.length < 10) {
      throw new BadRequestException('DISMISS_NOTE_TOO_SHORT');
    }

    const content = await this.prisma.commerceContent.findUnique({
      where: { id: contentId },
      select: { id: true, authorId: true, status: true, moderationStatus: true, reportsCount: true },
    });
    if (!content) throw new NotFoundException('Content not found');
    if (content.status === CommerceContentStatus.REMOVED) {
      throw new BadRequestException('ALREADY_REMOVED');
    }

    const closed = await this.prisma.$transaction(async (tx) => {
      const cases = await tx.moderationCase.updateMany({
        where: { targetType: 'commerce_content', targetId: contentId, status: ModerationStatus.OPEN },
        data: { status: ModerationStatus.REJECTED, resolution: trimmed, assignedTo: user.id },
      });
      await tx.commerceContent.update({
        where: { id: contentId },
        data: { reportsCount: 0 },
      });
      await tx.commerceContentModerationAction.create({
        data: {
          contentId,
          moderatorId: user.id,
          fromStatus: content.moderationStatus,
          toStatus: content.moderationStatus,
          reason: trimmed,
          metadata: {
            decision: 'reports_dismissed',
            reports_count: content.reportsCount,
          } as Prisma.InputJsonValue,
        },
      });
      return cases.count;
    });

    await this.audit.record({
      actorId: user.id,
      action: 'content_reports_dismissed',
      category: 'admin',
      outcome: 'success',
      severity: AuditSeverity.INFO,
      metadata: {
        content_id: contentId,
        author_id: content.authorId,
        cases_closed: closed,
        reason: trimmed,
      },
    });

    return { dismissed: true, cases_closed: closed };
  }

  /**
   * The word screen's report: the piece is already live, and this puts it in
   * front of a moderator rather than holding it back.
   *
   * One open automatic case per piece — an author editing the same caption
   * three times is one thing to look at, not three.
   */
  async autoFlag(contentId: string, terms: string[]) {
    if (terms.length === 0) return;
    const existing = await this.prisma.moderationCase.findFirst({
      where: {
        targetType: 'commerce_content',
        targetId: contentId,
        reporterId: null,
        status: ModerationStatus.OPEN,
        reason: { startsWith: AUTO_FLAG_REASON_PREFIX },
      },
      select: { id: true },
    });
    if (existing) return;

    await this.prisma.$transaction([
      this.prisma.moderationCase.create({
        data: {
          targetType: 'commerce_content',
          targetId: contentId,
          reporterId: null,
          reason: `${AUTO_FLAG_REASON_PREFIX}: ${terms.join(', ')}`,
        },
      }),
      this.prisma.commerceContent.update({
        where: { id: contentId },
        data: { reportsCount: { increment: 1 } },
      }),
    ]);
  }

  /**
   * Where a reinstated piece goes back to.
   *
   * Not always PUBLISHED. A draft taken down while it was a draft comes back
   * a draft, an archived piece comes back archived, and a story whose day
   * ran out while it was down comes back expired — reinstating it as
   * PUBLISHED would have put a removed draft on the feed she never chose to
   * publish, or a two-day-old story back in the tray.
   */
  private async statusBeforeRemoval(
    contentId: string,
  ): Promise<CommerceContentStatus> {
    const [lastRemoval, content] = await Promise.all([
      this.prisma.commerceContentModerationAction.findFirst({
        where: {
          contentId,
          toStatus: CommerceContentModerationStatus.REJECTED,
        },
        orderBy: { createdAt: 'desc' },
        select: { metadata: true },
      }),
      this.prisma.commerceContent.findUnique({
        where: { id: contentId },
        select: { expiresAt: true, publishedAt: true },
      }),
    ]);

    const metadata = lastRemoval?.metadata;
    const recorded =
      metadata && typeof metadata === 'object' && !Array.isArray(metadata)
        ? (metadata as Record<string, unknown>).previous_status
        : undefined;
    const valid = Object.values(CommerceContentStatus) as string[];
    let status =
      typeof recorded === 'string' &&
      valid.includes(recorded) &&
      recorded !== CommerceContentStatus.REMOVED &&
      recorded !== CommerceContentStatus.DELETED
        ? (recorded as CommerceContentStatus)
        : content?.publishedAt
          ? CommerceContentStatus.PUBLISHED
          : CommerceContentStatus.DRAFT;

    if (
      status === CommerceContentStatus.PUBLISHED &&
      content?.expiresAt &&
      content.expiresAt <= new Date()
    ) {
      status = CommerceContentStatus.EXPIRED;
    }
    return status;
  }

  // ── Reports ───────────────────────────────────────────────────────────────

  /**
   * A woman reports a piece of content.
   *
   * Writes a `ModerationCase` — the polymorphic table that has had an admin
   * queue at `GET|PATCH /admin/moderation` since before this feature and, until
   * now, no writer at all. Adding a fourth report table beside it would have
   * been the easy mistake.
   */
  async report(
    user: AuthUser,
    contentId: string,
    reason: ContentReportReason,
    detail?: string,
  ) {
    const content = await this.prisma.commerceContent.findUnique({
      where: { id: contentId },
      select: { id: true, authorId: true, status: true },
    });
    if (!content) throw new NotFoundException('Content not found');
    // Reporting her own piece is not a report — it would put her own post
    // at the top of the moderators' queue. She deletes it instead.
    if (content.authorId === user.id) {
      throw new BadRequestException('CANNOT_REPORT_OWN_CONTENT');
    }
    // Already taken down: the report has been answered.
    if (content.status === CommerceContentStatus.REMOVED) {
      return { reported: true, already: true };
    }

    const existing = await this.prisma.moderationCase.findFirst({
      where: {
        targetType: 'commerce_content',
        targetId: contentId,
        reporterId: user.id,
        status: ModerationStatus.OPEN,
      },
      select: { id: true },
    });
    // Reporting twice is not two reports. Without this a single upset viewer
    // could push anything to the top of the queue by tapping repeatedly.
    if (existing) return { reported: true, already: true };

    await this.prisma.$transaction([
      this.prisma.moderationCase.create({
        data: {
          targetType: 'commerce_content',
          targetId: contentId,
          reporterId: user.id,
          reason: detail?.trim() ? `${reason}: ${detail.trim()}` : reason,
        },
      }),
      this.prisma.commerceContent.update({
        where: { id: contentId },
        data: { reportsCount: { increment: 1 } },
      }),
    ]);

    return { reported: true, already: false };
  }

  async reportComment(
    user: AuthUser,
    commentId: string,
    reason: ContentReportReason,
    detail?: string,
  ) {
    const comment = await this.prisma.commerceContentComment.findUnique({
      where: { id: commentId },
      select: { id: true, userId: true },
    });
    if (!comment) throw new NotFoundException('Comment not found');
    if (comment.userId === user.id) {
      throw new BadRequestException('CANNOT_REPORT_OWN_CONTENT');
    }

    const existing = await this.prisma.moderationCase.findFirst({
      where: {
        targetType: 'commerce_content_comment',
        targetId: commentId,
        reporterId: user.id,
        status: ModerationStatus.OPEN,
      },
      select: { id: true },
    });
    if (existing) return { reported: true, already: true };

    await this.prisma.moderationCase.create({
      data: {
        targetType: 'commerce_content_comment',
        targetId: commentId,
        reporterId: user.id,
        reason: detail?.trim() ? `${reason}: ${detail.trim()}` : reason,
      },
    });
    return { reported: true, already: false };
  }

  // ── The console's queue ───────────────────────────────────────────────────

  /**
   * Everything published, for a moderator.
   *
   * Deliberately unfiltered by visibility: the whole point of the screen is
   * that a moderator sees what a shopper cannot, including a private woman's
   * page and content already taken down.
   */
  async list(
    user: AuthUser,
    query: {
      page: number;
      limit: number;
      skip: number;
      content_type?: string;
      author_kind?: CommerceAuthorKind;
      status?: CommerceContentStatus;
      reported?: boolean;
      q?: string;
    },
  ) {
    this.assertModerator(user);

    const where: Prisma.CommerceContentWhereInput = {
      ...(query.content_type ? { contentType: query.content_type } : {}),
      ...(query.author_kind ? { authorKind: query.author_kind } : {}),
      // Her own deletions are hers: nobody can see them, there is nothing to
      // moderate, and listing them only puts a «remove» button on a ghost.
      // The reported queue is what is still waiting on a decision, so a piece
      // already taken down leaves it.
      ...(query.status
        ? { status: query.status }
        : query.reported
          ? { status: { notIn: [CommerceContentStatus.REMOVED, CommerceContentStatus.DELETED] } }
          : { status: { not: CommerceContentStatus.DELETED } }),
      ...(query.reported ? { reportsCount: { gt: 0 } } : {}),
      ...(query.q
        ? {
            OR: [
              { title: { contains: query.q, mode: 'insensitive' } },
              { body: { contains: query.q, mode: 'insensitive' } },
              { author: { username: { contains: query.q, mode: 'insensitive' } } },
            ],
          }
        : {}),
    };

    const [items, total, pending] = await Promise.all([
      this.prisma.commerceContent.findMany({
        where,
        // Reported first, then newest. A queue sorted only by time buries the
        // thing somebody is waiting on.
        orderBy: [{ reportsCount: 'desc' }, { createdAt: 'desc' }],
        skip: query.skip,
        take: query.limit,
        include: commerceContentInclude,
      }),
      this.prisma.commerceContent.count({ where }),
      this.prisma.commerceContent.count({
        where: {
          reportsCount: { gt: 0 },
          status: { notIn: [CommerceContentStatus.REMOVED, CommerceContentStatus.DELETED] },
        },
      }),
    ]);

    // What each row is in the queue for, in one query for the page: the open
    // reports' reasons, newest first, and whether the word screen opened one.
    const openCases = items.length
      ? await this.prisma.moderationCase.findMany({
          where: {
            targetType: 'commerce_content',
            targetId: { in: items.map((item) => item.id) },
            status: ModerationStatus.OPEN,
          },
          orderBy: { createdAt: 'desc' },
          select: { targetId: true, reason: true, reporterId: true },
        })
      : [];
    const reports = new Map<string, { reasons: string[]; autoFlagged: boolean }>();
    for (const row of openCases) {
      const entry = reports.get(row.targetId) ?? { reasons: [], autoFlagged: false };
      if (row.reporterId === null && row.reason.startsWith(AUTO_FLAG_REASON_PREFIX)) {
        entry.autoFlagged = true;
      }
      if (entry.reasons.length < 5) entry.reasons.push(row.reason);
      reports.set(row.targetId, entry);
    }

    return {
      items,
      reports,
      total,
      pending,
      meta: buildMeta(query.page, query.limit, total, items.length),
    };
  }

  /** The open report queue, newest first. */
  async reports(user: AuthUser, page: PaginationDto) {
    this.assertModerator(user);
    const where = {
      targetType: { in: ['commerce_content', 'commerce_content_comment'] },
      status: ModerationStatus.OPEN,
    };
    const [items, total] = await Promise.all([
      this.prisma.moderationCase.findMany({
        where,
        orderBy: { createdAt: 'desc' },
        skip: page.skip,
        take: page.limit,
      }),
      this.prisma.moderationCase.count({ where }),
    ]);
    return { items, total, meta: buildMeta(page.page, page.limit, total, items.length) };
  }

  /** The trail for one piece — every decision anybody has made about it. */
  async history(user: AuthUser, contentId: string) {
    this.assertModerator(user);
    return this.prisma.commerceContentModerationAction.findMany({
      where: { contentId },
      orderBy: { createdAt: 'desc' },
      include: { moderator: { select: { id: true, name: true, username: true } } },
    });
  }

  /** A moderator hiding a comment. Reason mandatory, same as content. */
  async removeComment(user: AuthUser, commentId: string, reason: string) {
    this.assertModerator(user);
    const trimmed = reason?.trim() ?? '';
    if (trimmed.length < 10) {
      throw new BadRequestException('REMOVAL_REASON_REQUIRED');
    }

    const comment = await this.prisma.commerceContentComment.findUnique({
      where: { id: commentId },
      select: { id: true, userId: true, contentId: true, parentId: true, status: true },
    });
    if (!comment) throw new NotFoundException('Comment not found');
    if (comment.status !== CommerceContentCommentStatus.VISIBLE) {
      return { removed: true, already: true };
    }

    await this.prisma.$transaction([
      this.prisma.commerceContentComment.update({
        where: { id: commentId },
        data: {
          status: CommerceContentCommentStatus.REMOVED,
          removedAt: new Date(),
          removedById: user.id,
          removalReason: trimmed,
        },
      }),
      this.prisma.commerceContent.update({
        where: { id: comment.contentId },
        data: { repliesCount: { decrement: 1 } },
      }),
      this.prisma.moderationCase.updateMany({
        where: {
          targetType: 'commerce_content_comment',
          targetId: commentId,
          status: ModerationStatus.OPEN,
        },
        data: { status: ModerationStatus.APPROVED, resolution: trimmed, assignedTo: user.id },
      }),
    ]);

    await this.audit.record({
      actorId: user.id,
      action: 'content_comment_removed',
      category: 'admin',
      outcome: 'success',
      severity: AuditSeverity.WARNING,
      metadata: {
        comment_id: commentId,
        content_id: comment.contentId,
        author_id: comment.userId,
        reason: trimmed,
      },
    });

    return { removed: true, already: false };
  }
}
