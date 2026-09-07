import {
  BadRequestException,
  ForbiddenException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { EventEmitter2 } from '@nestjs/event-emitter';
import {
  CommerceContentAnalyticsEventType,
  CommerceContentCommentStatus,
  CommerceContentReactionKind,
  CommerceContentStatus,
  Prisma,
} from '@prisma/client';
import { PrismaService } from '../../../prisma/prisma.service';
import { AuthUser } from '../../../common/decorators/current-user.decorator';
import { buildMeta, PaginationDto } from '../../../common/dto/pagination.dto';
import { AppEvent } from '../../../common/events/app-events';
import { assertCanManage } from '../../../common/authz';
import { ContentAttributionService } from '../attribution/content-attribution.service';

/**
 * Everything a woman *does* to a piece of content: likes it, saves it,
 * comments, replies, adds it to her own page.
 *
 * ## The counters have exactly one writer
 *
 * `commerce_contents` carries `reactions_count`, `saves_count`,
 * `replies_count` and `shares_count`, and `POST /content/:id/events` used to
 * increment all four from the client. Now that real interaction rows exist,
 * both paths would fire on a single like and the boutique's dashboard would be
 * quietly double every number, forever, with nothing to notice it by.
 *
 * So these four counters are written **here and nowhere else**. The event
 * ledger still records the gesture — "she liked it at 14:02" belongs in a
 * ledger — but it no longer touches the totals. See `eventCounterUpdate` in
 * `commerce-content.service.ts`, where those three cases are now deliberately
 * inert.
 */
@Injectable()
export class ContentInteractionsService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly events: EventEmitter2,
    private readonly attribution: ContentAttributionService,
  ) {}

  // ── Reactions ─────────────────────────────────────────────────────────────

  /**
   * Toggle a like, or set a story's emoji.
   *
   * One row per woman per piece, which is what both legacy tables enforced.
   * Sending a different emoji replaces the old one rather than adding a second
   * reaction — the story contract's `my_reaction` is singular.
   */
  async react(user: AuthUser, contentId: string, emoji?: string) {
    const content = await this.interactableOrThrow(contentId);

    const existing = await this.prisma.commerceContentReaction.findUnique({
      where: { contentId_userId: { contentId, userId: user.id } },
      select: { id: true, emoji: true },
    });

    // Tapping the heart again removes it; sending a *different* emoji changes
    // it. Without that second branch a woman could never correct a mis-tap on
    // a story without first clearing it.
    const isRemoval = existing !== null && (emoji ?? null) === existing.emoji;

    await this.prisma.$transaction(async (tx) => {
      if (isRemoval) {
        await tx.commerceContentReaction.delete({ where: { id: existing.id } });
        await tx.commerceContent.update({
          where: { id: contentId },
          data: { reactionsCount: { decrement: 1 } },
        });
        return;
      }

      if (existing) {
        await tx.commerceContentReaction.update({
          where: { id: existing.id },
          data: { emoji: emoji ?? null },
        });
        return;
      }

      await tx.commerceContentReaction.create({
        data: {
          contentId,
          userId: user.id,
          kind: emoji
            ? CommerceContentReactionKind.EMOJI
            : CommerceContentReactionKind.LIKE,
          emoji: emoji ?? null,
        },
      });
      await tx.commerceContent.update({
        where: { id: contentId },
        data: {
          reactionsCount: { increment: 1 },
          engagementCount: { increment: 1 },
          lastEngagementAt: new Date(),
        },
      });
    });

    if (!isRemoval && content.authorId !== user.id) {
      this.events.emit(AppEvent.ContentLiked, {
        authorId: content.authorId,
        actorId: user.id,
        contentId,
      });
    }

    return this.viewerState(contentId, user.id);
  }

  // ── Saves ─────────────────────────────────────────────────────────────────

  async toggleSave(user: AuthUser, contentId: string) {
    await this.interactableOrThrow(contentId);

    const existing = await this.prisma.commerceContentSave.findUnique({
      where: { contentId_userId: { contentId, userId: user.id } },
      select: { id: true },
    });

    await this.prisma.$transaction([
      existing
        ? this.prisma.commerceContentSave.delete({ where: { id: existing.id } })
        : this.prisma.commerceContentSave.create({
            data: { contentId, userId: user.id },
          }),
      this.prisma.commerceContent.update({
        where: { id: contentId },
        data: existing
          ? { savesCount: { decrement: 1 } }
          : {
              savesCount: { increment: 1 },
              engagementCount: { increment: 1 },
              lastEngagementAt: new Date(),
            },
      }),
    ]);

    return this.viewerState(contentId, user.id);
  }

  // ── Comments ──────────────────────────────────────────────────────────────

  async comment(
    user: AuthUser,
    contentId: string,
    body: string,
    parentId?: string,
  ) {
    const content = await this.interactableOrThrow(contentId);

    // One level only. A reply to a reply is re-parented to the thread root
    // rather than refused: she was answering somebody, and telling her the
    // thread is "too deep" is a worse answer than putting her comment where it
    // can be read.
    let rootId: string | null = null;
    if (parentId) {
      const parent = await this.prisma.commerceContentComment.findUnique({
        where: { id: parentId },
        select: { id: true, contentId: true, parentId: true, status: true },
      });
      if (!parent || parent.contentId !== contentId) {
        throw new NotFoundException('Comment not found');
      }
      if (parent.status !== CommerceContentCommentStatus.VISIBLE) {
        throw new BadRequestException('That comment is no longer available');
      }
      rootId = parent.parentId ?? parent.id;
    }

    const comment = await this.prisma.$transaction(async (tx) => {
      const created = await tx.commerceContentComment.create({
        data: { contentId, userId: user.id, parentId: rootId, body },
        include: { user: true },
      });
      await tx.commerceContent.update({
        where: { id: contentId },
        data: {
          repliesCount: { increment: 1 },
          engagementCount: { increment: 1 },
          lastEngagementAt: new Date(),
        },
      });
      if (rootId) {
        await tx.commerceContentComment.update({
          where: { id: rootId },
          data: { repliesCount: { increment: 1 } },
        });
      }
      return created;
    });

    if (content.authorId !== user.id) {
      this.events.emit(AppEvent.ContentCommented, {
        authorId: content.authorId,
        actorId: user.id,
        contentId,
        commentId: comment.id,
      });
    }

    return comment;
  }

  /**
   * Remove a comment.
   *
   * Hidden, never deleted. A comment that leaves no trace is how a harassment
   * report loses its own evidence, and Q103 asks for hiding as an action
   * distinct from deletion. Three people may do it: the woman who wrote it,
   * the author of the content it sits under, and a moderator.
   */
  async removeComment(user: AuthUser, commentId: string, reason?: string) {
    const comment = await this.prisma.commerceContentComment.findUnique({
      where: { id: commentId },
      select: {
        id: true,
        userId: true,
        parentId: true,
        contentId: true,
        status: true,
        content: { select: { authorId: true } },
      },
    });
    if (!comment) throw new NotFoundException('Comment not found');
    if (comment.status !== CommerceContentCommentStatus.VISIBLE) {
      return { removed: true };
    }

    const isCommenter = comment.userId === user.id;
    const isContentAuthor = comment.content.authorId === user.id;
    if (!isCommenter && !isContentAuthor) {
      // `assertCanManage` lets the moderator roles through and refuses
      // everybody else — the same gate the rest of the platform uses.
      assertCanManage(comment.userId, user);
    }

    await this.prisma.$transaction([
      this.prisma.commerceContentComment.update({
        where: { id: commentId },
        data: {
          status: CommerceContentCommentStatus.REMOVED,
          removedAt: new Date(),
          removedById: user.id,
          removalReason: reason ?? null,
        },
      }),
      this.prisma.commerceContent.update({
        where: { id: comment.contentId },
        data: { repliesCount: { decrement: 1 } },
      }),
      ...(comment.parentId
        ? [
            this.prisma.commerceContentComment.update({
              where: { id: comment.parentId },
              data: { repliesCount: { decrement: 1 } },
            }),
          ]
        : []),
    ]);

    return { removed: true };
  }

  async listComments(contentId: string, page: PaginationDto) {
    const where: Prisma.CommerceContentCommentWhereInput = {
      contentId,
      parentId: null,
      status: CommerceContentCommentStatus.VISIBLE,
    };

    const [roots, total] = await Promise.all([
      this.prisma.commerceContentComment.findMany({
        where,
        orderBy: { createdAt: 'desc' },
        skip: page.skip,
        take: page.limit,
        include: {
          user: true,
          replies: {
            where: { status: CommerceContentCommentStatus.VISIBLE },
            orderBy: { createdAt: 'asc' },
            // A thread head shows the first few and says how many more; the
            // rest arrive when she opens it. Loading every reply to every
            // comment is how a popular post becomes a slow page.
            take: 3,
            include: { user: true },
          },
        },
      }),
      this.prisma.commerceContentComment.count({ where }),
    ]);

    return { roots, total, meta: buildMeta(page.page, page.limit, total, roots.length) };
  }

  async listReplies(commentId: string, page: PaginationDto) {
    const where: Prisma.CommerceContentCommentWhereInput = {
      parentId: commentId,
      status: CommerceContentCommentStatus.VISIBLE,
    };
    const [items, total] = await Promise.all([
      this.prisma.commerceContentComment.findMany({
        where,
        orderBy: { createdAt: 'asc' },
        skip: page.skip,
        take: page.limit,
        include: { user: true },
      }),
      this.prisma.commerceContentComment.count({ where }),
    ]);
    return { items, total, meta: buildMeta(page.page, page.limit, total, items.length) };
  }

  // ── Reshare: «أضيفي إلى صفحتي» ────────────────────────────────────────────

  /**
   * Put somebody else's post on her own page.
   *
   * A pointer, never a copy — see `CommerceContentReshare`. What is created
   * here is an edge and the attribution rows a boutique reads; the media, the
   * caption and the product tags are never duplicated, so a price correction
   * or a takedown on the original reaches every page it was added to.
   */
  async reshare(
    user: AuthUser,
    contentId: string,
    input: { note?: string; viaReshareId?: string } = {},
  ) {
    const content = await this.interactableOrThrow(contentId);

    if (content.authorId === user.id) {
      throw new BadRequestException('CANNOT_RESHARE_OWN_CONTENT');
    }

    // Resharing a reshare records the ROOT. The chain cannot deepen, so no
    // read ever has to walk it — but the path she came by is kept, because a
    // referral trail that was never recorded cannot be reconstructed later.
    let viaReshareId: string | null = null;
    if (input.viaReshareId) {
      const via = await this.prisma.commerceContentReshare.findUnique({
        where: { id: input.viaReshareId },
        select: { id: true, sourceContentId: true },
      });
      if (via && via.sourceContentId === contentId) viaReshareId = via.id;
    }

    const viewer = await this.prisma.user.findUnique({
      where: { id: user.id },
      select: { profileIsPublic: true },
    });

    const existing = await this.prisma.commerceContentReshare.findUnique({
      where: {
        sourceContentId_resharerId: { sourceContentId: contentId, resharerId: user.id },
      },
      select: { id: true },
    });
    // Idempotent by construction: adding the same post twice is a no-op, not a
    // second row and not a second number on the boutique's dashboard.
    if (existing) return { reshared: true, id: existing.id, already: true };

    const reshare = await this.prisma.$transaction(async (tx) => {
      const created = await tx.commerceContentReshare.create({
        data: {
          sourceContentId: contentId,
          resharerId: user.id,
          sourceAuthorId: content.authorId,
          viaReshareId,
          note: input.note?.trim() || null,
          resharerIsPublic: viewer?.profileIsPublic ?? false,
        },
      });
      await tx.commerceContent.update({
        where: { id: contentId },
        data: {
          sharesCount: { increment: 1 },
          engagementCount: { increment: 1 },
          lastEngagementAt: new Date(),
        },
      });
      await tx.commerceContentEvent.create({
        data: {
          contentId,
          actorId: user.id,
          type: CommerceContentAnalyticsEventType.SHARE,
          metadata: { channel: 'reshare', reshare_id: created.id },
        },
      });
      return created;
    });

    // Outside the transaction on purpose: the projection is rebuildable, and
    // failing to write it must not undo the woman's reshare.
    await this.attribution.rebuild(contentId);

    this.events.emit(AppEvent.ContentReshared, {
      authorId: content.authorId,
      actorId: user.id,
      contentId,
      reshareId: reshare.id,
    });

    return { reshared: true, id: reshare.id, already: false };
  }

  /**
   * Take it back off her page.
   *
   * The row goes. It is her page, and something she has removed should stop
   * counting as promotion — the historical trace survives as the
   * `CommerceContentEvent` written when she added it.
   */
  async unreshare(user: AuthUser, contentId: string) {
    const existing = await this.prisma.commerceContentReshare.findUnique({
      where: {
        sourceContentId_resharerId: { sourceContentId: contentId, resharerId: user.id },
      },
      select: { id: true },
    });
    if (!existing) return { reshared: false };

    await this.prisma.$transaction([
      this.prisma.commerceContentReshare.delete({ where: { id: existing.id } }),
      this.prisma.commerceContent.update({
        where: { id: contentId },
        data: { sharesCount: { decrement: 1 } },
      }),
    ]);
    await this.attribution.rebuild(contentId);
    return { reshared: false };
  }

  /**
   * An external share — WhatsApp, a copied link. A ledger row and a counter,
   * not a reshare: nothing was added to anybody's page.
   */
  async recordExternalShare(user: AuthUser, contentId: string) {
    await this.interactableOrThrow(contentId);
    await this.prisma.$transaction([
      this.prisma.commerceContent.update({
        where: { id: contentId },
        data: {
          sharesCount: { increment: 1 },
          engagementCount: { increment: 1 },
          lastEngagementAt: new Date(),
        },
      }),
      this.prisma.commerceContentEvent.create({
        data: {
          contentId,
          actorId: user.id,
          type: CommerceContentAnalyticsEventType.SHARE,
          metadata: { channel: 'external' },
        },
      }),
    ]);
    return this.viewerState(contentId, user.id);
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  /**
   * Content anybody is allowed to act on.
   *
   * Removed content is unreachable here, not merely hidden from feeds: a woman
   * holding a stale card must not be able to like, comment on or reshare
   * something a moderator has taken down.
   */
  private async interactableOrThrow(contentId: string) {
    const content = await this.prisma.commerceContent.findUnique({
      where: { id: contentId },
      select: { id: true, authorId: true, status: true, expiresAt: true },
    });
    if (!content) throw new NotFoundException('Content not found');
    if (content.status === CommerceContentStatus.REMOVED) {
      throw new ForbiddenException('CONTENT_REMOVED');
    }
    if (content.status !== CommerceContentStatus.PUBLISHED) {
      throw new ForbiddenException('CONTENT_NOT_PUBLISHED');
    }
    return content;
  }

  /** What the card should render for this viewer, right now. */
  async viewerState(contentId: string, userId: string) {
    const [content, reaction, save, reshare] = await Promise.all([
      this.prisma.commerceContent.findUnique({
        where: { id: contentId },
        select: {
          reactionsCount: true,
          savesCount: true,
          sharesCount: true,
          repliesCount: true,
        },
      }),
      this.prisma.commerceContentReaction.findUnique({
        where: { contentId_userId: { contentId, userId } },
        select: { emoji: true },
      }),
      this.prisma.commerceContentSave.findUnique({
        where: { contentId_userId: { contentId, userId } },
        select: { id: true },
      }),
      this.prisma.commerceContentReshare.findUnique({
        where: {
          sourceContentId_resharerId: { sourceContentId: contentId, resharerId: userId },
        },
        select: { id: true },
      }),
    ]);

    return {
      is_liked: reaction !== null,
      my_reaction: reaction?.emoji ?? null,
      is_saved: save !== null,
      is_reshared: reshare !== null,
      likes_count: Number(content?.reactionsCount ?? 0),
      saves_count: Number(content?.savesCount ?? 0),
      shares_count: Number(content?.sharesCount ?? 0),
      comments_count: Number(content?.repliesCount ?? 0),
    };
  }
}
