/**
 * Product Health.
 *
 * Six axes over one listing, and the advice that follows from them.
 *
 * ── Why half the axes are measured against the cohort ────────────────────
 *
 * A conversion rate of 2% is meaningless on its own. In handbags it might be
 * excellent; in phone cases it is poor. The same is true of attribute counts,
 * of search exposure, of price. So the axes that only mean something in
 * context — conversion, discoverability, performance, and the price note —
 * are scored against the *live listings in the same category*, and are simply
 * withheld when that cohort is too small to say anything honest.
 *
 * The axes she can fix without knowing anything about anybody else — images,
 * description, attributes — are scored against a fixed target, because "add a
 * third photograph" is good advice whether or not her competitors have three.
 *
 * Pure, like every other kernel here: it takes counts and returns numbers, so
 * the health score on the screen can be re-derived by hand from the row.
 */

import {
  ATTRIBUTE_TARGET,
  CONVERSION_MIN_VIEWS,
  DESCRIPTION_MINIMUM,
  DESCRIPTION_TARGET,
  IMAGE_MINIMUM,
  IMAGE_TARGET,
  PEER_MIN_COHORT,
  PRICE_PREMIUM_BPS,
  PRODUCT_HEALTH_AR,
  PRODUCT_HEALTH_KEYS,
  PRODUCT_HEALTH_WEIGHTS,
  ProductHealthKey,
  TITLE_TARGET,
} from '../intelligence.constants';

// ── What the kernel is given ─────────────────────────────────────────────

/** One listing, as facts a person could check by looking at it. */
export interface ProductFacts {
  productId: string;
  title: string;
  description: string;
  /** Photographs on the listing. */
  imageCount: number;
  /** Of those, how many carry a blur hash — the ones that load gracefully. */
  imagesWithBlurHash: number;
  /** Attribute keys actually filled in. */
  attributeCount: number;
  /** Whether it carries a brand and a barcode: both help it be found. */
  hasBrand: boolean;
  hasGtin: boolean;

  /** The window's demand, summed. */
  impressions: number;
  views: number;
  searchHits: number;
  searchClicks: number;
  cartAdds: number;
  favorites: number;
  orders: number;
  units: number;

  /** Her price in SYP, and whether it is in stock at all. */
  priceSyp: number | null;
  inStock: boolean;
  stockUnits: number;

  reviewCount: number;
  averageRating: number | null;
}

/** The category's live listings, already reduced to the numbers that matter. */
export interface PeerCohort {
  /** How many listings the medians were taken over. */
  size: number;
  medianConversion: number;
  medianViews: number;
  medianAttributes: number;
  medianPriceSyp: number | null;
  medianImages: number;
}

export interface HealthAxis {
  key: ProductHealthKey;
  label: string;
  score: number | null;
  weight: number;
  /** Whether the cohort was big enough / the sample deep enough to score it. */
  evidence: 'measured' | 'thin' | 'unmeasurable';
}

export interface PeerPosition {
  peers: number;
  /** Her price against the cohort median, in basis points. Positive = dearer. */
  pricePremiumBps: number | null;
  conversion: number;
  medianConversion: number;
  /** 0-1, her rank among peers by conversion. */
  conversionPercentile: number | null;
}

export interface ProductHealthResult {
  score: number;
  confidence: number;
  axes: HealthAxis[];
  peers: PeerPosition | null;
}

const clamp01 = (n: number): number => Math.min(1, Math.max(0, n));
const round = (n: number, dp = 2): number => {
  const f = 10 ** dp;
  return Math.round(n * f) / f;
};

/** A count against a target, with a floor below which it is clearly wrong. */
export function towards(count: number, target: number, minimum = 0): number {
  if (target <= 0) return 100;
  const ratio = clamp01(count / target);
  if (count < minimum) return round(ratio * 60);
  return round(ratio * 100);
}

/**
 * Her value against the cohort's median.
 *
 * Anchored so that *the median is 70* — a solid listing, not a perfect one —
 * with zero at zero and full marks at twice the median.
 *
 * The obvious alternative, mapping the median to 100 and scaling down from
 * there, was what this did first and it was wrong in a way that mattered: it
 * put a floor under the axis, so a product converting at a twentieth of its
 * category still scored in the fifties and never tripped the advice that
 * exists precisely to catch it. An axis that cannot say "this is bad" is not
 * measuring anything.
 */
export function versusMedian(value: number, median: number): number {
  if (median <= 0) return value > 0 ? 100 : 0;
  const ratio = value / median;
  if (ratio <= 1) return round(ratio * 70);
  return round(Math.min(100, 70 + (ratio - 1) * 30));
}

export function conversionOf(facts: ProductFacts): number {
  return facts.views > 0 ? facts.orders / facts.views : 0;
}

// ── The kernel ───────────────────────────────────────────────────────────

export function scoreProductHealth(
  facts: ProductFacts,
  cohort: PeerCohort | null,
): ProductHealthResult {
  const usable = cohort && cohort.size >= PEER_MIN_COHORT ? cohort : null;
  const conversion = conversionOf(facts);

  const axes: HealthAxis[] = [];
  const add = (
    key: ProductHealthKey,
    score: number | null,
    evidence: HealthAxis['evidence'],
  ) => {
    axes.push({
      key,
      label: PRODUCT_HEALTH_AR[key],
      score: score === null ? null : round(score),
      weight: 0,
      evidence,
    });
  };

  // ── Content: is there enough here to understand and to search? ──────────
  const titleScore = towards(facts.title.trim().length, TITLE_TARGET);
  const descLength = facts.description.trim().length;
  const descScore = towards(descLength, DESCRIPTION_TARGET, DESCRIPTION_MINIMUM);
  add('content', titleScore * 0.35 + descScore * 0.65, 'measured');

  // ── Imagery: how many, and do they load gracefully? ─────────────────────
  const countScore = towards(facts.imageCount, IMAGE_TARGET, IMAGE_MINIMUM);
  const blurShare = facts.imageCount
    ? facts.imagesWithBlurHash / facts.imageCount
    : 0;
  add('imagery', countScore * 0.85 + blurShare * 100 * 0.15, 'measured');

  // ── Attributes: against the category's own habit where we know it. ──────
  const attrTarget = usable
    ? Math.max(ATTRIBUTE_TARGET * 0.5, usable.medianAttributes)
    : ATTRIBUTE_TARGET;
  const attrBase = towards(facts.attributeCount, attrTarget);
  // A brand and a barcode are worth a little on their own: both are things
  // search and comparison lean on that a description cannot replace.
  const identity = (facts.hasBrand ? 60 : 0) + (facts.hasGtin ? 40 : 0);
  add('attributes', attrBase * 0.8 + identity * 0.2, 'measured');

  // ── Discoverability: is anyone finding it, and do they click? ───────────
  if (facts.impressions + facts.searchHits === 0) {
    // Nothing has been shown. That is not a bad listing, it is an unseen one,
    // and scoring it zero would bury a new product under its own newness.
    add('discoverability', null, 'unmeasurable');
  } else {
    const clickRate = facts.searchHits
      ? facts.searchClicks / facts.searchHits
      : 0;
    const exposure = usable
      ? versusMedian(facts.views, usable.medianViews)
      : Math.min(100, facts.views * 2);
    add(
      'discoverability',
      exposure * 0.6 + clamp01(clickRate / 0.15) * 100 * 0.4,
      usable ? 'measured' : 'thin',
    );
  }

  // ── Performance: attention relative to the cohort. ──────────────────────
  if (!usable || (usable.medianViews <= 0 && facts.views === 0)) {
    // No cohort, or a cohort where nothing has been viewed at all. The second
    // case is the one live data caught: every listing in a quiet category
    // scored zero for performance, which reads as "your product is failing"
    // when the truth is that the whole aisle is asleep and there is nothing
    // to compare against. A listing cannot underperform a market that has no
    // performance.
    add('performance', null, 'unmeasurable');
  } else {
    const interest = facts.views
      ? (facts.cartAdds + facts.favorites) / facts.views
      : 0;
    add(
      'performance',
      versusMedian(facts.views, usable.medianViews) * 0.5 +
        clamp01(interest / 0.12) * 100 * 0.5,
      'measured',
    );
  }

  // ── Conversion: the axis the whole thing is really about. ──────────────
  if (facts.views < CONVERSION_MIN_VIEWS) {
    add('conversion', null, 'thin');
  } else if (usable && usable.medianConversion > 0) {
    add('conversion', versusMedian(conversion, usable.medianConversion), 'measured');
  } else {
    // Either no cohort, or a cohort where nothing converts. The second is a
    // real comparison that happens to be degenerate: ranking her against a
    // median of zero says nothing, so the absolute yardstick answers instead
    // and the axis is marked thin. 124 views and no orders is still a
    // problem worth naming — it just is not a problem relative to peers.
    add('conversion', clamp01(conversion / 0.03) * 100, 'thin');
  }

  // Renormalise across the axes that could actually be scored, exactly as the
  // seller kernel does: an unseen listing is scored on what it has, not
  // punished for what has not happened to it yet.
  const scored = axes.filter((a) => a.score !== null);
  const nominal = scored.reduce((t, a) => t + PRODUCT_HEALTH_WEIGHTS[a.key], 0);

  for (const axis of axes) {
    axis.weight =
      axis.score !== null && nominal > 0
        ? round((PRODUCT_HEALTH_WEIGHTS[axis.key] / nominal) * 100, 1)
        : 0;
  }

  const score = nominal
    ? round(
        scored.reduce(
          (t, a) => t + (a.score as number) * PRODUCT_HEALTH_WEIGHTS[a.key],
          0,
        ) / nominal,
      )
    : 0;

  // Confidence is about the evidence behind the score, so it leans on how
  // much of the weight came from axes we could measure properly.
  const measuredWeight = scored
    .filter((a) => a.evidence === 'measured')
    .reduce((t, a) => t + PRODUCT_HEALTH_WEIGHTS[a.key], 0);
  const total = PRODUCT_HEALTH_KEYS.reduce(
    (t, k) => t + PRODUCT_HEALTH_WEIGHTS[k],
    0,
  );

  return {
    score,
    confidence: round(measuredWeight / total, 2),
    axes,
    peers: usable
      ? {
          peers: usable.size,
          pricePremiumBps:
            facts.priceSyp && usable.medianPriceSyp
              ? Math.round(
                  ((facts.priceSyp - usable.medianPriceSyp) /
                    usable.medianPriceSyp) *
                    10_000,
                )
              : null,
          conversion: round(conversion, 4),
          medianConversion: round(usable.medianConversion, 4),
          conversionPercentile:
            facts.views >= CONVERSION_MIN_VIEWS
              ? round(
                  clamp01(
                    usable.medianConversion > 0
                      ? conversion / (usable.medianConversion * 2)
                      : 0.5,
                  ),
                  2,
                )
              : null,
        }
      : null,
  };
}

// ── Advice ───────────────────────────────────────────────────────────────

export interface ProductAdvice {
  code: string;
  axis: ProductHealthKey | 'price' | 'stock';
  severity: 'critical' | 'warning' | 'opportunity';
  /** Points on the health score she would recover. Zero for the ones that are
   *  about money rather than about the score. */
  gainPoints: number;
  ar: string;
}

/**
 * What to change, in the order worth changing it.
 *
 * These are the three sentences the brief asked for by name — "add more
 * photographs", "this gets views but few orders", "your price is above
 * similar products" — plus the ones the arithmetic turned out to support.
 * Every one of them is a statement about a number in `facts`, so none of them
 * can be wrong in a way the seller cannot check.
 */
export function adviseProduct(
  facts: ProductFacts,
  result: ProductHealthResult,
): ProductAdvice[] {
  const out: ProductAdvice[] = [];
  const axis = new Map(result.axes.map((a) => [a.key, a]));
  const gain = (key: ProductHealthKey): number => {
    const a = axis.get(key);
    if (!a || a.score === null || !a.weight) return 0;
    return round(((100 - a.score) * a.weight) / 100, 1);
  };

  if (facts.imageCount < IMAGE_TARGET) {
    out.push({
      code: 'MORE_IMAGES',
      axis: 'imagery',
      severity: facts.imageCount < IMAGE_MINIMUM ? 'critical' : 'opportunity',
      gainPoints: gain('imagery'),
      ar:
        facts.imageCount === 0
          ? 'لا صورة واحدة. القطعة بلا صورة لا تكاد تُشترى.'
          : `لديكِ ${facts.imageCount} صور. أضيفي صوراً أخرى — من الأمام والخلف وتفصيلاً قريباً — والأفضل ${IMAGE_TARGET}.`,
    });
  }

  if (facts.description.trim().length < DESCRIPTION_TARGET) {
    out.push({
      code: 'THIN_DESCRIPTION',
      axis: 'content',
      severity:
        facts.description.trim().length < DESCRIPTION_MINIMUM
          ? 'warning'
          : 'opportunity',
      gainPoints: gain('content'),
      ar: 'الوصف قصير. اكتبي القماش والقياسات وطريقة اللبس — هذه الكلمات هي ما تجده النساء في البحث.',
    });
  }

  // The sentence the brief asked for, and the one that needs both halves of
  // the funnel to be true at once before it is said.
  const conv = axis.get('conversion');
  if (
    facts.views >= CONVERSION_MIN_VIEWS &&
    conv?.score !== null &&
    conv?.score !== undefined &&
    conv.score < 45
  ) {
    out.push({
      code: 'VIEWS_NO_CONVERSION',
      axis: 'conversion',
      severity: 'critical',
      gainPoints: gain('conversion'),
      ar: `يحصل هذا المنتج على ${facts.views} مشاهدة لكن التحويل ضعيف. غالباً السعر أو الصور أو الوصف — غيّري واحداً منها وراقبي النتيجة.`,
    });
  }

  // Price, said only when the cohort is real and the gap is worth mentioning.
  const premium = result.peers?.pricePremiumBps ?? null;
  if (premium !== null && premium > PRICE_PREMIUM_BPS) {
    out.push({
      code: 'PRICE_ABOVE_PEERS',
      axis: 'price',
      severity: premium > PRICE_PREMIUM_BPS * 2 ? 'warning' : 'opportunity',
      gainPoints: 0,
      ar: `سعرك أعلى بـ${Math.round(premium / 100)}% من المنتجات المشابهة في الفئة نفسها. إن كان هناك سبب (خامة أفضل مثلاً) فاذكريه في الوصف.`,
    });
  } else if (premium !== null && premium < -PRICE_PREMIUM_BPS * 2) {
    out.push({
      code: 'PRICE_BELOW_PEERS',
      axis: 'price',
      severity: 'opportunity',
      gainPoints: 0,
      ar: `سعرك أقل بـ${Math.abs(Math.round(premium / 100))}% من المشابه. إن كان البيع جيداً، فهناك مجال لرفع السعر.`,
    });
  }

  if (!facts.inStock) {
    out.push({
      code: 'OUT_OF_STOCK',
      axis: 'stock',
      severity: facts.views > 0 ? 'critical' : 'warning',
      gainPoints: 0,
      ar: 'القطعة غير متوفرة وما زالت تظهر في البحث. أعيدي الكمية أو أخفيها لتوقفي المشاهدات الضائعة.',
    });
  }

  const attrs = axis.get('attributes');
  if (attrs?.score !== null && attrs?.score !== undefined && attrs.score < 60) {
    out.push({
      code: 'ATTRIBUTES_INCOMPLETE',
      axis: 'attributes',
      severity: 'opportunity',
      gainPoints: gain('attributes'),
      ar: 'الخصائص ناقصة (اللون، القياس، الخامة). هي ما يُظهر القطعة حين تستخدم المرأة الفلاتر.',
    });
  }

  const disc = axis.get('discoverability');
  if (
    disc?.score !== null &&
    disc?.score !== undefined &&
    disc.score < 40 &&
    facts.searchHits > 0
  ) {
    out.push({
      code: 'LOW_DISCOVERY',
      axis: 'discoverability',
      severity: 'warning',
      gainPoints: gain('discoverability'),
      ar: 'تظهر القطعة في البحث لكن قلّة يفتحنها. غالباً العنوان أو الصورة الأولى غير جاذبين.',
    });
  }

  return out.sort(
    (a, b) =>
      severityRank(b.severity) - severityRank(a.severity) ||
      b.gainPoints - a.gainPoints,
  );
}

function severityRank(s: ProductAdvice['severity']): number {
  return s === 'critical' ? 2 : s === 'warning' ? 1 : 0;
}
