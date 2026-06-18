import { Story, StoryView, User } from '@prisma/client';
import { serializeUser } from './user.serializer';

export type StoryWithRelations = Story & {
  user: User;
  views?: { userId: string }[];
  reactions?: { userId: string; emoji: string }[];
};

export function serializeStory(story: StoryWithRelations, currentUserId?: string) {
  const isViewed =
    currentUserId && story.views
      ? story.views.some((v) => v.userId === currentUserId)
      : false;
  const myReaction =
    currentUserId && story.reactions
      ? (story.reactions.find((r) => r.userId === currentUserId)?.emoji ?? null)
      : null;

  return {
    id: story.id,
    user: serializeUser(story.user),
    media: { url: story.mediaUrl, type: story.mediaType },
    link: story.link,
    is_viewed: isViewed,
    my_reaction: myReaction,
    expires_at: story.expiresAt.toISOString(),
    created_at: story.createdAt.toISOString(),
  };
}

/** Owner-only: a single viewer row with optional reaction. */
export function serializeStoryViewer(
  view: StoryView & { user: User },
  reactionEmoji: string | null,
) {
  return {
    user: serializeUser(view.user),
    viewed_at: view.viewedAt.toISOString(),
    reaction: reactionEmoji,
  };
}

/** Owner-only: aggregate analytics for a story. */
export function serializeStoryAnalytics(input: {
  storyId: string;
  viewsCount: number;
  reactionsCount: number;
  reactionBreakdown: Record<string, number>;
  expiresAt: Date;
  createdAt: Date;
}) {
  return {
    story_id: input.storyId,
    views_count: input.viewsCount,
    reactions_count: input.reactionsCount,
    reaction_breakdown: input.reactionBreakdown,
    engagement_rate:
      input.viewsCount > 0
        ? Math.round((input.reactionsCount / input.viewsCount) * 1000) / 10
        : 0,
    expires_at: input.expiresAt.toISOString(),
    created_at: input.createdAt.toISOString(),
  };
}
