import { CommerceContentCommentStatus, User } from '@prisma/client';
import { serializePublicUser } from './user.serializer';
import {
  CommerceContentWithRelations,
  serializeCommerceContent,
} from './commerce-content.serializer';

/** What the viewer has done to a piece — the half a counter cannot answer. */
export interface ViewerState {
  is_liked: boolean;
  my_reaction: string | null;
  /** The most chosen reactions, most first — not hers, everyone's. */
  reaction_summary?: { emoji: string; count: number }[];
  is_saved: boolean;
  is_reshared: boolean;
}

const NO_VIEWER: ViewerState = {
  is_liked: false,
  my_reaction: null,
  is_saved: false,
  is_reshared: false,
};

type CommentRecord = {
  id: string;
  body: string;
  parentId: string | null;
  repliesCount: number;
  status: CommerceContentCommentStatus;
  createdAt: Date;
  user: User;
  replies?: CommentRecord[];
};

/** A comment's reactions as the viewer sees them; see `commentReactionStates`. */
export interface CommentReactions {
  reactions_count: number;
  my_reaction: string | null;
  is_reacted: boolean;
  reaction_summary: { emoji: string; count: number }[];
}

const NO_REACTIONS: CommentReactions = {
  reactions_count: 0,
  my_reaction: null,
  is_reacted: false,
  reaction_summary: [],
};

export interface SerializedComment extends CommentReactions {
  id: string;
  user: ReturnType<typeof serializePublicUser>;
  body: string;
  parent_id: string | null;
  replies_count: number;
  replies: SerializedComment[];
  created_at: string;
}

/** Recursive by one level: a thread head and its replies, never deeper. */
export function serializeContentComment(
  comment: CommentRecord,
  reactions?: Map<string, CommentReactions>,
): SerializedComment {
  return {
    id: comment.id,
    user: serializePublicUser(comment.user),
    body: comment.body,
    parent_id: comment.parentId,
    replies_count: comment.repliesCount,
    replies: (comment.replies ?? []).map((reply) =>
      serializeContentComment(reply, reactions),
    ),
    created_at: comment.createdAt.toISOString(),
    ...(reactions?.get(comment.id) ?? NO_REACTIONS),
  };
}

/** Every comment id in a page, replies included — to load their reactions. */
export function commentIdsOf(comments: CommentRecord[]): string[] {
  return comments.flatMap((comment) => [
    comment.id,
    ...(comment.replies ?? []).map((reply) => reply.id),
  ]);
}

/**
 * A feed card.
 *
 * `serializeCommerceContent` is the boutique's workspace view — it carries the
 * version history and the full analytics block, which is the right payload for
 * a woman editing her own post and the wrong one for twenty cards in a feed.
 * This adds the viewer's own state and drops what a card cannot use.
 */
export function serializeFeedContent(
  content: CommerceContentWithRelations,
  viewer: ViewerState = NO_VIEWER,
) {
  const full = serializeCommerceContent(content);
  const { versions: _versions, ...card } = full;
  return { ...card, viewer };
}

type ReshareRecord = {
  id: string;
  note: string | null;
  createdAt: Date;
  resharer: User;
  sourceContent: CommerceContentWithRelations;
};

/**
 * A reshared post on somebody's page.
 *
 * The original is nested whole and attributed to its own author — that is the
 * requirement, and it is why this is a wrapper rather than a copy with a
 * `reshared_by` field bolted on. A client that renders `content` gets the
 * boutique's name, the boutique's products and the boutique's link for free,
 * and cannot accidentally present the resharer as the source.
 */
export function serializeReshare(
  reshare: ReshareRecord,
  viewer: ViewerState = NO_VIEWER,
) {
  return {
    kind: 'reshare' as const,
    id: reshare.id,
    resharer: serializePublicUser(reshare.resharer),
    note: reshare.note,
    reshared_at: reshare.createdAt.toISOString(),
    content: serializeFeedContent(reshare.sourceContent, viewer),
  };
}

/** A timeline entry is either something she published or something she added. */
export function serializeTimelineEntry(
  entry:
    | { kind: 'own'; content: CommerceContentWithRelations }
    | { kind: 'reshare'; reshare: ReshareRecord },
  viewerFor: (contentId: string) => ViewerState,
) {
  if (entry.kind === 'own') {
    return {
      kind: 'own' as const,
      content: serializeFeedContent(entry.content, viewerFor(entry.content.id)),
    };
  }
  return serializeReshare(
    entry.reshare,
    viewerFor(entry.reshare.sourceContent.id),
  );
}

/**
 * A woman who has promoted a boutique's products.
 *
 * **Where Q44 is honoured.** The client asked for the identity of the
 * customers who add his posts to their pages; the questionnaire says the
 * customer's name is hidden from the seller. Both hold, because the answer is
 * her own: a woman whose page is open is already publishing under her name, so
 * naming her to the boutique tells it nothing she has not already said in
 * public. A woman whose page is closed is a number.
 *
 * The flag is read here, at serialization time, and never stored — so closing
 * her page takes her name off the boutique's screen on the next load rather
 * than at the next rebuild.
 */
export function serializePromoter(row: {
  actor: Pick<
    User,
    'id' | 'name' | 'username' | 'imageUrl' | 'profileIsPublic'
  >;
  reshares: number;
  products: number;
  lastAt: Date;
}) {
  const named = row.actor.profileIsPublic;
  return {
    is_named: named,
    user: named
      ? {
          id: row.actor.id,
          name: row.actor.name,
          username: row.actor.username,
          image_url: row.actor.imageUrl,
        }
      : null,
    reshares: row.reshares,
    products: row.products,
    last_at: row.lastAt.toISOString(),
  };
}
