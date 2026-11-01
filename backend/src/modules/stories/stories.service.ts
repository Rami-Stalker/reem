import { PRODUCT_CARD_INCLUDE } from '../../common/catalog/product-include';
import { Injectable, NotFoundException, Optional } from '@nestjs/common';
import { CommerceContentStatus } from '@prisma/client';
import { PrismaService } from '../../prisma/prisma.service';
import {
  LegacyViewerState,
  NO_LEGACY_VIEWER,
  serializeLegacyStory,
  serializeProduct,
} from '../../common/serializers';
import { TrendSignalService } from '../trends/collection/trend-signal.service';
import { contentVisibilityWhere } from '../commerce-content/feed/content-feed.service';
import { FeedRankingService } from '../commerce-content/ranking/feed-ranking.service';

/**
 * `GET /stories` and the two engagement routes — the same contract, over the
 * content platform.
 *
 * The `stories`, `story_views` and `story_reactions` tables are no longer the
 * source of truth. A story is a `CommerceContent` of type `story`, its views
 * are `commerce_content_viewers` and its reactions are
 * `commerce_content_reactions` with an emoji — which is what the platform
 * already modelled, and why the merge needed no new tables for any of it.
 *
 * The best part of the change is a deletion: `productIdFromLink` is gone. A
 * story's product used to be recovered by running a uuid regex over a
 * free-text link on every view, and it is a real `CommerceContentProductTag`
 * now. The backfill converted the existing links.
 */
@Injectable()
export class StoriesService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly signals: TrendSignalService,
    @Optional() private readonly ranking?: FeedRankingService,
  ) {}

  /** `userId` is absent for a signed-out visitor — see the controller. */
  async list(userId?: string) {
    const stories = await this.prisma.commerceContent.findMany({
      // The content platform's own visibility rule, so the home rail agrees
      // with `/content/stories`: her own stories and the followers-only ones
      // of shops she follows appear, and the accounts she muted do not.
      where: {
        AND: [
          contentVisibilityWhere(userId),
          { contentType: 'story' },
          { expiresAt: { gt: new Date() } },
          ...(userId
            ? [
                { hiddenBy: { none: { userId } } },
                { author: { mutesReceived: { none: { muterId: userId } } } },
              ]
            : []),
        ],
      },
      orderBy: { createdAt: 'desc' },
      include: {
        author: true,
        media: { orderBy: { sortOrder: 'asc' } },
        // Every piece the story tags, not only the first: a story about an
        // outfit tags each piece of it, and the viewer offers them all.
        productTags: {
          orderBy: { sortOrder: 'asc' },
          take: 12,
          include: { product: { include: PRODUCT_CARD_INCLUDE } },
        },
      },
    });

    const viewer = await this.viewerState(
      stories.map((story) => story.id),
      userId,
    );
    const ordered = await this.trayOrder(stories, viewer, userId);
    // `product_id` is additive: the story it tags, for the viewer's
    // «تسوّقي القطعة». Older clients ignore the key.
    return ordered.map(({ productTags, ...story }) => ({
      ...serializeLegacyStory(story, viewer),
      product_id: productTags[0]?.productId ?? null,
      products: productTags.map((tag) => serializeProduct(tag.product)),
    }));
  }

  async recordView(userId: string, storyId: string) {
    const story = await this.ensureActive(storyId, userId);

    // Owners viewing their own story should not inflate their analytics — and
    // that applies to the trend signal for exactly the same reason.
    if (story.authorId !== userId) {
      await this.prisma.$transaction(async (tx) => {
        const existing = await tx.commerceContentViewer.findUnique({
          where: { contentId_userId: { contentId: storyId, userId } },
          select: { id: true },
        });
        if (existing) {
          await tx.commerceContentViewer.update({
            where: { id: existing.id },
            data: { viewsCount: { increment: 1 }, lastViewedAt: new Date() },
          });
          await tx.commerceContent.update({
            where: { id: storyId },
            data: { viewsCount: { increment: 1 } },
          });
          return;
        }
        await tx.commerceContentViewer.create({
          data: { contentId: storyId, userId },
        });
        await tx.commerceContent.update({
          where: { id: storyId },
          data: {
            viewsCount: { increment: 1 },
            uniqueViewersCount: { increment: 1 },
          },
        });
      });
      await this.recordProductEngagement(storyId, userId);
    }
    return { message: 'View recorded' };
  }

  /**
   * A story that tags a product is discovery for it, and on this platform that
   * is a large share of how discovery happens. Fire-and-forget: a dropped
   * signal is a rounding error in a daily total, a failed view is not.
   */
  private async recordProductEngagement(
    contentId: string,
    userId: string,
  ): Promise<void> {
    const tag = await this.prisma.commerceContentProductTag
      .findFirst({
        where: { contentId },
        orderBy: { sortOrder: 'asc' },
        select: { productId: true },
      })
      .catch(() => null);
    if (!tag?.productId) return;
    this.signals.recordContentEngagement({
      productId: tag.productId,
      kind: 'story',
      userId,
    });
  }

  async react(userId: string, storyId: string, emoji: string) {
    const story = await this.ensureActive(storyId, userId);

    const existing = await this.prisma.commerceContentReaction.findUnique({
      where: { contentId_userId: { contentId: storyId, userId } },
      select: { id: true },
    });

    await this.prisma.$transaction(async (tx) => {
      if (existing) {
        await tx.commerceContentReaction.update({
          where: { id: existing.id },
          data: { emoji, kind: 'EMOJI' },
        });
        return;
      }
      await tx.commerceContentReaction.create({
        data: { contentId: storyId, userId, kind: 'EMOJI', emoji },
      });
      await tx.commerceContent.update({
        where: { id: storyId },
        data: {
          reactionsCount: { increment: 1 },
          engagementCount: { increment: 1 },
          lastEngagementAt: new Date(),
        },
      });
    });

    // Reacting implies a view.
    if (story.authorId !== userId) await this.recordView(userId, storyId);
    return { message: 'Reaction saved', emoji };
  }

  async unreact(userId: string, storyId: string) {
    await this.ensureActive(storyId);
    const existing = await this.prisma.commerceContentReaction.findUnique({
      where: { contentId_userId: { contentId: storyId, userId } },
      select: { id: true },
    });
    if (!existing) return { message: 'Reaction removed' };

    await this.prisma.$transaction([
      this.prisma.commerceContentReaction.delete({ where: { id: existing.id } }),
      this.prisma.commerceContent.update({
        where: { id: storyId },
        data: { reactionsCount: { decrement: 1 } },
      }),
    ]);
    return { message: 'Reaction removed' };
  }

  /**
   * The rail groups by shop in the order each shop first appears, so the
   * flat list is laid out shop by shop in the tray's order — her own, then
   * the shops with something new, closest first, then the ones she finished.
   * Each shop's frames keep their order. Without the ranker: newest first.
   */
  private async trayOrder<T extends { id: string; authorId: string; createdAt: Date }>(
    stories: T[],
    viewer: LegacyViewerState,
    userId?: string,
  ): Promise<T[]> {
    if (!this.ranking) return stories;
    const byShop = new Map<string, T[]>();
    for (const story of stories) {
      const frames = byShop.get(story.authorId);
      if (frames) frames.push(story);
      else byShop.set(story.authorId, [story]);
    }
    try {
      const groups = await this.ranking.orderTray(
        userId,
        [...byShop.entries()].map(([authorId, frames]) => ({
          authorId,
          frames,
          allSeen: frames.every((frame) => viewer.viewed.has(frame.id)),
          // Newest first, so the first frame is the newest.
          newestAt: frames[0].createdAt,
        })),
      );
      return groups.flatMap((group) => group.frames);
    } catch {
      return stories;
    }
  }

  private async viewerState(
    contentIds: string[],
    userId?: string,
  ): Promise<LegacyViewerState> {
    if (!userId || contentIds.length === 0) return NO_LEGACY_VIEWER;
    const [views, reactions] = await Promise.all([
      this.prisma.commerceContentViewer.findMany({
        where: { userId, contentId: { in: contentIds } },
        select: { contentId: true },
      }),
      this.prisma.commerceContentReaction.findMany({
        where: { userId, contentId: { in: contentIds } },
        select: { contentId: true, emoji: true },
      }),
    ]);
    return {
      liked: new Set(),
      saved: new Set(),
      viewed: new Set(views.map((view) => view.contentId)),
      reactions: new Map(reactions.map((r) => [r.contentId, r.emoji])),
    };
  }

  /**
   * A live story this viewer may see. The visibility rule is the feeds' one,
   * so a followers-only story cannot be viewed or reacted to by a stranger
   * holding its id.
   */
  private async ensureActive(storyId: string, viewerId?: string) {
    const story = await this.prisma.commerceContent.findFirst({
      where: {
        AND: [
          { id: storyId, contentType: 'story' },
          ...(viewerId ? [contentVisibilityWhere(viewerId)] : []),
        ],
      },
      select: { id: true, authorId: true, expiresAt: true, status: true },
    });
    if (
      !story ||
      story.status !== CommerceContentStatus.PUBLISHED ||
      (story.expiresAt && story.expiresAt < new Date())
    ) {
      throw new NotFoundException('Story not found or expired');
    }
    return story;
  }
}
