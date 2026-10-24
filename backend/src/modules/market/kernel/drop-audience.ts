/**
 * Choosing who a launch is for.
 *
 * The part that makes a drop more than a scheduled sale. A launch blasted at
 * everyone is an advertisement; a launch shown to the two hundred women whose
 * wardrobes have a hole this exact shape is an invitation, and the difference
 * is entirely in this function.
 *
 * ── Why every choice carries a reason ────────────────────────────────────
 *
 * A shopper is entitled to know why she is being shown something, and Ohara is
 * entitled to know whether its targeting works. Both need the same thing: the
 * reason the graph picked her, stored beside the invitation. A drop with a
 * thousand invitations and four opens is a targeting failure, and without
 * per-invitation reasons nobody can tell which reason was the bad one.
 *
 * Pure — it takes the graph's edges as plain values and returns an ordered
 * list, so the targeting can be re-run and argued with without a database.
 */

export type InviteReason =
  /// A closet gap or an open room decision names the slot this drop fills.
  | 'OPEN_NEED'
  /// She shops for the occasion the drop is dressed for.
  | 'OCCASION_MATCH'
  /// She buys from this seller.
  | 'SELLER_CUSTOMER'
  /// She owns or saved things the graph says are like these.
  | 'TASTE_MATCH'
  /// She searched for something these answer.
  | 'SEARCHED_FOR';

/** One shopper's relationship to the drop, as the graph sees it. */
export interface CandidateSignals {
  userId: string;
  /** Slots she is short of. */
  needsSlots: readonly string[];
  /** Occasions she shops for. */
  occasions: readonly string[];
  /** Sellers she buys from. */
  sellerIds: readonly string[];
  /** Products she owns, saved or considered that are similar to the drop's. */
  tasteMatches: number;
  /** Search terms of hers the drop answers. */
  searchHits: number;
}

/** What the drop is, reduced to what targeting needs. */
export interface DropShape {
  slots: readonly string[];
  occasions: readonly string[];
  sellerIds: readonly string[];
  productCount: number;
}

export interface Invitation {
  userId: string;
  affinity: number;
  reasons: Array<{ code: InviteReason; weight: number }>;
}

/**
 * What each kind of match is worth.
 *
 * An open need leads by a distance, and deliberately: it is the only signal
 * that describes something she is *missing* rather than something she likes.
 * Everything else predicts interest; this one predicts a purchase.
 */
const REASON_WEIGHTS: Record<InviteReason, number> = {
  OPEN_NEED: 45,
  SEARCHED_FOR: 25,
  OCCASION_MATCH: 18,
  SELLER_CUSTOMER: 12,
  TASTE_MATCH: 20,
};

/**
 * Below this, an invitation is a guess.
 *
 * The floor is the whole discipline of the feature. Without it a drop reaches
 * everybody with any edge at all, which is the blast it was built to replace —
 * and the reason to invite fewer women is not politeness, it is that a
 * notification nobody wanted is the fastest way to lose the right to send one.
 */
export const MIN_AFFINITY = 30;

const round = (n: number): number => Math.round(n * 100) / 100;
const clamp = (n: number): number => Math.min(100, Math.max(0, n));

export function selectAudience(
  drop: DropShape,
  candidates: readonly CandidateSignals[],
  options: { limit?: number; minAffinity?: number } = {},
): Invitation[] {
  const floor = options.minAffinity ?? MIN_AFFINITY;
  const out: Invitation[] = [];

  for (const candidate of candidates) {
    const reasons: Invitation['reasons'] = [];

    if (drop.slots.some((slot) => candidate.needsSlots.includes(slot))) {
      reasons.push({ code: 'OPEN_NEED', weight: REASON_WEIGHTS.OPEN_NEED });
    }
    if (candidate.searchHits > 0) {
      reasons.push({
        code: 'SEARCHED_FOR',
        // Saturating: three matching searches is a strong signal, thirty is
        // not ten times stronger.
        weight: round(
          REASON_WEIGHTS.SEARCHED_FOR * Math.min(1, candidate.searchHits / 3),
        ),
      });
    }
    if (drop.occasions.some((o) => candidate.occasions.includes(o))) {
      reasons.push({
        code: 'OCCASION_MATCH',
        weight: REASON_WEIGHTS.OCCASION_MATCH,
      });
    }
    if (candidate.tasteMatches > 0) {
      reasons.push({
        code: 'TASTE_MATCH',
        weight: round(
          REASON_WEIGHTS.TASTE_MATCH * Math.min(1, candidate.tasteMatches / 3),
        ),
      });
    }
    if (drop.sellerIds.some((id) => candidate.sellerIds.includes(id))) {
      reasons.push({
        code: 'SELLER_CUSTOMER',
        weight: REASON_WEIGHTS.SELLER_CUSTOMER,
      });
    }

    if (!reasons.length) continue;

    const affinity = clamp(round(reasons.reduce((t, r) => t + r.weight, 0)));
    if (affinity < floor) continue;

    out.push({
      userId: candidate.userId,
      affinity,
      reasons: reasons.sort((a, b) => b.weight - a.weight),
    });
  }

  return out
    .sort((a, b) => b.affinity - a.affinity)
    .slice(0, options.limit ?? 500);
}

/**
 * How a drop actually did.
 *
 * Reach, opens and conversions are the obvious three. `precision` is the one
 * worth having: of the women Ohara chose, what share cared enough to look. A
 * drop that sold well to a thousand invitations may still have been badly
 * targeted, and only this number says so.
 */
export interface DropPerformance {
  invited: number;
  notified: number;
  opened: number;
  converted: number;
  /** Opens over notified, 0-1. */
  precision: number;
  /** Conversions over opens, 0-1. */
  conversion: number;
  /** Mean affinity of those who converted, against those who did not. */
  affinityLift: number | null;
}

export function measureDrop(
  invites: ReadonlyArray<{
    affinity: number;
    notifiedAt: Date | null;
    openedAt: Date | null;
    convertedAt: Date | null;
  }>,
): DropPerformance {
  const invited = invites.length;
  const notified = invites.filter((i) => i.notifiedAt).length;
  const opened = invites.filter((i) => i.openedAt).length;
  const converted = invites.filter((i) => i.convertedAt).length;

  const buyers = invites.filter((i) => i.convertedAt);
  const rest = invites.filter((i) => !i.convertedAt);
  const mean = (rows: typeof buyers): number =>
    rows.length ? rows.reduce((t, r) => t + r.affinity, 0) / rows.length : 0;

  return {
    invited,
    notified,
    opened,
    converted,
    precision: notified ? round(opened / notified) : 0,
    conversion: opened ? round(converted / opened) : 0,
    // Positive means the women the graph rated highest are the ones who
    // bought — which is the only real evidence that the targeting works
    // rather than merely runs.
    affinityLift:
      buyers.length && rest.length ? round(mean(buyers) - mean(rest)) : null,
  };
}
