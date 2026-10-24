/**
 * Every tuning number the Ohara Trend Engine uses, in one file.
 *
 * They are constants rather than environment variables on purpose. A weight is
 * not configuration — it is part of the definition of the score, and a score
 * whose meaning changes with a deployment is a score nobody can compare across
 * two weeks. When a weight really must change, it changes here, `KERNEL_METHOD`
 * is bumped, and every row written afterwards says which kernel produced it.
 */

/** Stamped onto every score row. Bump on any change to weights or shapes. */
export const KERNEL_METHOD = 'reem-trend-kernel-v1';

/** Stamped onto insights an Arabic template phrased. */
export const TEMPLATE_NARRATOR = 'reem-trend-templates-v1';

/**
 * The nine components of the Trend Score, and what each is worth.
 *
 * The shape of this list is the answer to "why isn't this just best sellers?".
 * Sales are the single heaviest term, and they are still only seventeen
 * percent: a product that nobody has bought yet but that is being viewed,
 * searched for and added to carts at an accelerating rate outscores a steady
 * seller, which is exactly the moment a merchandiser can still do something
 * about it.
 *
 * Sums to 1.0 — asserted in the kernel's tests, because a silent drift here
 * rescales every score on the platform.
 */
export const SCORE_WEIGHTS = {
  /** Growth in product-page views, window over previous window. */
  viewGrowth: 0.13,
  /** Growth in appearances for a search term. */
  searchGrowth: 0.1,
  /** Growth in add-to-cart — the strongest pre-purchase intent there is. */
  cartGrowth: 0.12,
  /** View→cart and cart→order, shrunk toward the platform mean. */
  conversion: 0.13,
  /** Units per day, saturating. The one term best-seller lists use alone. */
  salesVelocity: 0.17,
  /** Second derivative: is the growth itself growing? */
  acceleration: 0.11,
  /** Favourites, wishlists, shares, post and story engagement. */
  engagement: 0.1,
  /** Wilson lower bound on the rating. Protects against one lucky review. */
  quality: 0.08,
  /** Could she actually buy it? An out-of-stock product cannot trend. */
  availability: 0.06,
} as const;

export type ScoreComponentKey = keyof typeof SCORE_WEIGHTS;

export const SCORE_COMPONENT_KEYS = Object.keys(
  SCORE_WEIGHTS,
) as ScoreComponentKey[];

/**
 * Laplace smoothing added to both sides of every growth ratio.
 *
 * Without it, one view yesterday and three today is a 200% surge and the top
 * of the leaderboard is noise. Three is small enough not to flatten a real
 * move on a busy product and large enough to make a two-event product boring.
 */
export const GROWTH_SMOOTHING = 3;

/**
 * The log-ratio that maps to a near-maximum growth component.
 *
 * `ln(3)`: tripling in a window is the ceiling the squash treats as "as fast
 * as this measurement can usefully distinguish". Beyond it the curve is flat,
 * so a 10× spike and a 30× spike do not fight over the same top slot on the
 * strength of their tails.
 */
export const GROWTH_SCALE = Math.log(3);

/**
 * Evidence half-point for a growth component: the combined event count at
 * which the component is trusted at half strength.
 */
export const GROWTH_EVIDENCE_HALF = 8;

/** Units per day at which `salesVelocity` reaches 0.5. */
export const VELOCITY_HALF_UNITS_PER_DAY = 1.5;

/** Weighted engagement events per day at which `engagement` reaches 0.5. */
export const ENGAGEMENT_HALF_PER_DAY = 1.2;

/**
 * How the soft intent signals are weighted against each other inside the
 * engagement component. A share is worth more than a favourite because it
 * costs more and reaches someone new.
 */
export const ENGAGEMENT_WEIGHTS = {
  favorites: 1,
  wishlistAdds: 1.2,
  shares: 2.5,
  contentEngagements: 0.6,
} as const;

/**
 * Platform priors for the two conversion rates, and how many trials it takes
 * to outvote them.
 *
 * A product with four views and one order has a 25% conversion rate and no
 * business being believed. Shrinking toward the prior means it has to earn its
 * way out of the average.
 */
export const CONVERSION_PRIOR = {
  /** view → cart add. */
  viewToCart: 0.06,
  /** cart add → order. */
  cartToOrder: 0.25,
  /** Pseudo-trials backing each prior. */
  strength: 25,
} as const;

/**
 * Exposure at which the conversion component is trusted at half strength.
 *
 * Separate from `CONFIDENCE_HALF_EXPOSURE` because it answers a different
 * question. That one asks how much of the whole score to believe; this one
 * stops a product with no funnel at all from banking the prior as if it had
 * one.
 */
export const CONVERSION_EVIDENCE_HALF = 40;

/** The rate at which a shrunk conversion rate scores 1.0. */
export const CONVERSION_CEILING = {
  viewToCart: 0.2,
  cartToOrder: 0.6,
} as const;

/** z for the 95% Wilson lower bound used by the quality component. */
export const WILSON_Z = 1.96;

/**
 * Exposure at which `confidence` reaches 0.5.
 *
 * Exposure is views + 3×cart adds + 8×orders — an event-count in which a
 * purchase is worth eight glances, because it is.
 */
export const CONFIDENCE_HALF_EXPOSURE = 60;

export const EXPOSURE_WEIGHTS = {
  views: 1,
  cartAdds: 3,
  orders: 8,
} as const;

/** Below this exposure a subject is `DORMANT` whatever its ratios say. */
export const MIN_EXPOSURE_FOR_STAGE = 12;

/**
 * Stage thresholds on the blended growth index (0–1, 0.5 is flat).
 *
 * `emergingGrowth` sits below `risingGrowth` on purpose: emerging is not a
 * *weaker* rise, it is a rise on a product that has not sold much yet, and
 * demanding a steeper slope from a low-volume product than from a high-volume
 * one is how early signal gets missed.
 */
export const STAGE_THRESHOLDS = {
  emergingGrowth: 0.6,
  emergingAcceleration: 0.52,
  risingGrowth: 0.62,
  peakingGrowthFloor: 0.45,
  coolingGrowth: 0.45,
  decliningGrowth: 0.34,
} as const;

/**
 * Which windows the nightly run scores. All three, because a seller and a
 * merchandiser are asking different questions of the same data.
 */
export const SCORED_WINDOWS = [7, 14, 30] as const;
export type ScoredWindowDays = (typeof SCORED_WINDOWS)[number];

/** Horizons the forecaster writes. */
export const FORECAST_HORIZONS = [7, 14, 30] as const;

/** Minimum days of history before Holt is fitted rather than a naive method. */
export const FORECAST_MIN_TREND_DAYS = 21;
/** Minimum days before a weekly-naive forecast is preferred to a flat mean. */
export const FORECAST_MIN_SEASONAL_DAYS = 7;
/** How much of the raw weekday index is applied. Half, to avoid overfitting. */
export const FORECAST_SEASONALITY_DAMPING = 0.5;

/**
 * k-anonymity floor for any distinct-person count the engine stores.
 *
 * A "3 women viewed this" is a fact about a product. A "1 woman viewed this",
 * on a seller's dashboard, next to a timestamp, is a fact about a woman.
 */
export const K_ANONYMITY = 5;

/**
 * How long raw `analytics_events` rows are kept after they have been rolled up.
 *
 * The aggregate is permanent and carries no identity; the raw row carries a
 * user id and a session id and is the only thing here that could be read back
 * as a person's behaviour. Ninety days is long enough for the existing
 * analytics dashboard's longest range and for a backfill after an outage.
 */
export const RAW_EVENT_RETENTION_DAYS = 90;

/** How long a generated insight stays on a dashboard. */
export const INSIGHT_TTL_DAYS = 7;

/** Cap on insights generated per seller per run, highest priority first. */
export const MAX_INSIGHTS_PER_SELLER = 12;
/** Cap on platform insights per run. */
export const MAX_ADMIN_INSIGHTS = 40;

/**
 * Unmet demand gates. A term has to be asked for by enough people, miss often
 * enough, and be recent enough, before the buying team is told about it.
 */
export const UNMET_DEMAND = {
  window: 30,
  minSearches: 8,
  minMissRate: 0.45,
  /** A term whose click-through is this low is unmet even when it returns rows. */
  weakClickRate: 0.08,
  minSearchesForWeakClick: 20,
} as const;

/**
 * SYP price bands. Fixed edges rather than quantiles so a band means the same
 * thing in March as in September, which is the only way "الطلب انتقل إلى نطاق
 * سعري أعلى" is a sentence with content.
 */
export const PRICE_BANDS: ReadonlyArray<{
  code: string;
  labelAr: string;
  min: number;
  max: number | null;
}> = [
  // New lira, so the boundaries carry two zeros fewer than the ones the trend
  // engine shipped with. The bands themselves are unchanged in real terms.
  { code: 'B1', labelAr: 'أقل من 500', min: 0, max: 500 },
  { code: 'B2', labelAr: '500 – 1000', min: 500, max: 1_000 },
  { code: 'B3', labelAr: '1000 – 2500', min: 1_000, max: 2_500 },
  { code: 'B4', labelAr: '2500 – 5000', min: 2_500, max: 5_000 },
  { code: 'B5', labelAr: '5000 – 10 آلاف', min: 5_000, max: 10_000 },
  { code: 'B6', labelAr: 'أكثر من 10 آلاف', min: 10_000, max: null },
];

/** The scope key used for a platform-wide slice or forecast. */
export const PLATFORM_SCOPE = 'PLATFORM';
