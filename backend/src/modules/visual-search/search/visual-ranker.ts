import { ModestyLevel, Prisma } from '@prisma/client';
import { PRODUCT_CARD_INCLUDE, defaultOffer } from '../../../common/catalog/product-include';
import { StyleBrief } from '../../ai-stylist/understanding/style-brief';
import {
  colourLabel,
  coloursHarmonise,
  detectColours,
  garmentModesty,
  modestyRank,
} from '../../ai-stylist/understanding/stylist-lexicon';
import { displayedSimilarity } from '../embedding/visual-descriptor';
import { VectorMatch } from '../vector/vector-index';
import { PATTERN_LABELS, VisualAttributes } from '../understanding/visual-attributes';

export type VisualCandidate = Prisma.ProductGetPayload<{
  include: typeof PRODUCT_CARD_INCLUDE;
}>;

/**
 * Why a product was shown, as a code the sentence is rendered from.
 *
 * Same discipline as the stylist's `ReasonCode`, and for the same reason: the
 * text under a card is generated from the components that actually fired, so
 * "نفس اللون تقريبًا" appears if and only if the colour block scored. A
 * percentage nobody can explain is a percentage nobody believes.
 */
export type VisualReasonCode =
  | 'NEAR_IDENTICAL'
  | 'COLOUR_MATCH'
  | 'COLOUR_HARMONY'
  | 'SHAPE_MATCH'
  | 'PATTERN_MATCH'
  | 'LAYOUT_MATCH'
  | 'CATEGORY_MATCH'
  | 'BUDGET_FIT'
  | 'MODESTY_MATCH'
  | 'SIZE_AVAILABLE'
  | 'TOP_RATED'
  | 'POPULAR';

export interface ScoredVisualMatch {
  match: VectorMatch;
  product: VisualCandidate;
  /** The number rendered as "٩٤٪ مشابه". 0–1. */
  similarity: number;
  /** The calibrated visual half. 0–1. */
  visualScore: number;
  /** The attribute-agreement half. 0–1, or the visual score when no evidence. */
  attributeScore: number;
  reasons: VisualReasonCode[];
  reason: string;
}

/**
 * How much of the displayed percentage is "it looks like it" versus "it
 * matches what you asked for".
 *
 * Weighted heavily to the pixels, because the label on the card says *مشابه*
 * and a number under that word has to be mostly about looking alike. The
 * attribute quarter is what stops a photograph of a black dress returning a
 * black cushion cover that happens to score well: category, colour name,
 * pattern and her stated constraints all pull in the same direction as the
 * vector when the answer is right, and disagree loudly when it is not.
 */
const VISUAL_WEIGHT = 0.75;

/**
 * The similarity below which nothing is shown at all.
 *
 * Applied to the *calibrated* score, so it means what it looks like: under a
 * third, this is not a match, and an empty result is a better answer than a
 * page of things that merely exist. Kept here rather than in the query so the
 * same threshold governs every caller.
 */
export const MIN_DISPLAYED_SIMILARITY = 0.34;

export interface RankingInput {
  matches: VectorMatch[];
  products: Map<string, VisualCandidate>;
  attributes: VisualAttributes;
  brief: StyleBrief;
  anchors: { floor: number; ceiling: number };
  /** Cap per seller, so one boutique cannot own the page. Null disables it. */
  diversity?: { perSeller: number } | null;
}

export function rankVisualMatches(
  input: RankingInput,
  limit: number,
): ScoredVisualMatch[] {
  const scored: ScoredVisualMatch[] = [];

  for (const match of input.matches) {
    const product = input.products.get(match.productId);
    if (!product) continue;

    const entry = scoreVisualMatch({
      match,
      product,
      attributes: input.attributes,
      brief: input.brief,
      anchors: input.anchors,
    });
    if (entry.similarity < MIN_DISPLAYED_SIMILARITY) continue;
    scored.push(entry);
  }

  scored.sort((a, b) => b.similarity - a.similarity);

  if (input.diversity === null) return scored.slice(0, limit);

  const perSeller = input.diversity?.perSeller ?? 3;
  const seen = new Map<string, number>();
  const out: ScoredVisualMatch[] = [];
  const overflow: ScoredVisualMatch[] = [];

  for (const entry of scored) {
    const sellerId = defaultOffer(entry.product)?.sellerId ?? 'unknown';
    const used = seen.get(sellerId) ?? 0;
    if (used >= perSeller) {
      overflow.push(entry);
      continue;
    }
    seen.set(sellerId, used + 1);
    out.push(entry);
    if (out.length >= limit) return out;
  }

  // A near-empty page from one seller beats an empty one: the cap is a
  // preference about ordering, not a reason to withhold real matches.
  return [...out, ...overflow].slice(0, limit);
}

export function scoreVisualMatch(input: {
  match: VectorMatch;
  product: VisualCandidate;
  attributes: VisualAttributes;
  brief: StyleBrief;
  anchors: { floor: number; ceiling: number };
}): ScoredVisualMatch {
  const { match, product, attributes, brief } = input;
  const reasons: VisualReasonCode[] = [];

  const visualScore = displayedSimilarity(match.similarity, input.anchors);

  // ── The visual half's own reasons ─────────────────────────────────────
  //
  // Read straight off the block cosines, which is what makes them true.
  const parts = match.parts;
  if (visualScore >= 0.9) reasons.push('NEAR_IDENTICAL');
  if ((parts['shape'] ?? 0) >= 0.86) reasons.push('SHAPE_MATCH');
  if ((parts['texture'] ?? 0) >= 0.88) reasons.push('PATTERN_MATCH');
  if ((parts['layout'] ?? 0) >= 0.9) reasons.push('LAYOUT_MATCH');

  // ── The attribute half ────────────────────────────────────────────────
  //
  // Each component contributes only when there is something to compare, and
  // the total is renormalised by the evidence that actually existed. A brief
  // with no budget must not score the same as one whose budget was missed.
  let agreement = 0;
  let evidence = 0;

  const wantedColours = brief.colours.length
    ? brief.colours
    : attributes.colours.map((colour) => colour.key);

  if (wantedColours.length) {
    const productColours = productColourKeys(product, match);
    evidence += 0.4;
    if (productColours.some((colour) => wantedColours.includes(colour))) {
      agreement += 0.4;
      reasons.push('COLOUR_MATCH');
    } else if (
      productColours.some((colour) =>
        wantedColours.some((wanted) => coloursHarmonise(wanted, colour)),
      )
    ) {
      agreement += 0.16;
      reasons.push('COLOUR_HARMONY');
    }
  }

  if (match.pattern) {
    evidence += 0.12;
    if (match.pattern === attributes.pattern) {
      agreement += 0.12;
      if (!reasons.includes('PATTERN_MATCH')) reasons.push('PATTERN_MATCH');
    }
  }

  const wantedCategories = brief.categorySlugs.length
    ? brief.categorySlugs
    : attributes.categories.map((entry) => entry.slug);
  if (wantedCategories.length) {
    evidence += 0.24;
    if (wantedCategories.includes(product.category.slug)) {
      agreement += 0.24;
      reasons.push('CATEGORY_MATCH');
    }
  }

  const priceSyp = product.minPriceSyp ? Number(product.minPriceSyp) : null;
  if (brief.budgetMax !== null && priceSyp !== null) {
    evidence += 0.14;
    if (priceSyp <= brief.budgetMax) {
      agreement += 0.14;
      reasons.push('BUDGET_FIT');
    }
  }

  const wantedModesty =
    brief.modesty !== ModestyLevel.UNSPECIFIED ? brief.modesty : null;
  if (wantedModesty) {
    evidence += 0.1;
    const actual = garmentModesty({
      title: product.title,
      categorySlug: product.category.slug,
      attributes: product.attributes as Record<string, unknown> | null,
    });
    if (actual === null || modestyRank(actual) >= modestyRank(wantedModesty)) {
      agreement += 0.1;
      reasons.push('MODESTY_MATCH');
    }
  }

  // No attribute evidence at all — an unnamed palette on a photograph with no
  // refinement — means the pixels are the only honest answer, so the visual
  // score stands in rather than a zero dragging the total down.
  const attributeScore = evidence > 0 ? agreement / evidence : visualScore;

  if (product.rating >= 4.5 && product.reviewsCount >= 3) reasons.push('TOP_RATED');
  else if (product.ordersCount >= 25) reasons.push('POPULAR');

  const similarity =
    VISUAL_WEIGHT * visualScore + (1 - VISUAL_WEIGHT) * attributeScore;

  return {
    match,
    product,
    similarity: clamp01(similarity),
    visualScore,
    attributeScore: clamp01(attributeScore),
    reasons,
    reason: reasonSentence(reasons, { attributes, brief }),
  };
}

/**
 * The colours this product is, as lexicon keys.
 *
 * Prefers what the indexer measured off the matched photograph — that is the
 * colour of the thing in the picture, which is the question — and falls back
 * to the words in the listing when the row predates the indexer.
 */
function productColourKeys(product: VisualCandidate, match: VectorMatch): string[] {
  if (match.paletteKeys.length) return match.paletteKeys;

  const fromVariants = product.variants.flatMap((variant) => {
    const attributes = variant.attributes as Record<string, unknown> | null;
    const colour = attributes?.['colour'] ?? attributes?.['color'];
    return typeof colour === 'string' ? detectColours(colour) : [];
  });

  return [...new Set([...fromVariants, ...detectColours(product.title)])];
}

/**
 * The sentence under the card.
 *
 * Built from at most two codes. A card is a postcard, not a report, and a
 * reason listing six agreements reads as a machine explaining itself rather
 * than a shop assistant saying why she picked it up.
 */
export function reasonSentence(
  codes: readonly VisualReasonCode[],
  context: { attributes: VisualAttributes; brief: StyleBrief },
): string {
  const colour =
    context.brief.colours[0] ?? context.attributes.colours[0]?.key ?? null;

  const phrases: string[] = [];
  for (const code of codes) {
    const phrase = phraseFor(code, {
      colour,
      pattern: context.attributes.pattern,
    });
    if (phrase && !phrases.includes(phrase)) phrases.push(phrase);
    if (phrases.length === 2) break;
  }

  if (!phrases.length) return 'قريب بصريًا من الصورة اللي رفعتيها.';
  return `${phrases.join('، و')}.`;
}

function phraseFor(
  code: VisualReasonCode,
  context: { colour: string | null; pattern: string },
): string | null {
  switch (code) {
    case 'NEAR_IDENTICAL':
      return 'شبه مطابق للصورة';
    case 'SHAPE_MATCH':
      return 'نفس القصّة تقريبًا';
    case 'LAYOUT_MATCH':
      return 'نفس توزيع الألوان';
    case 'PATTERN_MATCH':
      return `نفس الملمس (${PATTERN_LABELS[context.pattern as keyof typeof PATTERN_LABELS] ?? context.pattern})`;
    case 'COLOUR_MATCH':
      return context.colour ? `باللون ${colourLabel(context.colour)}` : 'بنفس اللون';
    case 'COLOUR_HARMONY':
      return 'بلون بينسّق مع الصورة';
    case 'CATEGORY_MATCH':
      return 'من نفس القسم';
    case 'BUDGET_FIT':
      return 'ضمن ميزانيتك';
    case 'MODESTY_MATCH':
      return 'بيناسب درجة الاحتشام اللي طلبتيها';
    case 'SIZE_AVAILABLE':
      return 'متوفر بمقاسك';
    case 'TOP_RATED':
      return 'تقييمه عالي';
    case 'POPULAR':
      return 'مطلوب كتير';
  }
}

function clamp01(value: number): number {
  if (!Number.isFinite(value)) return 0;
  return value < 0 ? 0 : value > 1 ? 1 : value;
}
