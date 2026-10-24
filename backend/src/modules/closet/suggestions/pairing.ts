import { ClosetSeason, ModestyLevel, OutfitSlot } from '@prisma/client';
import { coloursHarmonise, modestyRank, slotEntry } from '../../ai-stylist/understanding/stylist-lexicon';
import { ClosetItemFact, ClosetLookFact } from '../gaps/gap-engine';
import { seasonMatches } from '../items/garment-descriptor';

/**
 * How well a candidate garment fits the wardrobe it would be joining.
 *
 * This is the layer the stylist's ranker cannot have. `rankProducts` scores a
 * product against a *brief* — what she asked for — and does it well. This scores
 * the same product against her *closet*: how many things she already owns it
 * would go with, which saved looks it would complete, whether it is the size her
 * other clothes are, and whether it is the fourth black top she does not need.
 *
 * The two compose rather than compete. Retrieval and ranking stay exactly as
 * they are, and this rides on top as a bounded adjustment — see
 * `ClosetSuggestionService`. Rewriting the ranker to know about closets would
 * have coupled the conversational stylist to a table it has no business
 * reading, and would have given Ohara two ranking functions to keep honest.
 *
 * Pure, like the ranker, and for the same reason: a suggestion whose reasons
 * cannot be reproduced is a suggestion that cannot be defended.
 */

/** Why the closet liked a candidate. Rendered into Arabic by the serializer. */
export type PairingReason =
  | 'PAIRS_WITH_OWNED'
  | 'COMPLETES_LOOK'
  | 'FILLS_EMPTY_SLOT'
  | 'MATCHES_YOUR_SIZE'
  | 'IN_SEASON'
  | 'MATCHES_YOUR_MODESTY'
  | 'MATCHES_YOUR_PALETTE'
  | 'ALREADY_WELL_STOCKED'
  | 'DUPLICATE_OF_OWNED';

export interface PairingResult {
  /**
   * −1…+1. Negative is a real outcome, not an error: the fourth black top
   * genuinely deserves to sit below the skirt that completes nine outfits.
   */
  score: number;
  reasons: PairingReason[];
  /** Owned pieces this would go with. */
  pairsWithItemIds: string[];
  /** Saved looks this would complete outright. */
  completesLookIds: string[];
}

/** What a candidate has to look like for this scorer. */
export interface PairingCandidate {
  slot: OutfitSlot;
  colours: string[];
  seasons: ClosetSeason[];
  occasions: string[];
  modesty: ModestyLevel;
  /** Sizes any live offer has in stock, for the slot's size system. */
  availableSizes: string[];
}

export interface PairingContext {
  items: readonly ClosetItemFact[];
  looks: readonly ClosetLookFact[];
  season: ClosetSeason;
  /** Her modal size per slot, from `modalSize`. */
  sizes: ReadonlyMap<OutfitSlot, string>;
  /** The occasion in play, when the suggestion is for one. */
  occasion?: string | null;
}

/**
 * Slots that combine into an outfit.
 *
 * Asymmetric on purpose and read in both directions by `pairsWith`. A dress
 * pairs with shoes and a bag; a top pairs with a bottom. Listing the pair once
 * and looking it up either way keeps the table short enough to read and
 * impossible to make internally inconsistent.
 */
const COMPLEMENTS: ReadonlyArray<readonly [OutfitSlot, OutfitSlot]> = [
  [OutfitSlot.TOP, OutfitSlot.BOTTOM],
  [OutfitSlot.TOP, OutfitSlot.OUTERWEAR],
  [OutfitSlot.BOTTOM, OutfitSlot.OUTERWEAR],
  [OutfitSlot.TOP, OutfitSlot.SHOES],
  [OutfitSlot.BOTTOM, OutfitSlot.SHOES],
  [OutfitSlot.DRESS, OutfitSlot.SHOES],
  [OutfitSlot.DRESS, OutfitSlot.OUTERWEAR],
  [OutfitSlot.DRESS, OutfitSlot.BAG],
  [OutfitSlot.DRESS, OutfitSlot.JEWELRY],
  [OutfitSlot.ABAYA, OutfitSlot.SHOES],
  [OutfitSlot.ABAYA, OutfitSlot.BAG],
  [OutfitSlot.ABAYA, OutfitSlot.ACCESSORY],
  [OutfitSlot.TOP, OutfitSlot.BAG],
  [OutfitSlot.BOTTOM, OutfitSlot.BAG],
  [OutfitSlot.TOP, OutfitSlot.JEWELRY],
  [OutfitSlot.DRESS, OutfitSlot.ACCESSORY],
];

export function complementarySlots(slot: OutfitSlot): OutfitSlot[] {
  const out = new Set<OutfitSlot>();
  for (const [left, right] of COMPLEMENTS) {
    if (left === slot) out.add(right);
    if (right === slot) out.add(left);
  }
  return [...out];
}

/**
 * How many pieces she owns that a candidate would go with.
 *
 * Colour is the only compatibility test, via the lexicon's harmony table, and
 * the honesty of it rests on `coloursHarmonise` treating neutrals as universal.
 * A piece with no detected colour pairs with everything — which is right: not
 * knowing a colour is not the same as knowing it clashes.
 */
function pairsWith(
  candidate: PairingCandidate,
  context: PairingContext,
): ClosetItemFact[] {
  const complements = new Set(complementarySlots(candidate.slot));

  return context.items.filter((item) => {
    if (!complements.has(item.slot)) return false;
    // Two garments that cannot be worn in the same weather are not a pair.
    if (!seasonMatches(item.seasons, context.season)) return false;
    if (!seasonMatches(candidate.seasons, context.season)) return false;

    if (!candidate.colours.length || !item.colours.length) return true;
    return candidate.colours.some((colour) =>
      item.colours.some((owned) => coloursHarmonise(colour, owned)),
    );
  });
}

/** Looks whose only missing slot is the one this candidate fills. */
function completesLooks(
  candidate: PairingCandidate,
  context: PairingContext,
): ClosetLookFact[] {
  return context.looks.filter((look) => {
    const missing = new Set(look.wantedSlots);
    if (missing.size !== 1 || !missing.has(candidate.slot)) return false;
    if (!look.palette.length || !candidate.colours.length) return true;
    return candidate.colours.some((colour) =>
      look.palette.every((owned) => coloursHarmonise(colour, owned)),
    );
  });
}

/**
 * The prevailing modesty of a wardrobe.
 *
 * Read from the pieces themselves rather than from her stated preference,
 * because this scorer's question is "does this belong with her clothes", and
 * what she owns answers that better than what she once ticked. The stated
 * preference is still applied — upstream, by the ranker, where a hard mismatch
 * is scored to −Infinity.
 */
function closetModesty(items: readonly ClosetItemFact[]): ModestyLevel | null {
  const ranks = items
    .filter((item) => item.modesty !== ModestyLevel.UNSPECIFIED)
    .map((item) => modestyRank(item.modesty));
  if (!ranks.length) return null;

  // The most covering thing she owns is not the answer, nor is the average: the
  // median is what her wardrobe actually looks like.
  ranks.sort((a, b) => a - b);
  const median = ranks[Math.floor(ranks.length / 2)];

  const byRank: ReadonlyArray<[number, ModestyLevel]> = [
    [4, ModestyLevel.FULL_COVERAGE],
    [3, ModestyLevel.MODEST],
    [2, ModestyLevel.BALANCED],
    [1, ModestyLevel.EXPRESSIVE],
  ];
  return byRank.find(([rank]) => rank === median)?.[1] ?? null;
}

export function scorePairing(
  candidate: PairingCandidate,
  context: PairingContext,
): PairingResult {
  const reasons: PairingReason[] = [];
  let score = 0;

  // ── What it goes with ─────────────────────────────────────────────────
  const partners = pairsWith(candidate, context);
  if (partners.length) {
    // Saturating: going with three things she owns is a great deal better than
    // going with one, and going with twenty is not seven times better than
    // going with three.
    score += Math.min(partners.length / 6, 1) * 0.35;
    reasons.push('PAIRS_WITH_OWNED');
  }

  const completed = completesLooks(candidate, context);
  if (completed.length) {
    score += 0.3;
    reasons.push('COMPLETES_LOOK');
  }

  // ── What she has none of ──────────────────────────────────────────────
  const ownedInSlot = context.items.filter((item) => item.slot === candidate.slot);
  if (!ownedInSlot.length) {
    score += 0.15;
    reasons.push('FILLS_EMPTY_SLOT');
  }

  // ── Fit with her, not with the look ───────────────────────────────────
  const wantedSize = context.sizes.get(candidate.slot);
  if (wantedSize && slotEntry(candidate.slot).sizeSystem) {
    if (candidate.availableSizes.includes(wantedSize)) {
      score += 0.12;
      reasons.push('MATCHES_YOUR_SIZE');
    }
  }

  if (seasonMatches(candidate.seasons, context.season)) {
    score += 0.08;
    reasons.push('IN_SEASON');
  }

  const prevailing = closetModesty(context.items);
  if (
    prevailing &&
    candidate.modesty !== ModestyLevel.UNSPECIFIED &&
    modestyRank(candidate.modesty) >= modestyRank(prevailing)
  ) {
    score += 0.08;
    reasons.push('MATCHES_YOUR_MODESTY');
  }

  const palette = new Set(context.items.flatMap((item) => item.colours));
  if (palette.size && candidate.colours.some((colour) => palette.has(colour))) {
    score += 0.06;
    reasons.push('MATCHES_YOUR_PALETTE');
  }

  // ── What she does not need ────────────────────────────────────────────
  //
  // The half of the job a wishlist cannot do at all. A recommender that only
  // adds points recommends more of what she already has, forever.
  const nearDuplicates = ownedInSlot.filter(
    (item) =>
      item.colours.length &&
      candidate.colours.length &&
      item.colours.some((colour) => candidate.colours.includes(colour)),
  );
  if (nearDuplicates.length >= 2) {
    score -= 0.3;
    reasons.push('DUPLICATE_OF_OWNED');
  } else if (ownedInSlot.length >= 5) {
    score -= 0.15;
    reasons.push('ALREADY_WELL_STOCKED');
  }

  return {
    score: Math.max(-1, Math.min(1, Math.round(score * 1000) / 1000)),
    reasons,
    pairsWithItemIds: partners.map((item) => item.id).slice(0, 8),
    completesLookIds: completed.map((look) => look.id).slice(0, 4),
  };
}
