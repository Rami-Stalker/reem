/**
 * What Reem has to say about one product, to one woman.
 *
 * The whole of phase three's user-facing half comes out of this function. It
 * takes what the graph knows about her and what the catalogue knows about the
 * product, and returns *notes* — small, ordered, explainable statements, each
 * carrying the evidence that produced it.
 *
 * ── Why notes and not a score ────────────────────────────────────────────
 *
 * A relevance score tells her nothing she can argue with. "You already own two
 * navy dresses" is a fact she can check, disagree with, and act on. So the
 * output is sentences with their working attached, and the ranking of the
 * sentences is the only judgement the system makes.
 *
 * ── Why it can say nothing ───────────────────────────────────────────────
 *
 * Most products, most of the time, deserve no note at all. A layer that always
 * has an opinion is a layer nobody believes: the empty result is the common
 * case and the honest one, and every rule below is written to fire only when
 * it has real evidence rather than to fill a slot on a screen.
 *
 * Pure. No database, no clock beyond what it is handed, no model.
 */

import { ModestyLevel } from '@prisma/client';

export type VerdictCode =
  /// It goes with pieces she already owns.
  | 'SUITS_YOUR_CLOSET'
  /// She has something close enough that this would be a duplicate.
  | 'ALREADY_OWN_SIMILAR'
  /// It fills a gap in a look she has saved.
  | 'COMPLETES_LOOK'
  /// A near-identical piece costs meaningfully less.
  | 'BETTER_VALUE'
  /// Demand for it is climbing.
  | 'RISING_DEMAND'
  /// It answers what she has been searching for.
  | 'MATCHES_INTENT'
  /// From a shop she has bought from before.
  | 'TRUSTED_SELLER'
  /// It suits the occasion she is shopping for.
  | 'FITS_OCCASION'
  /// It is about to run out.
  | 'LAST_FEW';

export type VerdictTone = 'encourage' | 'caution' | 'inform';

export interface Verdict {
  code: VerdictCode;
  tone: VerdictTone;
  /** 0-100. Only used to order them; never shown. */
  confidence: number;
  ar: string;
  /** The rows behind the sentence, so a screen can link to them. */
  evidence: Record<string, unknown>;
}

// ── What the kernel is given ─────────────────────────────────────────────

/** One garment she owns, reduced to what matters for a comparison. */
export interface OwnedPiece {
  itemId: string;
  title: string;
  slot: string | null;
  colours: readonly string[];
  categoryId: string | null;
}

/** A slot a saved look is short of. */
export interface OpenLook {
  lookId: string;
  title: string;
  missingSlots: readonly string[];
  occasion: string | null;
}

/** A cheaper near-equivalent the graph found. */
export interface ValueAlternative {
  productId: string;
  title: string;
  savingBps: number;
  score: number;
}

export interface ProductFacts {
  productId: string;
  title: string;
  categoryId: string;
  slot: string | null;
  colours: readonly string[];
  occasions: readonly string[];
  modesty: ModestyLevel;
  priceSyp: number | null;
  sellerIds: readonly string[];
  stockUnits: number;
  /** Views in the recent half of the window, against the half before it. */
  recentViews: number;
  previousViews: number;
}

export interface ShopperFacts {
  /** Her wardrobe, from Reem Closet. */
  owns: readonly OwnedPiece[];
  /** Saved looks that are still missing something. */
  openLooks: readonly OpenLook[];
  /** Occasion keys she has shopped for, strongest first. */
  occasions: readonly string[];
  /** Normalised search terms she has used, with the raw display text. */
  terms: readonly { key: string; display: string }[];
  /**
   * Sellers she has bought from **more than once**.
   *
   * Repeat buyers only, and that is the whole point. Every seller she has ever
   * bought a single thing from covered most of the catalogue, so the note fired
   * on 88 of 100 products — 56% of everything Reem said. A sentence that
   * appears on nearly every page is wallpaper: it stops being read, and it
   * crowds out the notes that are actually about this product.
   *
   * Twice is a relationship. Once is a transaction.
   */
  boughtFromSellerIds: readonly string[];
  /** Slots a closet gap or room decision says she is short of. */
  needsSlots: readonly string[];
}

// ── Thresholds ───────────────────────────────────────────────────────────

/** A duplicate needs the same slot and a real colour overlap, not just a slot. */
const DUPLICATE_MIN_COLOUR_OVERLAP = 0.5;

/** Growth at which demand counts as climbing. */
const RISING_GROWTH = 0.3;

/** Views below which growth is noise. */
const RISING_MIN_VIEWS = 20;

/** Stock at or below which "last few" is true rather than a nudge. */
const LAST_FEW = 3;

const round = (n: number, dp = 2): number => {
  const f = 10 ** dp;
  return Math.round(n * f) / f;
};

function colourOverlap(a: readonly string[], b: readonly string[]): number {
  if (!a.length || !b.length) return 0;
  const set = new Set(a);
  return b.filter((x) => set.has(x)).length / Math.max(a.length, b.length);
}

// ── The kernel ───────────────────────────────────────────────────────────

export function verdictsFor(input: {
  product: ProductFacts;
  shopper: ShopperFacts;
  alternative: ValueAlternative | null;
  /** Pieces of hers the graph says this pairs with. */
  pairsWith: readonly OwnedPiece[];
  /**
   * Pieces of hers the graph says are *like* this one.
   *
   * The stronger half of the duplicate test. Colour matching alone could only
   * fire when both the garment and the listing named a colour, and most
   * listings do not — «فستان سهرة بأكمام منفوخة» names a sleeve, not a shade —
   * so the note the whole design is proudest of almost never appeared.
   */
  ownsSimilar?: readonly OwnedPiece[];
}): Verdict[] {
  const { product, shopper, alternative, pairsWith } = input;
  const ownsSimilar = input.ownsSimilar ?? [];
  const out: Verdict[] = [];

  // ── Does she already have one? ────────────────────────────────────────
  //
  // Deliberately the first test and the only one with a cautioning tone. A
  // shop that stops a woman buying a fourth navy dress earns more trust than
  // one that sells it to her, and this is the note Reem should be proudest of.
  // Two routes to the same conclusion. The graph's own similarity is the
  // better one — it compares slot, colour, fabric, occasion and price — and
  // the colour test remains for pieces she typed in herself, which never
  // reach the affinity table because they are not catalogue products.
  const byGraph = new Set(ownsSimilar.map((piece) => piece.itemId));
  const duplicates = shopper.owns.filter(
    (piece) =>
      byGraph.has(piece.itemId) ||
      (piece.slot !== null &&
        piece.slot === product.slot &&
        colourOverlap(piece.colours, product.colours) >=
          DUPLICATE_MIN_COLOUR_OVERLAP),
  );
  if (duplicates.length) {
    out.push({
      code: 'ALREADY_OWN_SIMILAR',
      tone: 'caution',
      confidence: 90,
      ar:
        duplicates.length === 1
          ? `عندك «${duplicates[0].title}» وهي قريبة كتير من هاي.`
          : `عندك ${duplicates.length} قطع قريبة من هاي بخزانتك.`,
      evidence: {
        itemIds: duplicates.map((d) => d.itemId),
        titles: duplicates.map((d) => d.title),
      },
    });
  }

  // ── Does it finish something she started? ─────────────────────────────
  //
  // The slot has to match, and so does the occasion when both declare one.
  // Filling the slot alone offered a washable maternity bag as "the missing
  // piece for your wedding look" — correct about the slot, absurd about the
  // event, and exactly the kind of suggestion that teaches a shopper the
  // recommendations are automated and not worth reading.
  //
  // Only suppressed when the two genuinely disagree. Most listings declare no
  // occasion at all, and demanding one would silence the note for almost the
  // whole catalogue.
  const completes = product.slot
    ? shopper.openLooks.filter(
        (look) =>
          look.missingSlots.includes(product.slot as string) &&
          occasionCompatible(look.occasion, product.occasions),
      )
    : [];
  if (completes.length) {
    out.push({
      code: 'COMPLETES_LOOK',
      tone: 'encourage',
      confidence: 95,
      ar: `هي القطعة الناقصة لإطلالة «${completes[0].title}».`,
      evidence: { lookIds: completes.map((l) => l.lookId) },
    });
  }

  // ── Does it go with what she owns? ────────────────────────────────────
  //
  // Suppressed when she already owns one: telling her it matches her wardrobe
  // *and* that she already has it would be two notes arguing with each other.
  if (pairsWith.length && !duplicates.length) {
    out.push({
      code: 'SUITS_YOUR_CLOSET',
      tone: 'encourage',
      confidence: 80,
      ar:
        pairsWith.length === 1
          ? `بتنسّق مع «${pairsWith[0].title}» يلي عندك.`
          : `بتنسّق مع ${pairsWith.length} قطع من خزانتك.`,
      evidence: { itemIds: pairsWith.map((p) => p.itemId) },
    });
  }

  // ── Is there a better buy? ────────────────────────────────────────────
  if (alternative) {
    out.push({
      code: 'BETTER_VALUE',
      tone: 'inform',
      confidence: 70,
      ar: `في قطعة قريبة منها أرخص بـ${Math.round(alternative.savingBps / 100)}%.`,
      evidence: {
        productId: alternative.productId,
        title: alternative.title,
        savingBps: alternative.savingBps,
      },
    });
  }

  // ── Is it what she has been looking for? ──────────────────────────────
  const matchedTerm = shopper.terms.find((term) =>
    termMatches(term.key, product),
  );
  if (matchedTerm) {
    out.push({
      code: 'MATCHES_INTENT',
      tone: 'encourage',
      confidence: 75,
      ar: `قريبة من «${matchedTerm.display}» يلي كنتي عم تدوّري عليه.`,
      evidence: { term: matchedTerm.key },
    });
  }

  // ── Is it dressed for the event she is shopping for? ──────────────────
  const occasion = shopper.occasions.find((key) =>
    product.occasions.includes(key),
  );
  if (occasion && !matchedTerm) {
    out.push({
      code: 'FITS_OCCASION',
      tone: 'inform',
      confidence: 60,
      ar: 'مناسبة للمناسبة يلي عم تجهّزي إلها.',
      evidence: { occasion },
    });
  }

  // ── Has she bought from this shop before? ─────────────────────────────
  if (product.sellerIds.some((id) => shopper.boughtFromSellerIds.includes(id))) {
    out.push({
      code: 'TRUSTED_SELLER',
      tone: 'inform',
      confidence: 55,
      ar: 'من متجر بترجعي تشتري منه.',
      evidence: {},
    });
  }

  // ── Is the market moving? ─────────────────────────────────────────────
  //
  // Only stated when the numbers are big enough to mean it. A product that
  // went from two views to six has not started trending.
  const growth = growthOf(product.recentViews, product.previousViews);
  if (product.recentViews >= RISING_MIN_VIEWS && growth >= RISING_GROWTH) {
    out.push({
      code: 'RISING_DEMAND',
      tone: 'inform',
      confidence: 50,
      ar: `الطلب عليها عم يزيد — ${product.recentViews} بنت شافوها هالفترة.`,
      evidence: { recentViews: product.recentViews, growth: round(growth, 2) },
    });
  }

  // ── Is it about to go? ────────────────────────────────────────────────
  //
  // Last, and only when literally true. Scarcity is the easiest thing in
  // commerce to fake and the fastest way to lose a shopper's trust.
  if (product.stockUnits > 0 && product.stockUnits <= LAST_FEW) {
    out.push({
      code: 'LAST_FEW',
      tone: 'inform',
      confidence: 45,
      ar: `باقي ${product.stockUnits} قطع بس.`,
      evidence: { stockUnits: product.stockUnits },
    });
  }

  // Three at most.
  //
  // Not a display concern pushed into the kernel — a judgement about advice.
  // Five sentences about one dress is not five times as helpful as one; it is
  // a wall of text that gets skimmed, and the weakest lines crowd out the one
  // that mattered. Ordering already puts the caution first and the merely
  // contextual last, so the cut falls exactly where it should.
  return out
    .sort(
      (a, b) =>
        toneRank(b.tone) - toneRank(a.tone) || b.confidence - a.confidence,
    )
    .slice(0, MAX_NOTES);
}

/** How much Reem will say about one product before it becomes noise. */
export const MAX_NOTES = 3;

/**
 * Whether a product could plausibly be worn to a look's occasion.
 *
 * True when either side is silent — an unlabelled piece is not disqualified,
 * it is merely unlabelled. False only when both speak and they disagree.
 */
export function occasionCompatible(
  lookOccasion: string | null,
  productOccasions: readonly string[],
): boolean {
  if (!lookOccasion || !productOccasions.length) return true;
  return productOccasions.includes(lookOccasion);
}

/**
 * A caution outranks everything.
 *
 * If Reem is about to tell her she already owns this, that sentence goes
 * first — before anything encouraging her to buy it. Ordering the other way
 * would be a shop that buries its own warning under its own sales copy.
 */
function toneRank(tone: VerdictTone): number {
  return tone === 'caution' ? 2 : tone === 'encourage' ? 1 : 0;
}

function growthOf(recent: number, previous: number): number {
  const base = Math.max(previous, 3);
  return (recent - previous) / base;
}

/**
 * Whether a search term plausibly describes this product.
 *
 * Deliberately crude — token overlap against the title and the product's own
 * lexicon keys. The stylist has a real language model for this; here the
 * question is only "is this note worth showing", and a cheap test that
 * sometimes stays quiet is better than an expensive one on every card.
 */
export function termMatches(termKey: string, product: ProductFacts): boolean {
  const tokens = termKey.split(/[\s\-_]+/).filter((t) => t.length > 2);
  if (!tokens.length) return false;

  const haystack = [
    product.title,
    ...product.colours,
    ...product.occasions,
    product.slot ?? '',
  ]
    .join(' ')
    .toLowerCase();

  const hits = tokens.filter((t) => haystack.includes(t.toLowerCase())).length;
  // More than half the term has to be present, so "فستان سهرة أخضر" does not
  // match every dress in the catalogue on the strength of "فستان" alone.
  return hits / tokens.length > 0.5;
}
