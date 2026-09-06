import { Injectable, NotFoundException } from '@nestjs/common';
import { serializeStory } from '../../common/serializers';
import { StoriesRepository } from './stories.repository';
import { TrendSignalService } from '../trends/collection/trend-signal.service';

/** Customer-facing story viewing + reactions. */
@Injectable()
export class StoriesService {
  constructor(
    private readonly repo: StoriesRepository,
    private readonly signals: TrendSignalService,
  ) {}

  /** `userId` is absent for a signed-out visitor — see the controller. */
  async list(userId?: string) {
    const stories = await this.repo.activeForViewer(userId);
    return stories.map((s) => serializeStory(s, userId));
  }

  async recordView(userId: string, storyId: string) {
    const story = await this.ensureActive(storyId);
    // Owners viewing their own story should not inflate their analytics —
    // and that applies to the trend signal for exactly the same reason.
    if (story.userId !== userId) {
      await this.repo.upsertView(storyId, userId);
      this.recordProductEngagement(story, userId);
    }
    return { message: 'View recorded' };
  }

  /**
   * A story that links to a product is discovery for it, and on this platform
   * that is a large share of how discovery happens. Fire-and-forget: a
   * dropped signal is a rounding error in a daily total, a failed view is not.
   */
  private recordProductEngagement(
    story: { link?: string | null },
    userId: string,
  ): void {
    const productId = productIdFromLink(story.link);
    if (!productId) return;
    this.signals.recordContentEngagement({
      productId,
      kind: 'story',
      userId,
    });
  }

  async react(userId: string, storyId: string, emoji: string) {
    const story = await this.ensureActive(storyId);
    await this.repo.upsertReaction(storyId, userId, emoji);
    // Reacting implies a view.
    if (story.userId !== userId) {
      await this.repo.upsertView(storyId, userId);
    }
    return { message: 'Reaction saved', emoji };
  }

  async unreact(userId: string, storyId: string) {
    await this.ensureActive(storyId);
    await this.repo.deleteReaction(storyId, userId);
    return { message: 'Reaction removed' };
  }

  private async ensureActive(storyId: string) {
    const story = await this.repo.findOwner(storyId);
    if (!story || story.expiresAt < new Date()) {
      throw new NotFoundException('Story not found or expired');
    }
    return story;
  }
}


const UUID = /[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}/i;

/**
 * The product a story points at, from its `link`.
 *
 * Stories carry a free-form link rather than a product relation, so this is a
 * parse and not a join. It accepts only `/product/<uuid>` shapes and only a
 * well-formed uuid, because a mis-parse here would attribute a story's
 * audience to whatever the malformed id happened to hit.
 */
function productIdFromLink(link: string | null | undefined): string | null {
  if (!link) return null;
  if (!/\/products?\//i.test(link)) return null;
  const match = UUID.exec(link);
  return match ? match[0] : null;
}
