/**
 * The arithmetic of the graph.
 *
 * Pure, like every kernel in this codebase: it takes plain values and returns
 * numbers, so an edge weight on any screen can be re-derived by hand from the
 * rows behind it. Nothing here reads a database and nothing asks a model.
 */

import { GraphEdge } from '@prisma/client';
import {
  EDGE_HALF_LIFE_DAYS,
  EDGE_WEIGHTS,
  MAX_REPEAT_MULTIPLIER,
} from '../graph.constants';

const round = (n: number, dp = 2): number => {
  const f = 10 ** dp;
  return Math.round(n * f) / f;
};
const clamp = (n: number, lo = 0, hi = 100): number =>
  Math.min(hi, Math.max(lo, n));

/** Halved every `halfLifeDays`. */
export function decay(ageDays: number, halfLifeDays: number): number {
  if (halfLifeDays <= 0) return 1;
  return Math.pow(0.5, Math.max(0, ageDays) / halfLifeDays);
}

/**
 * Repetition, with diminishing returns.
 *
 * Nine views are worth more than one but nowhere near nine times more —
 * somebody comparing two dresses reloads a page, and a linear count would read
 * that indecision as devotion.
 */
export function repetition(observations: number): number {
  if (observations <= 1) return 1;
  return Math.min(MAX_REPEAT_MULTIPLIER, 1 + Math.log(observations));
}

/**
 * What one relationship is currently worth.
 *
 * Recomputed from `lastSeenAt` on every projection rather than incremented,
 * so an edge cannot outlive the behaviour behind it: a product she looked at
 * twice in March quietly fades instead of sitting at its March weight forever.
 */
export function edgeWeight(input: {
  kind: GraphEdge;
  observations: number;
  ageDays: number;
}): number {
  const base = EDGE_WEIGHTS[input.kind] ?? 0;
  const life = EDGE_HALF_LIFE_DAYS[input.kind] ?? 30;
  return round(
    clamp(base * repetition(input.observations) * decay(input.ageDays, life)),
  );
}

// ── Affinity ─────────────────────────────────────────────────────────────

/** What the affinity scorer is told about one product. */
export interface AffinityFacts {
  productId: string;
  categoryId: string;
  /** Lexicon colour keys. */
  colours: readonly string[];
  materials: readonly string[];
  /** The wardrobe slot, when the catalogue implies one. */
  slot: string | null;
  occasions: readonly string[];
  priceSyp: number | null;
  rating: number;
  reviewsCount: number;
}

const overlap = (a: readonly string[], b: readonly string[]): number => {
  if (!a.length || !b.length) return 0;
  const set = new Set(a);
  const shared = b.filter((x) => set.has(x)).length;
  return shared / Math.max(a.length, b.length);
};

/**
 * How alike two products are, 0-100.
 *
 * Category first, because a dress and a candle are not alternatives however
 * many colours they share. Then the things a woman actually compares: the
 * slot it fills, its colour, its fabric, what it is *for*, and whether it
 * costs roughly the same — a piece at four times the price is not an
 * alternative to the one she is looking at, whatever it is made of.
 */
export function similarityScore(a: AffinityFacts, b: AffinityFacts): number {
  if (a.productId === b.productId) return 0;
  if (a.categoryId !== b.categoryId) return 0;

  let score = 40; // Same category is already most of the claim.

  if (a.slot && b.slot && a.slot === b.slot) score += 15;
  score += overlap(a.colours, b.colours) * 15;
  score += overlap(a.materials, b.materials) * 10;
  score += overlap(a.occasions, b.occasions) * 10;
  score += priceCloseness(a.priceSyp, b.priceSyp) * 10;

  return round(clamp(score));
}

/** 1 when the prices match, falling to 0 at a fourfold difference. */
export function priceCloseness(a: number | null, b: number | null): number {
  if (!a || !b || a <= 0 || b <= 0) return 0;
  const ratio = a > b ? a / b : b / a;
  if (ratio >= 4) return 0;
  return round(1 - (ratio - 1) / 3, 3);
}

/**
 * Whether two products go *together* rather than instead of each other.
 *
 * The opposite test to similarity on the one axis that matters: they must fill
 * **different** slots. A second dress does not complete an outfit. Beyond
 * that, what makes two pieces an outfit is that they suit the same occasion
 * and their colours do not fight.
 *
 * `coOccurrence` is the honest part — how often they were actually bought,
 * closeted or roomed together. Everything else is inference; this is
 * observation, so it carries the most.
 */
export function complementScore(
  a: AffinityFacts,
  b: AffinityFacts,
  coOccurrence: number,
): number {
  if (a.productId === b.productId) return 0;
  // Same slot is a substitute, never a complement.
  if (a.slot && b.slot && a.slot === b.slot) return 0;
  // Nor are slots that replace each other — see `exclusiveSlots`.
  if (exclusiveSlots(a.slot, b.slot)) return 0;

  let score = 0;

  // Observed togetherness, saturating: twice is a signal, twenty times is not
  // ten times the signal.
  score += Math.min(45, coOccurrence * 18);

  // Both dressed for the same event.
  score += overlap(a.occasions, b.occasions) * 25;

  // Different slots at all is the structural requirement.
  if (a.slot && b.slot && a.slot !== b.slot) score += 15;

  // Colours that sit together. Shared palette *or* a neutral in the pair.
  const NEUTRALS = new Set(['black', 'white', 'beige', 'grey', 'navy']);
  const neutral =
    a.colours.some((c) => NEUTRALS.has(c)) ||
    b.colours.some((c) => NEUTRALS.has(c));
  if (overlap(a.colours, b.colours) > 0 || neutral) score += 15;

  return round(clamp(score));
}

/**
 * Slots that are worn *instead of* each other, not with each other.
 *
 * Different slots are usually the whole point of a complement — a bag and a
 * dress make an outfit. But some pairs are alternatives despite having
 * different slot names, and the graph offered «عباية سهرة» as a complement to
 * «فستان سهرة» until this existed. Nobody wears both.
 *
 * The groupings are not invented here: they are the ones Reem Closet already
 * uses to count outfits, where capacity is
 * `(dresses + abayas + min(tops, bottoms)) × shoes`. That formula treats a
 * dress and an abaya as interchangeable base garments, and treats either as
 * standing in for a top-and-bottom pair. Any other answer here would put the
 * graph at odds with the wardrobe arithmetic she can already see.
 */
export function exclusiveSlots(
  a: string | null,
  b: string | null,
): boolean {
  if (!a || !b) return false;
  const BASE = new Set(['DRESS', 'ABAYA']);
  const HALVES = new Set(['TOP', 'BOTTOM']);

  // Two base garments: one or the other.
  if (BASE.has(a) && BASE.has(b)) return true;
  // A base garment already covers what a top or a bottom would.
  if (BASE.has(a) && HALVES.has(b)) return true;
  if (BASE.has(b) && HALVES.has(a)) return true;

  // A top and a bottom are the one pair that genuinely needs each other.
  return false;
}

/**
 * Whether `candidate` is a better-value stand-in for `product`.
 *
 * Returns null unless it genuinely is one, which is most of the value of this
 * function: a substitute rail that always finds something is a rail that
 * tells women to buy the cheapest thing in the category.
 *
 * Three gates. It has to be a real alternative (similar, same slot); it has to
 * be *meaningfully* cheaper, not three percent; and it must not be worse. The
 * third is what stops "better value" meaning "worse, but less".
 */
export function substituteScore(
  product: AffinityFacts,
  candidate: AffinityFacts,
  options: {
    minSavingBps: number;
    maxSavingBps: number;
    minSimilarity: number;
    maxRatingDrop: number;
  },
): { score: number; savingBps: number } | null {
  if (!product.priceSyp || !candidate.priceSyp) return null;
  if (candidate.priceSyp >= product.priceSyp) return null;

  const similarity = similarityScore(product, candidate);
  if (similarity < options.minSimilarity) return null;

  const savingBps = Math.round(
    ((product.priceSyp - candidate.priceSyp) / product.priceSyp) * 10_000,
  );
  if (savingBps < options.minSavingBps) return null;
  // Too cheap to be the same thing — see `SUBSTITUTE_MAX_SAVING_BPS`.
  if (savingBps > options.maxSavingBps) return null;

  // A cheaper piece nobody rated is not evidence of value. An unrated
  // candidate is allowed only against an unrated product.
  if (product.reviewsCount > 0 && candidate.reviewsCount === 0) return null;
  if (
    product.reviewsCount > 0 &&
    candidate.rating < product.rating - options.maxRatingDrop
  ) {
    return null;
  }

  // Saving carries the score, tempered by how alike they really are: a huge
  // discount on something only loosely comparable is not a saving.
  const saving = Math.min(1, savingBps / 5000);
  return {
    score: round(clamp(similarity * 0.5 + saving * 50)),
    savingBps,
  };
}
