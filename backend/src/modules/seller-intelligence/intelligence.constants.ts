/**
 * Every number the seller-intelligence kernels are allowed to invent.
 *
 * Gathered in one file for the same reason the trend engine gathers its own:
 * a weight buried in a function is a weight nobody can review, and every one
 * of these is a business decision rather than a mathematical fact. Somebody
 * should be able to read this file and argue with it without reading any of
 * the arithmetic.
 */

import { SellerHealthBand } from '@prisma/client';

// ── Seller health ────────────────────────────────────────────────────────

/**
 * The eight dimensions the brief named, and what each is worth.
 *
 * The weights answer one question: *what does a woman who buys here actually
 * feel?* She feels a parcel that came late, an order that was cancelled after
 * she paid, and a question nobody answered. She does not feel a seller's
 * attribute completeness. So fulfilment and reliability carry the most, and
 * the dimensions a seller can game cheaply carry the least.
 *
 * They sum to 100 so a dimension's weight is readable as "percent of her
 * score", which is the form a seller can hold an opinion about.
 */
export const HEALTH_WEIGHTS = {
  /// Did the order survive to delivery at all? The heaviest, because a
  /// cancelled order is the one failure that costs a customer outright.
  reliability: 20,
  /// Time from her accepting an order to it leaving her hands. The part of
  /// the wait she alone controls.
  prepSpeed: 15,
  /// What the pieces themselves turned out to be — ratings and returns.
  productQuality: 15,
  /// Did the buyer say she was happy.
  satisfaction: 15,
  /// Time from handover to delivery. Weighted below prep because a courier's
  /// bad week is only partly hers.
  shipSpeed: 10,
  /// Goods coming back. Separated from quality because a return is a specific,
  /// countable failure and deserves to be nameable on its own.
  returns: 10,
  /// How long a buyer waits for an answer.
  responsiveness: 10,
  /// Orders she cancelled herself, weighted apart from reliability so the
  /// screen can distinguish "it fell through" from "she pulled out".
  cancellation: 5,
} as const;

export type HealthDimensionKey = keyof typeof HEALTH_WEIGHTS;

export const HEALTH_DIMENSION_KEYS = Object.keys(
  HEALTH_WEIGHTS,
) as HealthDimensionKey[];

/**
 * Arabic for each dimension: a name and the sentence that says what it means.
 *
 * Rendered here rather than in the client because the label and the arithmetic
 * must not drift apart — if a weight changes and the sentence describing it
 * lives in another repository, the seller reads a lie.
 */
export const HEALTH_DIMENSION_AR: Record<
  HealthDimensionKey,
  { label: string; blurb: string }
> = {
  reliability: {
    label: 'الالتزام بالطلبات',
    blurb: 'الطلبات التي وصلت إلى صاحبتها من بين ما قبلتِه.',
  },
  prepSpeed: {
    label: 'سرعة التجهيز',
    blurb: 'الوقت من قبولكِ الطلب حتى يخرج من عندكِ.',
  },
  productQuality: {
    label: 'جودة المنتجات',
    blurb: 'تقييمات القطع نفسها، ونسبة ما أُرجع منها.',
  },
  satisfaction: {
    label: 'رضا العميلات',
    blurb: 'ما تقوله من اشترين منكِ.',
  },
  shipSpeed: {
    label: 'سرعة الشحن',
    blurb: 'الوقت من تسليم الطلب للمندوب حتى يصل.',
  },
  returns: {
    label: 'المرتجعات',
    blurb: 'نسبة الطلبات التي أُرجعت بعد وصولها.',
  },
  responsiveness: {
    label: 'سرعة الاستجابة',
    blurb: 'كم تستغرقين للرد على رسالة زبونة.',
  },
  cancellation: {
    label: 'الإلغاء',
    blurb: 'الطلبات التي ألغيتِها بعد أن طُلبت.',
  },
};

/**
 * What counts as a full sample for each dimension.
 *
 * Below this the dimension is *reported but discounted*, and the seller is
 * told the sample is thin rather than being handed a number that swings on
 * one bad week. The same idea as the trend engine's exposure confidence and
 * Ohara Value's evidence gate — a marketplace that grades a new seller on four
 * orders teaches her that the score is noise.
 */
export const HEALTH_FULL_SAMPLE: Record<HealthDimensionKey, number> = {
  reliability: 50,
  prepSpeed: 30,
  productQuality: 20,
  satisfaction: 20,
  shipSpeed: 30,
  // Rates need the deepest samples of the lot. A seller with six delivered
  // orders and one return has a "17% return rate", and treating that as a
  // measurement rather than as noise is how a scoring system ends up
  // punishing people for small numbers.
  returns: 40,
  responsiveness: 20,
  cancellation: 40,
};

/** Below this share of a full sample a dimension is not scored at all. */
export const HEALTH_MIN_EVIDENCE = 0.2;

/**
 * Hours, measured from the moment she accepted the order.
 *
 * `good` earns full marks and `bad` earns none, with a straight line between:
 * a threshold with nothing in between turns a system meant to guide her into
 * a cliff she falls off for being an hour late.
 */
export const PREP_HOURS = { good: 24, bad: 96 } as const;

/** Hours from handover to delivery. Syrian intercity delivery is the yardstick. */
export const SHIP_HOURS = { good: 48, bad: 168 } as const;

/** Hours a buyer waits for a first reply. */
export const RESPONSE_HOURS = { good: 2, bad: 48 } as const;

/** Rates where zero is perfect: the share at which the dimension scores zero. */
export const RATE_CEILINGS = {
  /// A tenth of her orders cancelled by her own hand is a shop in trouble.
  cancellation: 0.1,
  /// Returns run higher than cancellations in clothing and that is normal.
  returns: 0.25,
} as const;

/**
 * Where the bands begin.
 *
 * `BUILDING` is not on this ladder on purpose — it is not a low score, it is
 * the absence of one, and it is decided by confidence rather than by points.
 */
export const HEALTH_BANDS: ReadonlyArray<{
  band: SellerHealthBand;
  min: number;
  ar: string;
}> = [
  { band: SellerHealthBand.EXEMPLARY, min: 88, ar: 'مثالية' },
  { band: SellerHealthBand.STRONG, min: 74, ar: 'قوية' },
  { band: SellerHealthBand.STEADY, min: 58, ar: 'مستقرة' },
  { band: SellerHealthBand.AT_RISK, min: 0, ar: 'بحاجة انتباه' },
];

export const HEALTH_BAND_AR: Record<SellerHealthBand, string> = {
  [SellerHealthBand.BUILDING]: 'ما زلنا نتعرّف عليكِ',
  [SellerHealthBand.AT_RISK]: 'بحاجة انتباه',
  [SellerHealthBand.STEADY]: 'مستقرة',
  [SellerHealthBand.STRONG]: 'قوية',
  [SellerHealthBand.EXEMPLARY]: 'مثالية',
};

/** Confidence below which she is BUILDING regardless of the points. */
export const BUILDING_CONFIDENCE = 0.35;

/** How far back the health window looks. */
export const HEALTH_WINDOW_DAYS = 90;

// ── Product health ───────────────────────────────────────────────────────

/**
 * Six axes, and what each is worth.
 *
 * Weighted by what actually moves a listing. Conversion and discoverability
 * are the two that decide whether the product sells at all, so they lead;
 * content and imagery are the two she can fix this afternoon, so they are
 * worth enough to be worth fixing.
 */
export const PRODUCT_HEALTH_WEIGHTS = {
  /// Views that became orders, against the category's own median.
  conversion: 25,
  /// Whether anybody is finding it: search exposure and clicks.
  discoverability: 20,
  /// Photographs — count, and whether they load gracefully.
  imagery: 20,
  /// Title and description: enough words to be understood and searched.
  content: 15,
  /// Attributes filled against what the category's other listings carry.
  attributes: 10,
  /// Attention it is getting relative to its cohort.
  performance: 10,
} as const;

export type ProductHealthKey = keyof typeof PRODUCT_HEALTH_WEIGHTS;

export const PRODUCT_HEALTH_KEYS = Object.keys(
  PRODUCT_HEALTH_WEIGHTS,
) as ProductHealthKey[];

export const PRODUCT_HEALTH_AR: Record<ProductHealthKey, string> = {
  conversion: 'التحويل',
  discoverability: 'قابلية الاكتشاف',
  imagery: 'الصور',
  content: 'المعلومات',
  attributes: 'الخصائص',
  performance: 'الأداء',
};

/** Photographs: the point of diminishing returns, and the floor. */
export const IMAGE_TARGET = 5;
export const IMAGE_MINIMUM = 3;

/** Description length in characters at which content scores full marks. */
export const DESCRIPTION_TARGET = 220;
export const DESCRIPTION_MINIMUM = 80;

/** Title length in characters that reads as a real name rather than a stub. */
export const TITLE_TARGET = 28;

/** Attributes filled at which the axis is full. Category median overrides it. */
export const ATTRIBUTE_TARGET = 6;

/** Views below which this listing's conversion rate means nothing. */
export const CONVERSION_MIN_VIEWS = 25;

/** Listings needed in a category before peer comparison is honest. */
export const PEER_MIN_COHORT = 4;

/** How far above the cohort median a price has to sit before it is worth saying. */
export const PRICE_PREMIUM_BPS = 1500;

/** The product health window. Shorter than health: a listing changes faster. */
export const PRODUCT_WINDOW_DAYS = 30;

// ── Demand radar ─────────────────────────────────────────────────────────

/** Days of demand history the radar reads. */
export const RADAR_WINDOW_DAYS = 28;

/** Minimum searches before unmet demand is worth showing one seller. */
export const UNMET_MIN_SEARCHES = 8;

/** Miss rate above which a term counts as genuinely unserved. */
export const UNMET_MIN_MISS_RATE = 0.4;

/** Days of cover below which stock is a risk when demand is climbing. */
export const STOCK_COVER_DAYS = 7;

/** Growth (as a ratio, so 0.25 = +25%) above which a category is "rising". */
export const RISING_GROWTH = 0.15;
