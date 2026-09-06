import { ClosetSeason, OutfitSlot } from '@prisma/client';
import { coloursHarmonise } from '../../ai-stylist/understanding/stylist-lexicon';
import { ClosetItemFact, ClosetLookFact } from '../gaps/gap-engine';
import { seasonMatches, slotsForOccasion } from '../items/garment-descriptor';

/**
 * "ماذا أستطيع أن أرتدي اليوم؟"
 *
 * Two sources, in one ranked list, and the second is what makes the question
 * answerable at all:
 *
 *   SAVED     — a look she built. Ready to wear, and the strongest answer there
 *               is, because she already decided it works.
 *   COMPOSED  — an outfit assembled here, now, out of pieces she owns and has
 *               never put together. Every wardrobe app that only replays saved
 *               outfits is useless on day one, when there are none; and a woman
 *               with forty garments and three saved looks is being shown a
 *               fraction of what she can actually wear.
 *
 * A composed outfit is not a suggestion to buy anything. It is her own clothes,
 * arranged — which is the whole premise of the closet: the value arrives before
 * any purchase does, and the purchase is a consequence of the wardrobe rather
 * than the point of it.
 *
 * Pure and deterministic. Same closet, same day, same answer — a daily
 * suggestion that reshuffled on every pull-to-refresh would read as noise.
 */

export type OutfitOrigin = 'SAVED' | 'COMPOSED';

export type OutfitReason =
  | 'READY_TO_WEAR'
  | 'NOT_WORN_RECENTLY'
  | 'REDISCOVERED'
  | 'FAVOURITE'
  | 'SEASON_FIT'
  | 'OCCASION_FIT'
  | 'COLOURS_HARMONISE'
  | 'ONE_PIECE_SHORT';

export interface OutfitPiece {
  slot: OutfitSlot;
  itemId: string;
}

export interface OutfitProposal {
  /** Stable across a day for the same closet: the look id, or the piece ids. */
  key: string;
  origin: OutfitOrigin;
  /** Set for SAVED. */
  lookId: string | null;
  pieces: OutfitPiece[];
  /** Slots the outfit wants and she cannot fill. Empty for a wearable outfit. */
  missingSlots: OutfitSlot[];
  occasion: string | null;
  score: number;
  reasons: OutfitReason[];
}

export interface TodayInput {
  items: readonly ClosetItemFact[];
  looks: readonly ClosetLookFact[];
  /** Today, as the caller sees it. Injected so the picker stays testable. */
  now: Date;
  season: ClosetSeason;
  /** Narrow to one occasion, when she asked for one. */
  occasion?: string | null;
  limit?: number;
}

/** Days after which a piece counts as rested rather than recently worn. */
const REST_DAYS = 14;

/** Days of silence after which a piece is being neglected rather than rested. */
const NEGLECT_DAYS = 90;

/**
 * Anchors considered when composing. Bounded so a closet of three hundred
 * pieces still answers in one pass — and generous enough that the answer is not
 * the same four garments every day.
 */
const MAX_ANCHORS = 24;

export function pickTodayOutfits(input: TodayInput): OutfitProposal[] {
  const limit = input.limit ?? 6;
  const wearable = input.items.filter((item) =>
    seasonMatches(item.seasons, input.season),
  );

  const proposals = [
    ...savedProposals(input),
    ...composedProposals({ ...input, items: wearable }),
  ];

  // One outfit per set of pieces. A saved look and a composition that happen to
  // land on the same garments are the same outfit, and SAVED sorts first, so the
  // one that keeps her title wins.
  const seen = new Set<string>();
  return proposals
    .sort((a, b) => {
      if (a.origin !== b.origin) return a.origin === 'SAVED' ? -1 : 1;
      return b.score - a.score || a.key.localeCompare(b.key);
    })
    .filter((proposal) => {
      const signature = proposal.pieces
        .map((piece) => piece.itemId)
        .sort()
        .join('+');
      if (!signature) return true;
      if (seen.has(signature)) return false;
      seen.add(signature);
      return true;
    })
    .sort((a, b) => b.score - a.score || a.key.localeCompare(b.key))
    .slice(0, limit);
}

// ── Saved looks ─────────────────────────────────────────────────────────

function savedProposals(input: TodayInput): OutfitProposal[] {
  const byId = new Map(input.items.map((item) => [item.id, item]));

  return input.looks
    .filter((look) => {
      if (input.occasion && look.occasion !== input.occasion) return false;
      return seasonMatches(look.seasons, input.season);
    })
    .map((look) => {
      const pieces = look.ownedSlots
        .map((slot) => {
          const item = input.items.find((candidate) => candidate.slot === slot);
          return item ? { slot, itemId: item.id } : null;
        })
        .filter((piece): piece is OutfitPiece => piece !== null);

      const reasons: OutfitReason[] = [];
      const components: number[] = [];

      // A complete look is the answer to the question as asked. An incomplete
      // one still appears — she may own most of it — but it can never outrank
      // something she can put on.
      const complete = look.wantedSlots.length === 0;
      if (complete) {
        components.push(40);
        reasons.push('READY_TO_WEAR');
      } else {
        components.push(14);
        if (look.wantedSlots.length === 1) reasons.push('ONE_PIECE_SHORT');
      }

      if (look.isFavourite) {
        components.push(10);
        reasons.push('FAVOURITE');
      }

      const rest = restScore(
        look.ownedSlots.length
          ? pieces.map((piece) => byId.get(piece.itemId)?.lastWornAt ?? null)
          : [],
        input.now,
      );
      components.push(rest.score);
      if (rest.reason) reasons.push(rest.reason);

      if (input.occasion && look.occasion === input.occasion) {
        components.push(12);
        reasons.push('OCCASION_FIT');
      }

      return {
        key: look.id,
        origin: 'SAVED' as const,
        lookId: look.id,
        pieces,
        missingSlots: [...look.wantedSlots],
        occasion: look.occasion,
        score: sum(components),
        reasons,
      };
    });
}

// ── Composition ─────────────────────────────────────────────────────────

/**
 * Assemble outfits out of pieces she owns.
 *
 * Anchor first — a dress, an abaya, or a top-and-bottom pair — then the
 * supporting slots. Shoes are required, because an outfit is not wearable
 * without them and pretending otherwise would put an unwearable card at the top
 * of her morning.
 */
function composedProposals(input: TodayInput): OutfitProposal[] {
  const bySlot = new Map<OutfitSlot, ClosetItemFact[]>();
  for (const item of input.items) {
    const list = bySlot.get(item.slot) ?? [];
    list.push(item);
    bySlot.set(item.slot, list);
  }

  // Least recently worn first, so the composer reaches for what she has been
  // ignoring instead of the same dress every morning.
  for (const list of bySlot.values()) {
    list.sort((a, b) => {
      const left = a.lastWornAt?.getTime() ?? 0;
      const right = b.lastWornAt?.getTime() ?? 0;
      return left - right || a.id.localeCompare(b.id);
    });
  }

  const wantedSlots = input.occasion ? slotsForOccasion(input.occasion) : [];
  const shoes = bySlot.get(OutfitSlot.SHOES) ?? [];

  const anchors: Array<{ pieces: OutfitPiece[]; colours: string[] }> = [];

  // One-piece anchors.
  for (const slot of [OutfitSlot.DRESS, OutfitSlot.ABAYA]) {
    for (const item of (bySlot.get(slot) ?? []).slice(0, MAX_ANCHORS)) {
      if (input.occasion && !item.occasions.includes(input.occasion)) continue;
      anchors.push({
        pieces: [{ slot, itemId: item.id }],
        colours: item.colours,
      });
    }
  }

  // Two-piece anchors, colour-checked against each other.
  const tops = bySlot.get(OutfitSlot.TOP) ?? [];
  const bottoms = bySlot.get(OutfitSlot.BOTTOM) ?? [];
  for (const top of tops.slice(0, MAX_ANCHORS)) {
    if (input.occasion && !top.occasions.includes(input.occasion)) continue;
    for (const bottom of bottoms.slice(0, MAX_ANCHORS)) {
      if (input.occasion && !bottom.occasions.includes(input.occasion)) continue;
      if (!harmonise(top.colours, bottom.colours)) continue;
      anchors.push({
        pieces: [
          { slot: OutfitSlot.TOP, itemId: top.id },
          { slot: OutfitSlot.BOTTOM, itemId: bottom.id },
        ],
        colours: [...top.colours, ...bottom.colours],
      });
    }
  }

  const byId = new Map(input.items.map((item) => [item.id, item]));
  const out: OutfitProposal[] = [];

  for (const anchor of anchors.slice(0, MAX_ANCHORS * 2)) {
    const pieces = [...anchor.pieces];
    const reasons: OutfitReason[] = [];
    const components: number[] = [26];
    const missing: OutfitSlot[] = [];

    const shoe = shoes.find((item) => harmonise(item.colours, anchor.colours));
    if (shoe) {
      pieces.push({ slot: OutfitSlot.SHOES, itemId: shoe.id });
    } else {
      missing.push(OutfitSlot.SHOES);
    }

    // Finishing pieces. Absent ones are not "missing" unless the occasion asked
    // for them — a woman without a handbag is dressed.
    for (const slot of [OutfitSlot.OUTERWEAR, OutfitSlot.BAG, OutfitSlot.JEWELRY]) {
      if (slot === OutfitSlot.OUTERWEAR && input.season !== ClosetSeason.WINTER) continue;
      const found = (bySlot.get(slot) ?? []).find((item) =>
        harmonise(item.colours, anchor.colours),
      );
      if (found) pieces.push({ slot, itemId: found.id });
      else if (wantedSlots.includes(slot)) missing.push(slot);
    }

    if (anchor.colours.length > 1) {
      components.push(6);
      reasons.push('COLOURS_HARMONISE');
    }
    components.push(8);
    reasons.push('SEASON_FIT');

    if (input.occasion) {
      components.push(10);
      reasons.push('OCCASION_FIT');
    }

    const rest = restScore(
      pieces.map((piece) => byId.get(piece.itemId)?.lastWornAt ?? null),
      input.now,
    );
    components.push(rest.score);
    if (rest.reason) reasons.push(rest.reason);

    if (pieces.some((piece) => byId.get(piece.itemId)?.isFavourite)) {
      components.push(6);
      reasons.push('FAVOURITE');
    }

    // An outfit she cannot complete is worth showing — it is the honest answer
    // when she owns no shoes — but never above one she can walk out in.
    if (missing.length) components.push(-18);

    out.push({
      key: pieces
        .map((piece) => piece.itemId)
        .sort()
        .join('+'),
      origin: 'COMPOSED',
      lookId: null,
      pieces,
      missingSlots: missing,
      occasion: input.occasion ?? null,
      score: sum(components),
      reasons,
    });
  }

  return out;
}

/**
 * How rested the pieces are.
 *
 * Rotation is the quiet value of a wardrobe log: the point is not to tell her
 * what is nicest, it is to stop her wearing the same three things and forgetting
 * the rest. So a garment untouched for a season scores above one worn on
 * Tuesday, and something buried for months earns its own reason code.
 */
function restScore(
  lastWorn: ReadonlyArray<Date | null>,
  now: Date,
): { score: number; reason: OutfitReason | null } {
  if (!lastWorn.length) return { score: 0, reason: null };

  const days = lastWorn.map((date) =>
    date === null
      ? Number.POSITIVE_INFINITY
      : Math.floor((now.getTime() - date.getTime()) / 86_400_000),
  );
  // The most recently worn piece decides: an outfit is only as fresh as the
  // blouse she wore yesterday.
  const freshest = Math.min(...days);

  if (freshest >= NEGLECT_DAYS) return { score: 18, reason: 'REDISCOVERED' };
  if (freshest >= REST_DAYS) return { score: 12, reason: 'NOT_WORN_RECENTLY' };
  // Worn in the last fortnight: no bonus, and a penalty inside three days.
  return { score: freshest <= 3 ? -10 : 0, reason: null };
}

function harmonise(left: readonly string[], right: readonly string[]): boolean {
  if (!left.length || !right.length) return true;
  return left.some((colour) => right.some((other) => coloursHarmonise(colour, other)));
}

function sum(values: readonly number[]): number {
  return Math.round(values.reduce((acc, value) => acc + value, 0) * 100) / 100;
}
