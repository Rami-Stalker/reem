import { createHash } from 'node:crypto';
import { GraphEdge, GraphNode } from '@prisma/client';

/**
 * Every number and every key the graph invents.
 *
 * Same discipline as the trend engine and seller intelligence: a weight buried
 * in a projector is a weight nobody reviews, and each of these is a claim about
 * what a behaviour *means* rather than a mathematical fact.
 */

// ── What each behaviour is worth ─────────────────────────────────────────

/**
 * The base weight of one observation, before decay.
 *
 * The ordering is the argument. Owning something is the strongest statement
 * about taste there is, because it survived both the decision to buy and the
 * decision to keep. Buying is next. A view is very nearly nothing on its own —
 * it is the *repetition* of views that means anything, which is why
 * `observations` is kept beside the weight.
 */
export const EDGE_WEIGHTS: Record<GraphEdge, number> = {
  [GraphEdge.OWNS]: 40,
  [GraphEdge.PURCHASED]: 35,
  [GraphEdge.SAVED]: 18,
  [GraphEdge.CONSIDERED]: 15,
  [GraphEdge.NEEDS]: 22,
  [GraphEdge.SHOPS_FOR]: 20,
  [GraphEdge.BUYS_FROM]: 25,
  [GraphEdge.SEARCHED]: 10,
  [GraphEdge.ENGAGED]: 6,
  [GraphEdge.VIEWED]: 4,
};

/**
 * How long a behaviour keeps meaning something, in days.
 *
 * Halved every `EDGE_HALF_LIFE_DAYS`. A view from March says almost nothing
 * about what she wants today; a garment she owns says nearly as much as it did
 * the day it arrived, which is why owning decays far more slowly than looking.
 */
export const EDGE_HALF_LIFE_DAYS: Record<GraphEdge, number> = {
  [GraphEdge.OWNS]: 540,
  [GraphEdge.PURCHASED]: 270,
  [GraphEdge.BUYS_FROM]: 180,
  [GraphEdge.SAVED]: 120,
  [GraphEdge.NEEDS]: 45,
  [GraphEdge.SHOPS_FOR]: 90,
  [GraphEdge.CONSIDERED]: 60,
  [GraphEdge.SEARCHED]: 30,
  [GraphEdge.ENGAGED]: 30,
  [GraphEdge.VIEWED]: 21,
};

/** Repetition helps, with diminishing returns: 1 + ln(n) capped. */
export const MAX_REPEAT_MULTIPLIER = 2.5;

/** Below this a decayed edge is not worth a row. Pruned on each sweep. */
export const EDGE_FLOOR = 0.5;

/** How far back a projection reads. */
export const PROJECTION_WINDOW_DAYS = 180;

// ── Affinity ─────────────────────────────────────────────────────────────

/** Products below this affinity score are not worth relating. */
export const AFFINITY_FLOOR = 25;

/** How many related products to keep per product per kind. */
export const AFFINITY_FANOUT = 12;

/**
 * How much cheaper a product must be, in basis points, before it is offered as
 * a better-value substitute.
 *
 * Fifteen percent. Below that the saving is not worth unsettling a decision
 * she has nearly made, and a rail that said "here is one 3% cheaper" would be
 * noise wearing the clothes of advice.
 */
export const SUBSTITUTE_MIN_SAVING_BPS = 1500;

/** A substitute may not be rated worse than the product it replaces by more than this. */
export const SUBSTITUTE_MAX_RATING_DROP = 0.3;

/**
 * Above this saving, the two are not the same thing.
 *
 * Sixty percent. Live data offered a knit sweater as a "better value" version
 * of a cashmere cardigan at 72% less, and a ring as a cheaper pearl earring.
 * Genuine equivalents do not differ by that much: a gap that large *is* the
 * evidence that one of them is a different product, and presenting it as a
 * saving is how "better value" comes to mean "worse, but less".
 */
export const SUBSTITUTE_MAX_SAVING_BPS = 6000;

/**
 * How alike a substitute has to be.
 *
 * Higher than it looks, on purpose. `similarityScore` awards 40 for the same
 * category and 15 for the same slot, so 55 is reachable by two products that
 * share *nothing else* — which is how an earring became a substitute for a
 * ring. Above 65 the pair must also agree on colour, fabric, occasion or
 * price.
 */
export const SUBSTITUTE_MIN_SIMILARITY = 65;

/** Co-occurrences needed before "bought together" is a claim rather than a coincidence. */
export const CO_OCCURRENCE_MIN = 2;

// ── Addressing non-row nodes ─────────────────────────────────────────────

/**
 * A stable uuid for a node that is not a database row.
 *
 * Occasions, search terms and slots are keys, not rows, but the edge table
 * addresses everything with one uuid column. Hashing the key into a v5-shaped
 * uuid keeps that column uniform without a second nullable "string id" column
 * that would be null on almost every row.
 *
 * Deterministic, so the same occasion always lands on the same id and a
 * re-projection updates rather than duplicates.
 */
export function nodeId(type: GraphNode, key: string): string {
  if (
    type === GraphNode.USER ||
    type === GraphNode.PRODUCT ||
    type === GraphNode.SELLER ||
    type === GraphNode.CATEGORY
  ) {
    // These are real rows and their own ids are already uuids.
    return key;
  }

  const hash = createHash('sha1')
    .update(`reem:graph:${type}:${key}`)
    .digest('hex');

  return [
    hash.slice(0, 8),
    hash.slice(8, 12),
    // Version 5, so the id is well-formed rather than merely uuid-shaped.
    `5${hash.slice(13, 16)}`,
    ((parseInt(hash.slice(16, 18), 16) & 0x3f) | 0x80)
      .toString(16)
      .padStart(2, '0') + hash.slice(18, 20),
    hash.slice(20, 32),
  ].join('-');
}

/**
 * The reverse is impossible by design, so anything that needs the human key
 * back must carry it in `evidence`.
 *
 * Stated here because it is the one sharp edge of hashing keys: a row saying
 * "she shops for `9f2c…`" is unreadable on its own, and every projector that
 * writes an OCCASION or TERM node is expected to put the key in `evidence` so
 * an explanation can quote it.
 */
export const KEYED_NODES: readonly GraphNode[] = [
  GraphNode.OCCASION,
  GraphNode.TERM,
  GraphNode.SLOT,
];
