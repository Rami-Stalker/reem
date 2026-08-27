import { Injectable, NotFoundException } from '@nestjs/common';
import { serializeStory } from '../../common/serializers';
import { StoriesRepository } from './stories.repository';

/** Customer-facing story viewing + reactions. */
@Injectable()
export class StoriesService {
  constructor(private readonly repo: StoriesRepository) {}

  /** `userId` is absent for a signed-out visitor — see the controller. */
  async list(userId?: string) {
    const stories = await this.repo.activeForViewer(userId);
    return stories.map((s) => serializeStory(s, userId));
  }

  async recordView(userId: string, storyId: string) {
    const story = await this.ensureActive(storyId);
    // Owners viewing their own story should not inflate their analytics.
    if (story.userId !== userId) {
      await this.repo.upsertView(storyId, userId);
    }
    return { message: 'View recorded' };
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
