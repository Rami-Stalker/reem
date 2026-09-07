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
  ) {}

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

    const action = await this.prisma.$transaction(async (tx) => {
      await tx.commerceContent.update({
        where: { id: contentId },
        data: {
          status: CommerceContentStatus.PUBLISHED,
          moderationStatus: CommerceContentModerationStatus.APPROVED,
          removedAt: null,
          removedById: null,
          removalReason: null,
        },
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
        status_to: CommerceContentStatus.PUBLISHED,
        reason: trimmed,
      },
    });

    this.events.emit(AppEvent.ContentReinstated, {
      authorId: content.authorId,
      contentId,
      contentType: content.contentType,
      reason: trimmed,
      moderationActionId: action.id,
    });

    return { reinstated: true };
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
      select: { id: true, authorId: true },
    });
    if (!content) throw new NotFoundException('Content not found');

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
      select: { id: true },
    });
    if (!comment) throw new NotFoundException('Comment not found');

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
      ...(query.status ? { status: query.status } : {}),
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
        where: { reportsCount: { gt: 0 }, status: { not: CommerceContentStatus.REMOVED } },
      }),
    ]);

    return {
      items,
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
