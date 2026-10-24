import { Injectable, NotFoundException } from '@nestjs/common';
import {
  CommerceAuthorKind,
  CommerceContentStatus,
  MediaType,
} from '@prisma/client';
import { EventEmitter2 } from '@nestjs/event-emitter';
import { PrismaService } from '../../prisma/prisma.service';
import { AuthUser } from '../../common/decorators/current-user.decorator';
import { assertCanManage } from '../../common/authz';
import { AppEvent } from '../../common/events/app-events';
import {
  serializeLegacyStory,
  serializeStoryAnalytics,
  serializeStoryViewer,
} from '../../common/serializers';
import { CreateStoryDto } from './dto/create-story.dto';
import { MediaService } from '../media/media.service';
import { assertAuthorMayChange } from '../commerce-content/commerce-content.service';

const STORY_TTL_HOURS = 24;

/**
 * `POST|DELETE /seller/stories` and its analytics — over the content platform.
 *
 * A story is a `CommerceContent` of type `story`, whose registry row already
 * declares `expires_after_hours: 24`. The TTL constant stays because this
 * route bypasses the registry's expiry derivation: the old client sends no
 * `expires_at` and expects the server to pick one, and the two numbers must
 * not be allowed to disagree silently.
 */
@Injectable()
export class SellerStoriesService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly events: EventEmitter2,
    private readonly media: MediaService,
  ) {}

  async create(user: AuthUser, dto: CreateStoryDto) {
    const expiresAt = new Date();
    expiresAt.setHours(expiresAt.getHours() + STORY_TTL_HOURS);

    const author = await this.prisma.user.findUnique({
      where: { id: user.id },
      select: { role: true, profileIsPublic: true },
    });

    const story = await this.prisma.commerceContent.create({
      data: {
        authorId: user.id,
        authorKind:
          author?.role === 'CUSTOMER'
            ? CommerceAuthorKind.CUSTOMER
            : CommerceAuthorKind.SELLER,
        authorIsPublic: author?.profileIsPublic ?? true,
        contentType: 'story',
        locale: 'ar',
        status: CommerceContentStatus.PUBLISHED,
        moderationStatus: 'APPROVED',
        publishedAt: new Date(),
        expiresAt,
        payload: {
          frames: [{ media_url: dto.media_url, link: dto.link ?? null }],
          legacy: 'story',
        },
        publicationTargets: ['STORY_FEED', 'STORE_FEED'],
        media: {
          create: [
            {
              url: dto.media_url,
              type: dto.type ?? MediaType.image,
              sortOrder: 0,
            },
          ],
        },
      },
      include: { author: true, media: { orderBy: { sortOrder: 'asc' } } },
    });

    // The story now references the upload, so it is no longer an orphan the
    // sweeper may delete. After the write, not before: a create that fails
    // should leave the asset collectable.
    await this.media.markAttached(user.id, [dto.media_url]);

    this.events.emit(AppEvent.StoryPublished, {
      sellerId: user.id,
      storyId: story.id,
    });
    return serializeLegacyStory(story);
  }

  async remove(user: AuthUser, id: string) {
    const story = await this.ownedOrThrow(user, id);
    if (story.status === CommerceContentStatus.DELETED) {
      return { message: 'Story deleted' };
    }
    assertAuthorMayChange(story.status);
    await this.prisma.commerceContent.update({
      where: { id },
      data: { status: CommerceContentStatus.DELETED, archivedAt: new Date() },
    });
    return { message: 'Story deleted' };
  }

  async analytics(user: AuthUser, id: string) {
    const story = await this.ownedOrThrow(user, id);
    const [viewsCount, reactions] = await Promise.all([
      this.prisma.commerceContentViewer.count({ where: { contentId: id } }),
      this.prisma.commerceContentReaction.findMany({
        where: { contentId: id },
        select: { userId: true, emoji: true },
      }),
    ]);

    const reactionBreakdown = reactions.reduce<Record<string, number>>(
      (acc, reaction) => {
        const emoji = reaction.emoji ?? '♥';
        acc[emoji] = (acc[emoji] ?? 0) + 1;
        return acc;
      },
      {},
    );

    return serializeStoryAnalytics({
      storyId: id,
      viewsCount,
      reactionsCount: reactions.length,
      reactionBreakdown,
      expiresAt: story.expiresAt ?? story.createdAt,
      createdAt: story.createdAt,
    });
  }

  async viewers(user: AuthUser, id: string) {
    await this.ownedOrThrow(user, id);
    const [views, reactions] = await Promise.all([
      this.prisma.commerceContentViewer.findMany({
        where: { contentId: id },
        orderBy: { lastViewedAt: 'desc' },
      }),
      this.prisma.commerceContentReaction.findMany({
        where: { contentId: id },
        select: { userId: true, emoji: true },
      }),
    ]);

    // `CommerceContentViewer.userId` carries no relation — it is a bare uuid
    // on the model — so the people are fetched in one go rather than joined.
    const users = await this.prisma.user.findMany({
      where: { id: { in: views.map((view) => view.userId) } },
    });
    const userById = new Map(users.map((row) => [row.id, row]));
    const reactionByUser = new Map(
      reactions.map((reaction) => [reaction.userId, reaction.emoji]),
    );

    return views
      .map((view) => {
        const viewer = userById.get(view.userId);
        if (!viewer) return null;
        return serializeStoryViewer(
          { ...view, viewedAt: view.firstViewedAt, user: viewer } as never,
          reactionByUser.get(view.userId) ?? null,
        );
      })
      .filter((row): row is NonNullable<typeof row> => row !== null);
  }

  private async ownedOrThrow(user: AuthUser, id: string) {
    const story = await this.prisma.commerceContent.findFirst({
      where: { id, contentType: 'story' },
      select: {
        id: true,
        authorId: true,
        status: true,
        expiresAt: true,
        createdAt: true,
      },
    });
    if (!story) throw new NotFoundException('Story not found');
    assertCanManage(story.authorId, user);
    return story;
  }
}
