/**
 * The honest half of behavioural commerce.
 *
 * Every technique here works because it is *true*. Social proof works because
 * other women really did buy; scarcity works because the shelf really is
 * nearly empty; an anchor works because the higher price was really being
 * charged. The moment any of them stops being true it becomes a dark pattern,
 * and a dark pattern in a marketplace women recommend to each other is not a
 * conversion tactic — it is a way of spending the only thing the platform
 * cannot rebuy.
 *
 * So the rule this file enforces is: **when the claim is not true, return
 * nothing.** Not a softer version, not a rounded-up version. Nothing. A card
 * with no scarcity badge is a card telling the truth about a full shelf.
 */

/** One honest thing that can be said about a listing. */
export interface Cue {
  kind: 'social_proof' | 'scarcity' | 'anchor' | 'quality';
  /** Arabic, ready to render. */
  ar: string;
  /** The number behind it, so a client can style rather than parse. */
  value: number;
}

export interface CueFacts {
  /** Parcels of it sold in the recent window. */
  recentOrders: number;
  /** How long that window was. */
  windowDays: number;

  /** Women who have it saved right now. */
  favourites: number;

  /** Units left across live offers, and how many were there recently. */
  stock: number;
  liveOffers: number;

  /** Mean rating and how many reviews stand behind it. */
  rating: number;
  reviews: number;

  /**
   * A price the listing was genuinely being sold at before the current one —
   * a flash sale's frozen `compareAtPrice`, never a number a seller typed to
   * make a discount look bigger.
   */
  compareAtPrice: number | null;
  price: number;
}

/**
 * The floors.
 *
 * Set where the claim stops being informative rather than where it stops being
 * technically true. "Three women bought this" is true and tells a shopper
 * nothing; "one left" is true and useful. The gap between those two is the
 * whole design.
 */
export const CUE_RULES = {
  /** Below this many recent sales, "others bought it" is noise. */
  minRecentOrders: 5,
  /** Below this many saves, likewise. */
  minFavourites: 10,
  /** At or below this many units, scarcity is worth saying. */
  scarcityAt: 3,
  /**
   * And never when several boutiques still stock it. One shop being low is
   * not the marketplace running out, and saying so would be false urgency.
   */
  scarcityMaxOffers: 1,
  /** Below this many reviews a rating is not yet a recommendation. */
  minReviews: 5,
  /** An anchor below this discount is not worth drawing attention to. */
  minAnchorPercent: 10,
} as const;

/**
 * What can honestly be shown on this card.
 *
 * Order matters: the list is returned strongest-first so a client with room
 * for one badge shows the most informative one rather than the first that
 * happened to qualify.
 */
export function cuesFor(facts: CueFacts): Cue[] {
  const cues: Cue[] = [];

  // ── Scarcity, only when it is real and only when it is the marketplace's
  // scarcity rather than one seller's.
  if (
    facts.stock > 0 &&
    facts.stock <= CUE_RULES.scarcityAt &&
    facts.liveOffers <= CUE_RULES.scarcityMaxOffers
  ) {
    cues.push({
      kind: 'scarcity',
      value: facts.stock,
      ar:
        facts.stock === 1
          ? 'بقيت قطعة واحدة'
          : `بقيت ${facts.stock} قطع فقط`,
    });
  }

  // ── Social proof from purchases. The strongest thing that can be said,
  // because it cost the women who did it real money.
  if (facts.recentOrders >= CUE_RULES.minRecentOrders) {
    cues.push({
      kind: 'social_proof',
      value: facts.recentOrders,
      ar: `اشترتها ${facts.recentOrders} خلال ${facts.windowDays} يوماً`,
    });
  }

  // ── An anchor, only against a price that was genuinely charged.
  if (
    facts.compareAtPrice !== null &&
    facts.compareAtPrice > facts.price &&
    facts.price > 0
  ) {
    const off = Math.round(
      ((facts.compareAtPrice - facts.price) / facts.compareAtPrice) * 100,
    );
    if (off >= CUE_RULES.minAnchorPercent) {
      cues.push({
        kind: 'anchor',
        value: off,
        ar: `أقلّ بنسبة ${off}% من سعرها السابق`,
      });
    }
  }

  // ── Quality, once enough women have said so.
  if (facts.reviews >= CUE_RULES.minReviews && facts.rating >= 4.3) {
    cues.push({
      kind: 'quality',
      value: Math.round(facts.rating * 10) / 10,
      ar: `${facts.rating.toFixed(1)} من ${facts.reviews} مراجعة`,
    });
  }

  // ── Saves, but only when nothing stronger was available. A "many women
  // saved this" badge next to "twelve bought it" is the weaker claim
  // crowding out the better one.
  if (
    cues.length === 0 &&
    facts.favourites >= CUE_RULES.minFavourites
  ) {
    cues.push({
      kind: 'social_proof',
      value: facts.favourites,
      ar: `حفظتها ${facts.favourites} امرأة`,
    });
  }

  return cues;
}
