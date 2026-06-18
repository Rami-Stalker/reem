import { Injectable, NotFoundException } from '@nestjs/common';
import { MediaType } from '@prisma/client';
import { EventEmitter2 } from '@nestjs/event-emitter';
import { AuthUser } from '../../common/decorators/current-user.decorator';
import { assertCanManage } from '../../common/authz';
import { AppEvent } from '../../common/events/app-events';
import {
  serializeStory,
  serializeStoryAnalytics,
  serializeStoryViewer,
} from '../../common/serializers';
import { StoriesRepository } from './stories.repository';
import { CreateStoryDto } from './dto/create-story.dto';

const STORY_TTL_HOURS = 24;

/** Seller-only story authoring + analytics. */
@Injectable()
export class SellerStoriesService {
  constructor(
    private readonly repo: StoriesRepository,
    private readonly events: EventEmitter2,
  ) {}

  async create(user: AuthUser, dto: CreateStoryDto) {
    const expiresAt = new Date();
    expiresAt.setHours(expiresAt.getHours() + STORY_TTL_HOURS);

    const story = await this.repo.create({
      user: { connect: { id: user.id } },
      mediaUrl: dto.media_url,
      mediaType: dto.type ?? MediaType.image,
      link: dto.link ?? null,
      expiresAt,
    });
    this.events.emit(AppEvent.StoryPublished, {
      sellerId: user.id,
      storyId: story.id,
    });
    return serializeStory(story, user.id);
  }

  async remove(user: AuthUser, id: string) {
    await this.ownedOrThrow(user, id);
    await this.repo.delete(id);
    return { message: 'Story deleted' };
  }

  async analytics(user: AuthUser, id: string) {
    const story = await this.ownedOrThrow(user, id);
    const [viewsCount, reactions] = await Promise.all([
      this.repo.countViews(id),
      this.repo.reactionsFor(id),
    ]);

    const reactionBreakdown = reactions.reduce<Record<string, number>>(
      (acc, r) => {
        acc[r.emoji] = (acc[r.emoji] ?? 0) + 1;
        return acc;
      },
      {},
    );

    return serializeStoryAnalytics({
      storyId: id,
      viewsCount,
      reactionsCount: reactions.length,
      reactionBreakdown,
      expiresAt: story.expiresAt,
      createdAt: story.createdAt,
    });
  }

  async viewers(user: AuthUser, id: string) {
    await this.ownedOrThrow(user, id);
    const [views, reactions] = await Promise.all([
      this.repo.viewers(id),
      this.repo.reactionsFor(id),
    ]);
    const reactionByUser = new Map(reactions.map((r) => [r.userId, r.emoji]));
    return views.map((v) =>
      serializeStoryViewer(v, reactionByUser.get(v.userId) ?? null),
    );
  }

  private async ownedOrThrow(user: AuthUser, id: string) {
    const story = await this.repo.findOwner(id);
    if (!story) throw new NotFoundException('Story not found');
    assertCanManage(story.userId, user);
    return story;
  }
}
