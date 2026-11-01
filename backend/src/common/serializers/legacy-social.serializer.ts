import {
  CommerceContent,
  CommerceContentComment,
  CommerceContentMedia,
  CommerceContentProductTag,
  MediaType,
  ProductVariant,
  User,
} from '@prisma/client';
import { serializePublicUser } from './user.serializer';
import { ProductRecord, serializeProduct } from './product.serializer';

/**
 * The legacy `/posts/*` and `/stories/*` contract, spoken by the content
 * platform.
 *
 * The shipped Flutter app reads these shapes and nothing about it changes when
 * the tables underneath it do. Every key here is byte-identical to what
 * `post.serializer.ts` and `story.serializer.ts` emitted from `posts` and
 * `stories` — the fixtures in `test/contract/` were captured from those, and
 * the whole merge is only safe because they are regenerated from these and the
 * diff is empty.
 *
 * Three translations are worth naming, because they are where a shape had to
 * be *chosen* rather than copied:
 *
 *   - A legacy post's `caption` is the content's `body`. The payload also
 *     carries it, and the payload is what the composer edits, but `body` is
 *     what every read path already used.
 *   - `comments_count` maps to `repliesCount`. Same number, better name for a
 *     table that now carries replies as well.
 *   - A story's single `media` object comes from the first media row. The
 *     platform models many; the legacy contract promised one, and the client
 *     that reads it renders one.
 */

export type LegacyContentRecord = CommerceContent & {
  author: User;
  media?: CommerceContentMedia[];
  productTags?: (CommerceContentProductTag & {
    product: ProductRecord;
    variant?: ProductVariant | null;
  })[];
};

export interface LegacyViewerState {
  liked: Set<string>;
  saved: Set<string>;
  viewed: Set<string>;
  reactions: Map<string, string | null>;
  /**
   * Posts she added to her own page. Optional because only the post reads
   * need it — a story or a saved-shelf row has nothing to add.
   */
  reshared?: Set<string>;
  /** Everyone's most chosen reactions per post, for «❤️😍🔥» on the card. */
  summaries?: Map<string, { emoji: string; count: number }[]>;
}

export const NO_LEGACY_VIEWER: LegacyViewerState = {
  liked: new Set(),
  saved: new Set(),
  viewed: new Set(),
  reactions: new Map(),
};

/** `GET /posts/*` — the eleven original keys, plus `is_reshared`. */
export function serializeLegacyPost(
  content: LegacyContentRecord,
  viewer: LegacyViewerState = NO_LEGACY_VIEWER,
) {
  // A legacy post carried at most one product. The platform allows many, so
  // the first tag is the one this contract can express — sorted, so "first"
  // means the same thing on every read rather than whatever the join returned.
  const tags = (content.productTags ?? [])
    .slice()
    .sort((a, b) => a.sortOrder - b.sortOrder);
  const tag = tags[0];

  return {
    id: content.id,
    author: serializePublicUser(content.author),
    product: tag ? serializeProduct(tag.product) : null,
    // Every piece, in order — `product` above stays for builds that read only
    // one. A post tagging three pieces used to show the first and lose two.
    products: tags.map((t) => serializeProduct(t.product)),
    // The photographs she posted. The home feed drew the tagged piece's
    // catalogue shots instead, so a shopper's own photo never reached it.
    media: (content.media ?? [])
      .slice()
      .sort((a, b) => a.sortOrder - b.sortOrder)
      .map((m) => ({
        url: m.url,
        type: m.type,
        thumbnail_url: m.thumbnailUrl ?? null,
        blur_hash: m.blurHash ?? null,
      })),
    caption: content.body ?? '',
    likes_count: Number(content.reactionsCount),
    comments_count: Number(content.repliesCount),
    shares_count: Number(content.sharesCount),
    saves_count: Number(content.savesCount),
    is_liked: viewer.liked.has(content.id),
    // Which reaction she chose (null for the plain heart), and everyone's
    // most chosen — additive keys, older builds ignore them.
    my_reaction: viewer.reactions.get(content.id) ?? null,
    reaction_summary: viewer.summaries?.get(content.id) ?? [],
    is_saved: viewer.saved.has(content.id),
    // «أضيفي إلى صفحتي» on the post card. Without it the button could only
    // guess, and a guess of "not added" offers to add what is already there.
    is_reshared: viewer.reshared?.has(content.id) ?? false,
    created_at: content.createdAt.toISOString(),
  };
}

/** `GET /stories` — the eight keys, with one media object. */
export function serializeLegacyStory(
  content: LegacyContentRecord,
  viewer: LegacyViewerState = NO_LEGACY_VIEWER,
) {
  const media = (content.media ?? [])
    .slice()
    .sort((a, b) => a.sortOrder - b.sortOrder)[0];

  // The link lived on the story row and now lives in the payload's first
  // frame, because that is the shape the story content type declares.
  const payload = (content.payload ?? {}) as {
    frames?: { media_url?: string; link?: string | null }[];
  };
  const frame = payload.frames?.[0];

  return {
    id: content.id,
    user: serializePublicUser(content.author),
    media: {
      url: media?.url ?? frame?.media_url ?? '',
      type: media?.type ?? MediaType.image,
    },
    link: frame?.link ?? null,
    is_viewed: viewer.viewed.has(content.id),
    my_reaction: viewer.reactions.get(content.id) ?? null,
    expires_at: (content.expiresAt ?? content.createdAt).toISOString(),
    created_at: content.createdAt.toISOString(),
  };
}

/**
 * `GET /posts/:id/comments` — five keys, and `likes_count` is a literal zero.
 *
 * It was a literal in the old serializer too. Nothing has ever written a
 * comment like count, and emitting the key keeps the client parsing; inventing
 * a number behind it would be the thing `products.likes_count` was deleted
 * for.
 */
export function serializeLegacyComment(
  comment: CommerceContentComment & { user: User },
  reactions?: {
    reactions_count: number;
    my_reaction: string | null;
    is_reacted: boolean;
    reaction_summary: { emoji: string; count: number }[];
  },
) {
  return {
    id: comment.id,
    user: serializePublicUser(comment.user),
    content: comment.body,
    // Real now: comments carry reactions.
    likes_count: reactions?.reactions_count ?? 0,
    my_reaction: reactions?.my_reaction ?? null,
    is_reacted: reactions?.is_reacted ?? false,
    reaction_summary: reactions?.reaction_summary ?? [],
    created_at: comment.createdAt.toISOString(),
  };
}

/**
 * Owner-only: one viewer row on a story, with the emoji she left.
 *
 * Moved here from `story.serializer.ts` when that file went. The shape is
 * unchanged and pinned by `test/contract/story_viewers.json` — `viewed_at` is
 * the *first* view, because that is what the old `story_views.viewed_at`
 * recorded and what the boutique's list has always shown.
 */
export function serializeStoryViewer(
  view: { viewedAt: Date; user: User },
  reactionEmoji: string | null,
) {
  return {
    user: serializePublicUser(view.user),
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
