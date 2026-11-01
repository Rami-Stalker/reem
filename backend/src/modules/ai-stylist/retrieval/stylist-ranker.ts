import { ModestyLevel, OutfitSlot } from '@prisma/client';
import { defaultOffer } from '../../../common/catalog/product-include';
import {
  StyleProfile,
  affinityOf,
  personalizationWeight,
} from '../preferences/style-profile';
import { StyleBrief, formatSyp } from '../understanding/style-brief';
import {
  colourLabel,
  coloursHarmonise,
  detectColours,
  garmentModesty,
  modestyRank,
  personaLabel,
  searchable,
  slotForCategorySlug,
} from '../understanding/stylist-lexicon';
import { StylistCandidate } from './product-retrieval.service';

/**
 * Why a product was chosen, as a code the sentence is then rendered from.
 *
 * Keeping the codes separate from the prose is the point: the reason shown to
 * a customer is generated *from* the components that actually fired, so it
 * cannot claim a match the scorer did not make. "اخترته لأنه ضمن ميزانيتك"
 * appears if and only if `BUDGET_FIT` scored.
 */
export type ReasonCode =
  | 'BUDGET_FIT'
  | 'BUDGET_VALUE'
  | 'COLOUR_MATCH'
  | 'COLOUR_HARMONY'
  | 'CATEGORY_MATCH'
  | 'OCCASION_MATCH'
  | 'MODESTY_MATCH'
  | 'PERSONA_MATCH'
  | 'MATERIAL_MATCH'
  | 'SIZE_AVAILABLE'
  | 'TOP_RATED'
  | 'POPULAR'
  | 'TRUSTED_SELLER'
  | 'FAVOURITE_CATEGORY'
  | 'FAVOURITE_SELLER'
  | 'FAVOURITE_COLOUR'
  | 'USUAL_BUDGET'
  | 'FAST_DELIVERY'
  | 'GIFT_READY';

export interface ScoredProduct {
  product: StylistCandidate;
  score: number;
  reasons: ReasonCode[];
  /** The colour the look would be built around, when one is identifiable. */
  dominantColour: string | null;
}

export interface RankingContext {
  brief: StyleBrief;
  profile: StyleProfile;
  /** Set when ranking for one slot of an outfit. */
  slot?: OutfitSlot;
  /** The already-chosen anchor piece, for colour harmony inside an outfit. */
  anchorColour?: string | null;
  /** Cap per category and per seller, so a list is not six near-identical
   *  dresses from one boutique. Null disables the cap. */
  diversity?: { perCategory: number; perSeller: number } | null;
}

/**
 * Scores and orders candidates.
 *
 * Deliberately a pure function over rows already fetched: no database, no
 * network, no model. That is what makes a ranking reproducible — the same
 * inputs give the same order and the same reasons, which is the difference
 * between a recommendation you can defend to a seller and one you cannot.
 */
export function rankProducts(
  candidates: StylistCandidate[],
  context: RankingContext,
  limit: number,
): ScoredProduct[] {
  const scored = candidates
    .map((product) => scoreProduct(product, context))
    // A hard mismatch (she said modest, this is sleeveless) is scored to
    // -Infinity rather than filtered upstream, so the intent stays visible in
    // one place.
    .filter((entry) => Number.isFinite(entry.score))
    .sort((a, b) => b.score - a.score);

  return context.diversity === null
    ? scored.slice(0, limit)
    : applyDiversity(scored, context.diversity ?? { perCategory: 3, perSeller: 2 }, limit);
}

export function scoreProduct(
  product: StylistCandidate,
  context: RankingContext,
): ScoredProduct {
  const { brief, profile } = context;
  const reasons: ReasonCode[] = [];
  let score = 0;

  const offer = defaultOffer(product);
  const priceSyp = product.minPriceSyp ? Number(product.minPriceSyp) : null;
  const attributes = (product.attributes as Record<string, unknown> | null) ?? null;
  const haystack = `${product.title} ${product.description}`;

  // ── Budget ────────────────────────────────────────────────────────────
  if (brief.budgetMax !== null && priceSyp !== null) {
    if (priceSyp <= brief.budgetMax) {
      score += 30;
      reasons.push('BUDGET_FIT');
      // Comfortably inside the band reads as good value; scraping the ceiling
      // does not. The curve peaks around 70% of what she is willing to spend.
      const ratio = priceSyp / brief.budgetMax;
      if (ratio >= 0.4 && ratio <= 0.85) {
        score += 8;
        reasons.push('BUDGET_VALUE');
      }
    } else {
      // Over budget survives only because the ladder may have raised the
      // ceiling; it must never outrank something she can afford.
      const overshoot = (priceSyp - brief.budgetMax) / brief.budgetMax;
      score -= 25 + overshoot * 60;
    }
  }
  if (brief.budgetMin !== null && priceSyp !== null && priceSyp < brief.budgetMin) {
    score -= 10;
  }

  // ── Colour ────────────────────────────────────────────────────────────
  const productColours = productColourKeys(product);
  const dominantColour = productColours[0] ?? null;

  if (brief.colours.length) {
    const exact = productColours.filter((colour) => brief.colours.includes(colour));
    if (exact.length) {
      score += 26;
      reasons.push('COLOUR_MATCH');
    } else if (
      productColours.some((colour) =>
        brief.colours.some((wanted) => coloursHarmonise(wanted, colour)),
      )
    ) {
      score += 9;
      reasons.push('COLOUR_HARMONY');
    }
  }

  if (context.anchorColour && productColours.length) {
    const harmonises = productColours.some((colour) =>
      coloursHarmonise(context.anchorColour!, colour),
    );
    if (harmonises) {
      score += 18;
      if (!reasons.includes('COLOUR_HARMONY')) reasons.push('COLOUR_HARMONY');
    } else {
      score -= 14;
    }
  }

  // ── Category and occasion ─────────────────────────────────────────────
  const slugs = brief.categorySlugs;
  if (slugs.includes(product.category.slug)) {
    score += 18;
    reasons.push('CATEGORY_MATCH');
  }
  if (context.slot && slotForCategorySlug(product.category.slug) === context.slot) {
    score += 10;
  }
  if (brief.occasion) {
    score += 4;
    reasons.push('OCCASION_MATCH');
  }

  // ── Modesty ───────────────────────────────────────────────────────────
  // Only what she asked for in this conversation — see `briefFor`: the saved
  // setting is no longer shown or editable, so it no longer decides anything.
  const wanted = brief.modesty;
  if (wanted !== ModestyLevel.UNSPECIFIED) {
    const actual = garmentModesty({
      categorySlug: product.category.slug,
      title: product.title,
      attributes,
    });
    if (actual) {
      const gap = modestyRank(actual) - modestyRank(wanted);
      if (gap >= 0) {
        score += 22;
        reasons.push('MODESTY_MATCH');
      } else if (gap === -1) {
        score -= 8;
      } else {
        // Two levels short of what she asked for is not a near miss. Asking
        // for محتشم and being shown سترابلس is the failure that would make
        // her stop trusting the assistant, so it is removed, not demoted.
        return { product, score: -Infinity, reasons: [], dominantColour };
      }
    }
  }

  // ── Taste ─────────────────────────────────────────────────────────────
  const personas = brief.personas.length ? brief.personas : profile.personas;
  for (const persona of personas) {
    if (searchable(haystack).includes(searchable(personaLabel(persona)).trim())) {
      score += 7;
      if (!reasons.includes('PERSONA_MATCH')) reasons.push('PERSONA_MATCH');
    }
  }

  if (brief.materials.length) {
    const material = String(attributes?.['material'] ?? '');
    const matched = brief.materials.some(
      (wantedMaterial) =>
        material.includes(wantedMaterial) || haystack.includes(wantedMaterial),
    );
    if (matched) {
      score += 12;
      reasons.push('MATERIAL_MATCH');
    }
  }

  // ── Availability in her size ──────────────────────────────────────────
  const size = sizeForProduct(brief, product.category.slug);
  if (size) {
    const inHerSize = product.offers.some((candidate) =>
      candidate.variants.some(
        (offerVariant) =>
          offerVariant.stock > 0 &&
          String(
            (offerVariant.variant.attributes as Record<string, unknown> | null)?.['size'] ??
              '',
          ) === size,
      ),
    );
    if (inHerSize) {
      score += 20;
      reasons.push('SIZE_AVAILABLE');
    } else {
      score -= 12;
    }
  }

  // ── Delivery ──────────────────────────────────────────────────────────
  if (brief.deadlineDays !== null && offer) {
    if (!offer.isMadeToOrder && offer.handlingDays <= Math.max(1, brief.deadlineDays)) {
      score += 8;
      reasons.push('FAST_DELIVERY');
    } else {
      score -= 12;
    }
  }

  // ── Quality, damped ───────────────────────────────────────────────────
  // Logs throughout: the difference between 10 and 100 orders should matter
  // more than the difference between 1,000 and 1,090.
  score += product.rating * 5;
  score += Math.log1p(product.ordersCount) * 3.5;
  score += Math.log1p(product.favoritesCount) * 2;
  if (product.rating >= 4.5 && product.reviewsCount >= 3) reasons.push('TOP_RATED');
  if (product.ordersCount >= 20) reasons.push('POPULAR');
  if (product.brand?.isVerified) {
    score += 4;
    reasons.push('TRUSTED_SELLER');
  }

  // ── Her ───────────────────────────────────────────────────────────────
  const personal = personalizationWeight(profile);

  const categoryAffinity = affinityOf(profile.categoryAffinity, product.category.slug);
  if (categoryAffinity > 0.25) {
    score += categoryAffinity * 14 * personal;
    reasons.push('FAVOURITE_CATEGORY');
  }

  const sellerAffinity = Math.max(
    0,
    ...product.offers.map((candidate) =>
      affinityOf(profile.sellerAffinity, candidate.sellerId),
    ),
    0,
  );
  if (sellerAffinity > 0.25) {
    score += sellerAffinity * 10 * personal;
    reasons.push('FAVOURITE_SELLER');
  }

  if (productColours.some((colour) => profile.favouriteColours.includes(colour))) {
    score += 10 * personal;
    reasons.push('FAVOURITE_COLOUR');
  } else {
    const colourAffinity = Math.max(
      0,
      ...productColours.map((colour) => affinityOf(profile.colourAffinity, colour)),
      0,
    );
    if (colourAffinity > 0.4) {
      score += colourAffinity * 8 * personal;
      reasons.push('FAVOURITE_COLOUR');
    }
  }

  score += affinityOf(profile.brandAffinity, product.brandId) * 6 * personal;

  // Her usual spend, but only when she has not named a budget this time.
  if (
    brief.budgetMax === null &&
    priceSyp !== null &&
    profile.typicalMinSyp !== null &&
    profile.typicalMaxSyp !== null
  ) {
    const low = profile.typicalMinSyp * 0.7;
    const high = profile.typicalMaxSyp * 1.3;
    if (priceSyp >= low && priceSyp <= high) {
      score += 10 * personal;
      reasons.push('USUAL_BUDGET');
    }
  }

  // ── Refusals ──────────────────────────────────────────────────────────
  if (profile.dismissedProductIds.has(product.id)) {
    // She has already said no to this one. Showing it again is the single
    // fastest way to make an assistant feel like it is not listening.
    return { product, score: -Infinity, reasons: [], dominantColour };
  }
  if (profile.avoidedCategorySlugs.includes(product.category.slug)) {
    return { product, score: -Infinity, reasons: [], dominantColour };
  }
  if (productColours.some((colour) => profile.avoidedColours.includes(colour))) {
    score -= 30;
  }
  if (profile.purchasedProductIds.has(product.id)) {
    // Not fatal — perfume and chocolate are rebought — but it should not lead.
    score -= 18;
  }
  if (profile.savedProductIds.has(product.id)) score += 6;

  // ── Gifting ───────────────────────────────────────────────────────────
  if (!brief.forSelf) {
    if (GIFT_READY_CATEGORIES.has(product.category.slug)) {
      score += 12;
      reasons.push('GIFT_READY');
    }
    if (brief.recipientAge !== null) {
      score += ageFit(brief.recipientAge, product.category.slug);
    }
  }

  // Nothing to sell her.
  if (!offer) return { product, score: -Infinity, reasons: [], dominantColour };

  return { product, score: round(score), reasons: dedupe(reasons), dominantColour };
}

/** Categories that arrive gift-ready — boxed, wrapped, or presentable as-is. */
const GIFT_READY_CATEGORIES = new Set([
  'bouquets',
  'chocolate',
  'candy-boxes',
  'graduation-gifts',
  'newborn-gifts',
  'ramadan-gifts',
  'perfumes',
  'jewellery',
  'scarves',
  'notebooks',
  'desk-accessories',
  'wall-art',
]);

/**
 * A crude but honest age fit.
 *
 * Deliberately small in magnitude: age says something about a gift and very
 * little about a garment, and a bigger weight here would start hiding things
 * for no defensible reason.
 */
function ageFit(age: number, categorySlug: string): number {
  if (age <= 3) return ['baby-sets', 'baby-shoes', 'baby-skincare', 'baby-essentials', 'newborn-gifts'].includes(categorySlug) ? 18 : -6;
  if (age <= 16) return ['chocolate', 'candy-boxes', 'notebooks', 'desk-accessories'].includes(categorySlug) ? 8 : 0;
  if (age <= 30) return ['jewellery', 'perfumes', 'handbags', 'face-makeup', 'lips'].includes(categorySlug) ? 8 : 0;
  return ['perfumes', 'scarves', 'jewellery', 'moisturisers', 'wall-art'].includes(categorySlug) ? 8 : 0;
}

/**
 * Keeps a list from collapsing onto one category or one boutique.
 *
 * A greedy pass in score order, skipping anything that would exceed a cap, and
 * a second pass to backfill if the caps left the list short — a thin catalog
 * corner should give a shorter, still-useful list, not an empty one.
 */
function applyDiversity(
  scored: ScoredProduct[],
  caps: { perCategory: number; perSeller: number },
  limit: number,
): ScoredProduct[] {
  const chosen: ScoredProduct[] = [];
  const byCategory = new Map<string, number>();
  const bySeller = new Map<string, number>();

  for (const entry of scored) {
    if (chosen.length >= limit) break;
    const categorySlug = entry.product.category.slug;
    const sellerId = defaultOffer(entry.product)?.sellerId ?? '';

    if ((byCategory.get(categorySlug) ?? 0) >= caps.perCategory) continue;
    if (sellerId && (bySeller.get(sellerId) ?? 0) >= caps.perSeller) continue;

    chosen.push(entry);
    byCategory.set(categorySlug, (byCategory.get(categorySlug) ?? 0) + 1);
    if (sellerId) bySeller.set(sellerId, (bySeller.get(sellerId) ?? 0) + 1);
  }

  if (chosen.length < limit) {
    const taken = new Set(chosen.map((entry) => entry.product.id));
    for (const entry of scored) {
      if (chosen.length >= limit) break;
      if (taken.has(entry.product.id)) continue;
      chosen.push(entry);
    }
  }

  return chosen;
}

/**
 * The colours a row is actually in.
 *
 * Variant attributes first — a seller who filled them in is the authority on
 * their own product — falling back to the title, which is where the rest of
 * the catalog keeps it ("فستان سهرة بلون الشامبانيا").
 */
export function productColourKeys(product: StylistCandidate): string[] {
  const fromVariants = product.variants.flatMap((variant) => {
    const attributes = variant.attributes as Record<string, unknown> | null;
    const value = attributes?.['colour'] ?? attributes?.['color'];
    return typeof value === 'string' ? detectColours(value) : [];
  });
  if (fromVariants.length) return [...new Set(fromVariants)];

  return [...new Set(detectColours(product.title))];
}

/** The slots measured by the clothing chart rather than the shoe one. */
const SIZED_AS_CLOTHING: readonly OutfitSlot[] = [
  OutfitSlot.DRESS,
  OutfitSlot.ABAYA,
  OutfitSlot.TOP,
  OutfitSlot.BOTTOM,
  OutfitSlot.OUTERWEAR,
];

function sizeForProduct(brief: StyleBrief, categorySlug: string): string | null {
  const slot = slotForCategorySlug(categorySlug);
  if (slot === OutfitSlot.SHOES) return brief.sizes.shoes ?? null;
  if (slot && SIZED_AS_CLOTHING.includes(slot)) return brief.sizes.clothing ?? null;
  return null;
}

function dedupe(reasons: ReasonCode[]): ReasonCode[] {
  return [...new Set(reasons)];
}

function round(value: number): number {
  return Math.round(value * 100) / 100;
}

// ── Rendering a reason ──────────────────────────────────────────────────

/**
 * Turns the codes that fired into the sentence on the card.
 *
 * Ordered by how much each fact would actually influence a decision — price
 * and colour before "تقييمها عالي" — and capped at three clauses, because a
 * card that justifies itself at length reads as a machine defending a guess.
 */
export function renderReason(
  entry: ScoredProduct,
  brief: StyleBrief,
  context: { slot?: OutfitSlot } = {},
): string {
  const product = entry.product;
  const clauses: string[] = [];
  const has = (code: ReasonCode) => entry.reasons.includes(code);

  if (has('CATEGORY_MATCH') || context.slot) {
    // Opening clause names the thing, so the sentence stands alone under a
    // card that may be scrolled past its own image.
    clauses.push(`قريب من النمط الذي طلبتِه`);
  }
  if (has('COLOUR_MATCH')) {
    const colour = brief.colours[0] ?? entry.dominantColour;
    if (colour) clauses.push(`وباللون ${colourLabel(colour)} الذي أحببتِه`);
  } else if (has('COLOUR_HARMONY') && entry.dominantColour) {
    clauses.push(`ولونه ${colourLabel(entry.dominantColour)} يتناسق مع بقية الإطلالة`);
  }
  if (has('BUDGET_FIT')) {
    const price = product.minPriceSyp ? Number(product.minPriceSyp) : null;
    clauses.push(price !== null ? `وضمن ميزانيتكِ (${formatSyp(price)})` : 'وضمن ميزانيتكِ');
  }
  if (has('MODESTY_MATCH')) clauses.push('ومحتشم كما تحبين');
  if (has('SIZE_AVAILABLE')) {
    const size = brief.sizes.clothing ?? brief.sizes.shoes;
    clauses.push(size ? `ومتوفر بمقاس ${size}` : 'ومتوفر بمقاسكِ');
  }
  if (has('MATERIAL_MATCH')) clauses.push('وبالخامة التي سألتِ عنها');
  if (has('FAVOURITE_CATEGORY') && clauses.length < 3) {
    clauses.push('ومن قسم تتابعينه');
  }
  if (has('FAVOURITE_SELLER') && clauses.length < 3) {
    clauses.push('ومن بائعة سبق أن اشتريتِ منها');
  }
  if (has('FAST_DELIVERY') && clauses.length < 3) clauses.push('ويصل في الوقت');
  if (has('GIFT_READY') && clauses.length < 3) clauses.push('ومناسب كهدية جاهزة');

  if (clauses.length < 2) {
    if (has('TOP_RATED')) clauses.push(`وتقييمه ${product.rating.toFixed(1)} من 5`);
    else if (has('POPULAR')) clauses.push('ومطلوب كثيراً على المنصّة');
  }

  if (!clauses.length) return 'اختيار قريب من طلبكِ ومتوفر حالياً.';

  const body = clauses.slice(0, 3).join(' ');
  return `اخترت لكِ هذه القطعة لأنها ${stripLeadingWaw(body)}.`;
}

/** The clause list is built with "و" prefixes; the first one must lose it. */
function stripLeadingWaw(text: string): string {
  return text.startsWith('و') ? text.slice(1) : text;
}
