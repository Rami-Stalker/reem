import { ClosetGapKind, ClosetSeason, ModestyLevel, OutfitSlot } from '@prisma/client';
import {
  COLOURS,
  coloursHarmonise,
  slotEntry,
} from '../../ai-stylist/understanding/stylist-lexicon';
import { seasonMatches, slotsForOccasion } from '../items/garment-descriptor';

/**
 * The gap engine.
 *
 * A pure function from a snapshot of her closet to the list of things missing
 * from it. No database, no network, no model — the same inputs give the same
 * gaps with the same priorities and the same arithmetic behind them, which is
 * what lets a screen say "لأنو عندك ٦ بلوزات وتنورة وحدة" and be telling the
 * literal truth.
 *
 * Five rules run, in descending order of how concrete the need is:
 *
 *   LOOK_SLOT   — a look she saved has an empty slot. She has already decided
 *                 she wants this outfit; one piece stands between her and it.
 *   OCCASION    — she has an occasion in her closet's vocabulary and cannot
 *                 complete a single look for it.
 *   SEASON      — the season now under way is uncovered in a slot she otherwise
 *                 lives in. Ranked above COVERAGE because when both fire they
 *                 ask for the same garment and only this one can explain why.
 *   COVERAGE    — the structural rule, and the one that makes this a wardrobe
 *                 tool rather than a list. Priority is the *marginal outfit
 *                 gain*: how many additional complete outfits one more piece in
 *                 this slot would unlock. Six tops and one skirt is not a
 *                 problem because six is a lot; it is a problem because the
 *                 seventh top adds nothing and the second skirt adds six.
 *   REPLACEMENT — worn past what a garment lasts, with nothing behind it.
 *
 * Every rule emits constraints (`suggestedColours`, `suggestedSize`, the budget
 * band) read out of what she already owns, never out of the catalog. That is
 * what "اقتراح منتجات بناءً على القطع الموجودة فعليًا" means concretely: the
 * search is shaped by her wardrobe before it ever touches a product table.
 */

// ── Input ───────────────────────────────────────────────────────────────

/** One garment, reduced to what the engine reasons about. */
export interface ClosetItemFact {
  id: string;
  slot: OutfitSlot;
  colours: string[];
  materials: string[];
  modesty: ModestyLevel;
  seasons: ClosetSeason[];
  occasions: string[];
  size: string | null;
  wearCount: number;
  lastWornAt: Date | null;
  acquiredAt: Date | null;
  purchasePriceSyp: number | null;
  isFavourite: boolean;
}

/** One saved look, with its slots already resolved into owned and wanted. */
export interface ClosetLookFact {
  id: string;
  title: string;
  occasion: string | null;
  seasons: ClosetSeason[];
  palette: string[];
  isFavourite: boolean;
  /** Slots filled by a piece she owns. */
  ownedSlots: OutfitSlot[];
  /** Slots pointing at a catalog product she does not own yet. */
  wantedSlots: OutfitSlot[];
  updatedAt: Date;
}

export interface ClosetSnapshot {
  items: readonly ClosetItemFact[];
  looks: readonly ClosetLookFact[];
  now: Date;
  season: ClosetSeason;
  /**
   * The band she actually buys in, from `UserStylePreference`. Used only as a
   * fallback: a slot she already owns pieces in prices itself off those.
   */
  typicalBudgetSyp: { min: number | null; max: number | null } | null;
  /** Fingerprints she has dismissed. Suppressed rather than re-raised. */
  dismissedFingerprints: ReadonlySet<string>;
}

// ── Output ──────────────────────────────────────────────────────────────

export interface ComputedGap {
  fingerprint: string;
  kind: ClosetGapKind;
  slot: OutfitSlot;
  occasion: string | null;
  season: ClosetSeason | null;
  lookId: string | null;
  /** 0–100. */
  priority: number;
  /** The arithmetic, kept so any figure on screen can be taken apart. */
  components: Record<string, number>;
  suggestedColours: string[];
  suggestedSize: string | null;
  suggestedBudgetMinSyp: number | null;
  suggestedBudgetMaxSyp: number | null;
}

/**
 * The identity of a gap, flattened to a string.
 *
 * Recompute has to be idempotent — it runs on every closet write — and the
 * natural key spans four nullable columns, which Postgres would treat as
 * distinct on every pass and duplicate forever. Flattening the same tuple with
 * empty segments preserved gives a value a unique index can actually hold.
 *
 * Order and separator are part of the contract: a dismissal recorded today must
 * still suppress the same gap next month, so this function may gain segments at
 * the end but must never reorder the ones it has.
 */
export function gapFingerprint(input: {
  kind: ClosetGapKind;
  slot: OutfitSlot;
  occasion?: string | null;
  season?: ClosetSeason | null;
  lookId?: string | null;
}): string {
  return [
    input.kind,
    input.slot,
    input.occasion ?? '',
    input.season ?? '',
    input.lookId ?? '',
  ].join(':');
}

// ── Capacity ────────────────────────────────────────────────────────────

/**
 * The slots a daily outfit is actually built out of.
 *
 * Jewellery, perfume and bags are left out on purpose. They finish a look, they
 * do not make one possible, and counting them would let a closet of twelve
 * necklaces and no shoes report a healthy outfit count.
 */
const CAPACITY_SLOTS: readonly OutfitSlot[] = [
  OutfitSlot.DRESS,
  OutfitSlot.ABAYA,
  OutfitSlot.TOP,
  OutfitSlot.BOTTOM,
  OutfitSlot.SHOES,
];

export type SlotCounts = ReadonlyMap<OutfitSlot, number>;

/**
 * How many distinct complete outfits this closet can produce.
 *
 * A one-piece garment is one outfit; a top and a bottom combine, so the pair
 * count is bounded by whichever she has fewer of. Shoes multiply rather than
 * add, because an outfit without them is not an outfit — which also gives the
 * right answer at zero: a woman with ten dresses and no shoes has a capacity of
 * nought, and the first pair of shoes unlocks all ten at once.
 *
 * Crude, and deliberately so. Its job is not to be a true count of what she can
 * wear — no arithmetic knows that a blazer clashes with those trousers — but to
 * be a *comparable* number, so the difference between it and its value with one
 * more piece is a defensible reason to buy that piece.
 */
export function outfitCapacity(counts: SlotCounts): number {
  const at = (slot: OutfitSlot) => counts.get(slot) ?? 0;
  const onePiece = at(OutfitSlot.DRESS) + at(OutfitSlot.ABAYA);
  const twoPiece = Math.min(at(OutfitSlot.TOP), at(OutfitSlot.BOTTOM));
  return (onePiece + twoPiece) * Math.min(at(OutfitSlot.SHOES), 1);
}

/** What capacity would become with one more piece in `slot`. */
export function marginalCapacityGain(counts: SlotCounts, slot: OutfitSlot): number {
  const next = new Map(counts);
  next.set(slot, (counts.get(slot) ?? 0) + 1);
  return outfitCapacity(next) - outfitCapacity(counts);
}

function countBySlot(
  items: readonly ClosetItemFact[],
  season?: ClosetSeason,
): Map<OutfitSlot, number> {
  const counts = new Map<OutfitSlot, number>();
  for (const item of items) {
    if (season && !seasonMatches(item.seasons, season)) continue;
    counts.set(item.slot, (counts.get(item.slot) ?? 0) + 1);
  }
  return counts;
}

// ── Constraints derived from what she owns ──────────────────────────────

/**
 * Colours that would sit with a palette.
 *
 * Returns the lexicon keys harmonising with *every* colour given, so a suggested
 * piece works with the whole look rather than with one item in it. Neutrals win
 * this test constantly, which is correct — a closet short of one slot is best
 * served by something that goes with everything already in it.
 *
 * An empty palette yields an empty list, not every colour: "no constraint" and
 * "all twenty colours" reach retrieval as very different queries.
 */
export function harmonisingColours(palette: readonly string[], limit = 4): string[] {
  if (!palette.length) return [];
  return COLOURS.filter((entry) =>
    palette.every((colour) => coloursHarmonise(entry.key, colour)),
  )
    .map((entry) => entry.key)
    .slice(0, limit);
}

/** The colours this closet is actually built on, most-owned first. */
function dominantColours(items: readonly ClosetItemFact[], limit = 3): string[] {
  const weights = new Map<string, number>();
  for (const item of items) {
    for (const colour of item.colours) {
      weights.set(colour, (weights.get(colour) ?? 0) + 1);
    }
  }
  return [...weights.entries()]
    .sort((a, b) => b[1] - a[1] || a[0].localeCompare(b[0]))
    .slice(0, limit)
    .map(([colour]) => colour);
}

/**
 * The size she wears in this slot, from the pieces she already owns.
 *
 * Modal rather than latest: one mis-typed size should not redirect every future
 * suggestion. Ties break on the alphabetically first value so the answer is
 * stable across runs — an unstable size would change the suggestions under her
 * for no reason she could see.
 */
export function modalSize(
  items: readonly ClosetItemFact[],
  slot: OutfitSlot,
): string | null {
  const system = slotEntry(slot).sizeSystem;
  if (!system) return null;

  const counts = new Map<string, number>();
  for (const item of items) {
    if (item.slot !== slot || !item.size) continue;
    counts.set(item.size, (counts.get(item.size) ?? 0) + 1);
  }
  if (!counts.size) {
    // Nothing in this slot yet — borrow from any slot on the same size system,
    // which is the whole point of the system being on the slot entry.
    for (const item of items) {
      if (!item.size || slotEntry(item.slot).sizeSystem !== system) continue;
      counts.set(item.size, (counts.get(item.size) ?? 0) + 1);
    }
  }
  if (!counts.size) return null;

  return [...counts.entries()].sort(
    (a, b) => b[1] - a[1] || a[0].localeCompare(b[0]),
  )[0][0];
}

/**
 * What she spends on this kind of piece.
 *
 * Priced off her own closet when it can be: the median of what she paid for
 * pieces in this slot, widened by half in each direction. That band is a far
 * better description of her than a global budget, because a woman who spends
 * freely on dresses may not spend at all on shoes.
 *
 * Falls back to her stated/derived band, and then to nothing — an absent budget
 * is a brief without a budget constraint, which retrieval handles.
 */
export function budgetBandFor(
  items: readonly ClosetItemFact[],
  slot: OutfitSlot,
  fallback: { min: number | null; max: number | null } | null,
): { min: number | null; max: number | null } {
  const prices = items
    .filter((item) => item.slot === slot && item.purchasePriceSyp !== null)
    .map((item) => item.purchasePriceSyp as number)
    .sort((a, b) => a - b);

  if (prices.length) {
    const median = prices[Math.floor(prices.length / 2)];
    return { min: Math.round(median * 0.5), max: Math.round(median * 1.5) };
  }
  return { min: fallback?.min ?? null, max: fallback?.max ?? null };
}

// ── The rules ───────────────────────────────────────────────────────────

/** Ceiling on how many gaps one closet may hold open at once. */
const MAX_GAPS = 12;

/** Wears past which a garment is considered spent. */
const REPLACEMENT_WEARS = 30;

/** Days a piece must have been owned before wear counts as wear and tear. */
const REPLACEMENT_AGE_DAYS = 240;

export function computeGaps(snapshot: ClosetSnapshot): ComputedGap[] {
  const active = snapshot.items;
  // Order is load-bearing: the de-duplication below keeps the first gap to claim
  // a slot, so the rules run most-explanatory first. SEASON precedes COVERAGE
  // because both can ask for a dress and only one of them can say why she has
  // nothing to wear today — "عندك ٢ فساتين بس مو للجو" beats "خزانتك ناقصها
  // فستان" when both are true.
  const gaps: ComputedGap[] = [
    ...lookSlotGaps(snapshot, active),
    ...occasionGaps(snapshot, active),
    ...seasonGaps(snapshot, active),
    ...coverageGaps(snapshot, active),
    ...replacementGaps(snapshot, active),
  ];

  const seen = new Set<string>();
  return gaps
    .filter((gap) => {
      if (snapshot.dismissedFingerprints.has(gap.fingerprint)) return false;
      // The rules overlap on purpose — a look missing shoes in a closet with no
      // shoes is both a LOOK_SLOT and a COVERAGE gap. First one wins, and the
      // rules run in order of concreteness, so the winner is the one that can
      // name the outfit it would complete.
      if (seen.has(`${gap.slot}:${gap.occasion ?? ''}`)) return false;
      seen.add(`${gap.slot}:${gap.occasion ?? ''}`);
      return true;
    })
    .sort((a, b) => b.priority - a.priority || a.fingerprint.localeCompare(b.fingerprint))
    .slice(0, MAX_GAPS);
}

/**
 * Looks she saved that are one piece short.
 *
 * `wantedSlots` — slots already pointed at a catalog product — count as gaps
 * too. She has picked the thing; the gap keeps it in front of her, and it fills
 * the moment the piece enters her closet.
 */
function lookSlotGaps(
  snapshot: ClosetSnapshot,
  items: readonly ClosetItemFact[],
): ComputedGap[] {
  const out: ComputedGap[] = [];

  for (const look of snapshot.looks) {
    const wanted = slotsForOccasion(look.occasion ?? '');
    const owned = new Set(look.ownedSlots);

    // Two kinds of missing, and conflating them makes the engine pushy.
    //
    // A slot she *placed* and cannot fill is a stated intention. A slot the
    // occasion's table merely implies is our idea, and only worth raising when
    // the outfit is not wearable without it — a wedding look with a dress, shoes
    // and a bag on the way is finished, whatever the lexicon says about perfume.
    const chosen = new Set<OutfitSlot>(look.wantedSlots);
    const implied = wanted.filter(
      (slot) => !owned.has(slot) && !chosen.has(slot) && CAPACITY_SLOTS.includes(slot),
    );
    const missing = new Set<OutfitSlot>([...chosen, ...implied]);
    if (!missing.size) continue;

    // One piece from complete is a different proposition from four, and it is
    // the single strongest signal in the engine. Measured against what she
    // chose: an outfit she can wear tomorrow is nearly complete even if some
    // table thinks it wants a necklace.
    const nearlyComplete = chosen.size === 1 && implied.length === 0;

    for (const slot of missing) {
      const base = 55;
      const components: Record<string, number> = {
        base,
        nearly_complete: nearlyComplete ? 20 : 0,
        favourite_look: look.isFavourite ? 10 : 0,
        // A slot the occasion names outranks one she added by hand: the
        // occasion's own table says a wedding needs shoes.
        core_slot: wanted.includes(slot) ? 8 : 0,
        already_chosen: look.wantedSlots.includes(slot) ? 7 : 0,
        season_fit: seasonMatches(look.seasons, snapshot.season) ? 5 : 0,
      };

      const palette = look.palette.length ? look.palette : dominantColours(items);
      const budget = budgetBandFor(items, slot, snapshot.typicalBudgetSyp);

      out.push({
        fingerprint: gapFingerprint({
          kind: ClosetGapKind.LOOK_SLOT,
          slot,
          occasion: look.occasion,
          lookId: look.id,
        }),
        kind: ClosetGapKind.LOOK_SLOT,
        slot,
        occasion: look.occasion,
        season: null,
        lookId: look.id,
        priority: total(components),
        components,
        suggestedColours: harmonisingColours(palette),
        suggestedSize: modalSize(items, slot),
        suggestedBudgetMinSyp: budget.min,
        suggestedBudgetMaxSyp: budget.max,
      });
    }
  }

  return out;
}

/**
 * Occasions she cannot dress for.
 *
 * The set considered is drawn from her own closet — the occasions her pieces
 * and her looks already mention — rather than from the full lexicon. Telling a
 * woman who has never mentioned a wedding that she has no wedding outfit is a
 * catalog talking, not a wardrobe.
 */
function occasionGaps(
  snapshot: ClosetSnapshot,
  items: readonly ClosetItemFact[],
): ComputedGap[] {
  const interest = new Map<string, number>();
  for (const item of items) {
    for (const key of item.occasions) {
      interest.set(key, (interest.get(key) ?? 0) + 1);
    }
  }
  // A look she built for an occasion is a far louder statement of interest than
  // a piece that merely happens to suit one.
  for (const look of snapshot.looks) {
    if (look.occasion) interest.set(look.occasion, (interest.get(look.occasion) ?? 0) + 5);
  }

  const out: ComputedGap[] = [];

  for (const [occasion, weight] of interest) {
    // Fewer than two signals is noise, not an interest.
    if (weight < 2) continue;

    const slots = slotsForOccasion(occasion);
    if (!slots.length) continue;

    // Only the slots that actually make the outfit possible. Missing a perfume
    // for Eid is not a reason to tell her she has nothing to wear.
    const core = slots.filter((slot) => CAPACITY_SLOTS.includes(slot));
    const eligible = (slot: OutfitSlot) =>
      items.some((item) => item.slot === slot && item.occasions.includes(occasion));

    // If she can already make one outfit for it, there is no occasion gap —
    // whatever else is thin will surface as COVERAGE.
    const oneWearable = core.filter(eligible);
    const hasOnePiece =
      oneWearable.includes(OutfitSlot.DRESS) || oneWearable.includes(OutfitSlot.ABAYA);
    const hasPair =
      oneWearable.includes(OutfitSlot.TOP) && oneWearable.includes(OutfitSlot.BOTTOM);
    if (hasOnePiece || hasPair) continue;

    for (const slot of core) {
      if (eligible(slot)) continue;

      const components: Record<string, number> = {
        base: 40,
        interest: Math.min(weight * 2, 14),
        // The garment that carries the occasion on its own beats the pieces
        // that only work in combination.
        anchor_slot:
          slot === OutfitSlot.DRESS || slot === OutfitSlot.ABAYA ? 10 : 0,
        owns_nothing: items.some((item) => item.slot === slot) ? 0 : 6,
      };

      const budget = budgetBandFor(items, slot, snapshot.typicalBudgetSyp);

      out.push({
        fingerprint: gapFingerprint({
          kind: ClosetGapKind.OCCASION,
          slot,
          occasion,
        }),
        kind: ClosetGapKind.OCCASION,
        slot,
        occasion,
        season: null,
        lookId: null,
        priority: total(components),
        components,
        suggestedColours: harmonisingColours(dominantColours(items)),
        suggestedSize: modalSize(items, slot),
        suggestedBudgetMinSyp: budget.min,
        suggestedBudgetMaxSyp: budget.max,
      });
    }
  }

  return out;
}

/**
 * The structural rule: what would unlock the most outfits.
 *
 * This is the one that reads a wardrobe rather than a list. For each slot that
 * outfits are built from, it asks what capacity would become with one more
 * piece there, and keeps the slots where the answer is a real gain. A closet of
 * six tops and one skirt reports the skirt, because the seventh top gains
 * nothing and the second skirt gains six.
 */
function coverageGaps(
  snapshot: ClosetSnapshot,
  items: readonly ClosetItemFact[],
): ComputedGap[] {
  // Counted against the season under way: a winter coat does not help her get
  // dressed in July, and neither does the capacity it contributes.
  const counts = countBySlot(items, snapshot.season);
  const capacity = outfitCapacity(counts);

  // An empty closet has nothing to be structurally short of. It gets the
  // onboarding flow, not five gap cards saying it owns nothing.
  if (items.length < 3) return [];

  const out: ComputedGap[] = [];

  for (const slot of CAPACITY_SLOTS) {
    const gain = marginalCapacityGain(counts, slot);
    if (gain < 1) continue;

    const owned = counts.get(slot) ?? 0;

    const components: Record<string, number> = {
      base: 30,
      // The heart of it: outfits unlocked, flattened so one heroic slot cannot
      // crowd out everything else on the screen.
      outfit_gain: Math.min(gain * 6, 30),
      // Owning none of something outfits need is worse than owning few.
      owns_none: owned === 0 ? 12 : 0,
      // A closet that cannot dress her at all is the most urgent state there is.
      unlocks_first_outfit: capacity === 0 ? 10 : 0,
    };

    const budget = budgetBandFor(items, slot, snapshot.typicalBudgetSyp);

    out.push({
      fingerprint: gapFingerprint({ kind: ClosetGapKind.COVERAGE, slot }),
      kind: ClosetGapKind.COVERAGE,
      slot,
      occasion: null,
      season: null,
      lookId: null,
      priority: total(components),
      components: { ...components, outfits_unlocked: gain, outfits_now: capacity },
      suggestedColours: harmonisingColours(dominantColours(items)),
      suggestedSize: modalSize(items, slot),
      suggestedBudgetMinSyp: budget.min,
      suggestedBudgetMaxSyp: budget.max,
    });
  }

  return out;
}

/**
 * Slots she lives in that the current season has emptied.
 *
 * Requires that she own pieces in the slot already — otherwise this fires on
 * every slot she has never used and says nothing about the season at all.
 */
function seasonGaps(
  snapshot: ClosetSnapshot,
  items: readonly ClosetItemFact[],
): ComputedGap[] {
  if (snapshot.season === ClosetSeason.ALL) return [];

  const all = countBySlot(items);
  const inSeason = countBySlot(items, snapshot.season);
  const out: ComputedGap[] = [];

  for (const slot of CAPACITY_SLOTS) {
    const owned = all.get(slot) ?? 0;
    if (owned < 2) continue;
    if ((inSeason.get(slot) ?? 0) > 0) continue;

    const components: Record<string, number> = {
      base: 34,
      // The more she owns in a slot she cannot use right now, the sharper the
      // absence — a woman with five unwearable skirts notices.
      shelved: Math.min(owned * 3, 12),
    };

    const budget = budgetBandFor(items, slot, snapshot.typicalBudgetSyp);

    out.push({
      fingerprint: gapFingerprint({
        kind: ClosetGapKind.SEASON,
        slot,
        season: snapshot.season,
      }),
      kind: ClosetGapKind.SEASON,
      slot,
      occasion: null,
      season: snapshot.season,
      lookId: null,
      priority: total(components),
      components: { ...components, owned_out_of_season: owned },
      suggestedColours: harmonisingColours(dominantColours(items)),
      suggestedSize: modalSize(items, slot),
      suggestedBudgetMinSyp: budget.min,
      suggestedBudgetMaxSyp: budget.max,
    });
  }

  return out;
}

/**
 * Pieces worn out, with nothing behind them.
 *
 * Both conditions matter. High wear alone is a favourite, not a problem — and
 * telling a woman her favourite dress is worn out is presumptuous. High wear
 * *and* no alternative in the slot is a wardrobe about to have a hole in it.
 */
function replacementGaps(
  snapshot: ClosetSnapshot,
  items: readonly ClosetItemFact[],
): ComputedGap[] {
  const counts = countBySlot(items);
  const out: ComputedGap[] = [];

  for (const item of items) {
    if (item.wearCount < REPLACEMENT_WEARS) continue;
    if ((counts.get(item.slot) ?? 0) > 1) continue;

    const ageDays = item.acquiredAt
      ? Math.floor((snapshot.now.getTime() - item.acquiredAt.getTime()) / 86_400_000)
      : null;
    // Thirty wears in a fortnight is a logging habit, not a worn-out garment.
    if (ageDays !== null && ageDays < REPLACEMENT_AGE_DAYS) continue;

    const components: Record<string, number> = {
      base: 28,
      wear: Math.min((item.wearCount - REPLACEMENT_WEARS) * 0.5, 12),
      sole_in_slot: 8,
    };

    // Priced off the piece being replaced when we know what it cost — she is
    // buying the same thing again, not shopping the category afresh.
    const budget = item.purchasePriceSyp
      ? {
          min: Math.round(item.purchasePriceSyp * 0.6),
          max: Math.round(item.purchasePriceSyp * 1.6),
        }
      : budgetBandFor(items, item.slot, snapshot.typicalBudgetSyp);

    out.push({
      fingerprint: gapFingerprint({
        kind: ClosetGapKind.REPLACEMENT,
        slot: item.slot,
      }),
      kind: ClosetGapKind.REPLACEMENT,
      slot: item.slot,
      occasion: null,
      season: null,
      lookId: null,
      priority: total(components),
      components: { ...components, wear_count: item.wearCount },
      // Replacing something means replacing its colour, not harmonising with it.
      suggestedColours: item.colours.slice(0, 3),
      suggestedSize: item.size ?? modalSize(items, item.slot),
      suggestedBudgetMinSyp: budget.min,
      suggestedBudgetMaxSyp: budget.max,
    });
  }

  return out;
}

/** Components to a 0–100 priority. Clamped, so no rule can shout over the rest. */
function total(components: Record<string, number>): number {
  const sum = Object.values(components).reduce((acc, value) => acc + value, 0);
  return Math.max(0, Math.min(100, Math.round(sum * 100) / 100));
}
