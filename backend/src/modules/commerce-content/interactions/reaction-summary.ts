import { PrismaService } from '../../../prisma/prisma.service';

/** A plain like is drawn as this glyph, so it sits in the summary with the rest. */
export const LIKE_GLYPH = '❤️';

/** One reaction and how many chose it. */
export interface ReactionCount {
  emoji: string;
  count: number;
}

/** How many of each reaction a summary carries — the three a card shows. */
const SUMMARY_SIZE = 3;

/**
 * The most chosen reactions on each piece, most first — the «❤️😍🔥 ١٢»
 * beside the counter. One grouped query for a whole page.
 */
export async function contentReactionSummaries(
  prisma: PrismaService,
  contentIds: string[],
): Promise<Map<string, ReactionCount[]>> {
  const summaries = new Map<string, ReactionCount[]>();
  if (contentIds.length === 0) return summaries;
  const rows = await prisma.commerceContentReaction.groupBy({
    by: ['contentId', 'emoji'],
    where: { contentId: { in: contentIds } },
    _count: { _all: true },
  });
  return summarise(
    rows.map((row) => ({
      key: row.contentId,
      emoji: row.emoji,
      count: row._count._all,
    })),
  );
}

/** Folds grouped rows into per-key summaries, plain likes counted as ❤️. */
export function summarise(
  rows: { key: string; emoji: string | null; count: number }[],
): Map<string, ReactionCount[]> {
  const byKey = new Map<string, Map<string, number>>();
  for (const row of rows) {
    const glyph = row.emoji ?? LIKE_GLYPH;
    const tally = byKey.get(row.key) ?? new Map<string, number>();
    tally.set(glyph, (tally.get(glyph) ?? 0) + row.count);
    byKey.set(row.key, tally);
  }
  const summaries = new Map<string, ReactionCount[]>();
  for (const [key, tally] of byKey) {
    summaries.set(
      key,
      [...tally.entries()]
        .map(([emoji, count]) => ({ emoji, count }))
        .sort((a, b) => b.count - a.count)
        .slice(0, SUMMARY_SIZE),
    );
  }
  return summaries;
}

/** A comment's reactions as one viewer sees them. */
export interface CommentReactionState {
  reactions_count: number;
  my_reaction: string | null;
  is_reacted: boolean;
  reaction_summary: ReactionCount[];
}

export const NO_COMMENT_REACTIONS: CommentReactionState = {
  reactions_count: 0,
  my_reaction: null,
  is_reacted: false,
  reaction_summary: [],
};

/** The reactions on a page of comments, in two queries. */
export async function commentReactionStates(
  prisma: PrismaService,
  commentIds: string[],
  viewerId?: string,
): Promise<Map<string, CommentReactionState>> {
  const states = new Map<string, CommentReactionState>();
  if (commentIds.length === 0) return states;
  const [rows, mine] = await Promise.all([
    prisma.commerceContentCommentReaction.groupBy({
      by: ['commentId', 'emoji'],
      where: { commentId: { in: commentIds } },
      _count: { _all: true },
    }),
    viewerId
      ? prisma.commerceContentCommentReaction.findMany({
          where: { userId: viewerId, commentId: { in: commentIds } },
          select: { commentId: true, emoji: true },
        })
      : Promise.resolve([] as { commentId: string; emoji: string | null }[]),
  ]);
  const totals = new Map<string, number>();
  for (const row of rows) {
    totals.set(row.commentId, (totals.get(row.commentId) ?? 0) + row._count._all);
  }
  const summaries = summarise(
    rows.map((row) => ({ key: row.commentId, emoji: row.emoji, count: row._count._all })),
  );
  const myReaction = new Map(mine.map((row) => [row.commentId, row.emoji]));
  for (const id of commentIds) {
    states.set(id, {
      reactions_count: totals.get(id) ?? 0,
      my_reaction: myReaction.get(id) ?? null,
      is_reacted: myReaction.has(id),
      reaction_summary: summaries.get(id) ?? [],
    });
  }
  return states;
}
