/**
 * The Trend Score.
 *
 * One pure function turns a window of daily facts into a number between 0 and
 * 100, nine components that add up to it, a stage on the curve, and a
 * confidence that says how much of it to believe.
 *
 * Nothing in this file reads a database, and nothing in it asks a model. That
 * is the load-bearing property of the whole engine: the numbers on the
 * dashboards are arithmetic over rows, and Claude's only job downstream is to
 * describe them in a sentence a seller wants to read.
 */

import { TrendStage, TrendWindow } from '@prisma/client';
import {
  ENGAGEMENT_HALF_PER_DAY,
  ENGAGEMENT_WEIGHTS,
  KERNEL_METHOD,
  MIN_EXPOSURE_FOR_STAGE,
  SCORE_COMPONENT_KEYS,
  SCORE_WEIGHTS,
  STAGE_THRESHOLDS,
  ScoreComponentKey,
  VELOCITY_HALF_UNITS_PER_DAY,
} from '../trend.constants';
import {
  accelerationComponent,
  clamp,
  confidenceFromExposure,
  conversionComponent,
  exposure,
  growthComponent,
  growthEvidence,
  growthShape,
  qualityComponent,
  round,
  saturate,
  splitWindows,
  sum,
} from './trend-math';

/**
 * One day of demand for one subject, in the shape the kernel needs.
 *
 * Deliberately narrower than the `*DemandDaily` rows it is built from: the
 * kernel should not know what a `brandId` is, and a test should be able to
 * write a day of history in one line.
 */
export interface DemandDay {
  /** ISO date, `YYYY-MM-DD`. Only used for ordering and for the output. */
  day: string;
  views: number;
  searchHits: number;
  cartAdds: number;
  favorites: number;
  wishlistAdds: number;
  shares: number;
  contentEngagements: number;
  orders: number;
  units: number;
  revenueSyp: number;
  returns: number;
  reviews: number;
  ratingSum: number;
  stockUnits: number;
  inStock: boolean;
}

export function emptyDemandDay(day: string): DemandDay {
  return {
    day,
    views: 0,
    searchHits: 0,
    cartAdds: 0,
    favorites: 0,
    wishlistAdds: 0,
    shares: 0,
    contentEngagements: 0,
    orders: 0,
    units: 0,
    revenueSyp: 0,
    returns: 0,
    reviews: 0,
    ratingSum: 0,
    stockUnits: 0,
    inStock: false,
  };
}

/**
 * What the cohort looked like on the same day.
 *
 * Stage is a *relative* judgement — "climbing off a small base" needs to know
 * what a small base is on this platform this week — so the classifier is given
 * the cohort's shape rather than a hard-coded unit count that would be wrong
 * on the first busy month.
 */
export interface CohortContext {
  /** Median units sold in the window across the scored cohort. */
  medianUnits: number;
  /** 75th percentile of units, the line above which volume is "material". */
  p75Units: number;
}

export const NEUTRAL_COHORT: CohortContext = { medianUnits: 0, p75Units: 0 };

export type ScoreComponents = Record<ScoreComponentKey, number>;

export interface TrendScoreResult {
  /** 0–100. */
  score: number;
  stage: TrendStage;
  /** 0–1. */
  confidence: number;
  sampleSize: number;
  components: ScoreComponents;
  /** The raw window figures the components came from, for the tooltip. */
  metrics: TrendScoreMetrics;
  method: string;
}

export interface TrendScoreMetrics {
  windowDays: number;
  views: number;
  previousViews: number;
  searchHits: number;
  previousSearchHits: number;
  cartAdds: number;
  previousCartAdds: number;
  orders: number;
  previousOrders: number;
  units: number;
  previousUnits: number;
  revenueSyp: number;
  favorites: number;
  shares: number;
  returns: number;
  reviews: number;
  averageRating: number;
  unitsPerDay: number;
  viewToCartRate: number;
  cartToOrderRate: number;
  viewToOrderRate: number;
  returnRate: number;
  inStockRate: number;
  stockUnits: number;
  daysOfCover: number | null;
}

/** Maps a window length in days onto the enum the rows are keyed by. */
export function windowEnum(days: number): TrendWindow {
  if (days <= 7) return TrendWindow.D7;
  if (days <= 14) return TrendWindow.D14;
  return TrendWindow.D30;
}

export function windowDays(window: TrendWindow): number {
  switch (window) {
    case TrendWindow.D7:
      return 7;
    case TrendWindow.D14:
      return 14;
    default:
      return 30;
  }
}

/**
 * Score one subject over one window.
 *
 * `series` is oldest-first and should hold `2 × windowDays` entries — the
 * window and the window before it, which is what every growth term compares.
 * A shorter series is not an error; it scores what it has, and confidence
 * carries the fact that there was less of it.
 */
export function scoreTrend(
  series: readonly DemandDay[],
  windowLength: number,
  cohort: CohortContext = NEUTRAL_COHORT,
): TrendScoreResult {
  const { current, previous } = splitWindows(series, windowLength);
  const days = Math.max(1, current.length);

  const field = (rows: readonly DemandDay[], key: keyof DemandDay): number =>
    sum(rows.map((row) => Number(row[key] ?? 0)));

  const views = field(current, 'views');
  const prevViews = field(previous, 'views');
  const searchHits = field(current, 'searchHits');
  const prevSearchHits = field(previous, 'searchHits');
  const cartAdds = field(current, 'cartAdds');
  const prevCartAdds = field(previous, 'cartAdds');
  const orders = field(current, 'orders');
  const prevOrders = field(previous, 'orders');
  const units = field(current, 'units');
  const prevUnits = field(previous, 'units');
  const revenueSyp = field(current, 'revenueSyp');
  const favorites = field(current, 'favorites');
  const wishlistAdds = field(current, 'wishlistAdds');
  const shares = field(current, 'shares');
  const contentEngagements = field(current, 'contentEngagements');
  const returns = field(current, 'returns');
  const reviews = field(current, 'reviews');
  const ratingSum = field(current, 'ratingSum');

  const inStockDays = current.filter((row) => row.inStock).length;
  const inStockRate = current.length ? inStockDays / current.length : 0;
  // Stock is a snapshot, not a flow: the latest reading is the true one.
  const stockUnits = current.length
    ? Math.max(0, current[current.length - 1]?.stockUnits ?? 0)
    : 0;

  const unitsPerDay = units / days;
  const daysOfCover =
    unitsPerDay > 0 ? round(stockUnits / unitsPerDay, 2) : null;

  // ── The nine components ────────────────────────────────────────────────
  const engagementPerDay =
    (favorites * ENGAGEMENT_WEIGHTS.favorites +
      wishlistAdds * ENGAGEMENT_WEIGHTS.wishlistAdds +
      shares * ENGAGEMENT_WEIGHTS.shares +
      contentEngagements * ENGAGEMENT_WEIGHTS.contentEngagements) /
    days;

  const components: ScoreComponents = {
    viewGrowth: growthComponent(views, prevViews),
    searchGrowth: growthComponent(searchHits, prevSearchHits),
    cartGrowth: growthComponent(cartAdds, prevCartAdds),
    conversion: conversionComponent({ views, cartAdds, orders }),
    salesVelocity: saturate(unitsPerDay, VELOCITY_HALF_UNITS_PER_DAY),
    // Acceleration reads the *whole* series, both windows, because a second
    // difference needs three points and one window only gives two.
    acceleration: accelerationComponent(
      series.map((row) => row.views + row.cartAdds * 3 + row.orders * 8),
    ),
    engagement: saturate(engagementPerDay, ENGAGEMENT_HALF_PER_DAY),
    quality: qualityComponent(ratingSum, reviews),
    // Half for being buyable at all, half for having enough to sell. A
    // fortnight of cover is treated as fully stocked; hoarding is not a trend.
    availability: clamp(
      inStockRate * 0.5 + saturate(daysOfCover ?? (stockUnits > 0 ? 30 : 0), 14) * 0.5,
    ),
  };

  const weighted = SCORE_COMPONENT_KEYS.reduce(
    (total, key) => total + components[key] * SCORE_WEIGHTS[key],
    0,
  );
  const score = round(clamp(weighted) * 100, 2);

  const sampleSize = exposure({ views, cartAdds, orders });
  const confidence = round(confidenceFromExposure(sampleSize), 4);

  const averageRating = reviews > 0 ? round(ratingSum / reviews, 2) : 0;
  const metrics: TrendScoreMetrics = {
    windowDays: days,
    views,
    previousViews: prevViews,
    searchHits,
    previousSearchHits: prevSearchHits,
    cartAdds,
    previousCartAdds: prevCartAdds,
    orders,
    previousOrders: prevOrders,
    units,
    previousUnits: prevUnits,
    revenueSyp: round(revenueSyp, 2),
    favorites,
    shares,
    returns,
    reviews,
    averageRating,
    unitsPerDay: round(unitsPerDay, 3),
    viewToCartRate: views > 0 ? round(cartAdds / views, 4) : 0,
    cartToOrderRate: cartAdds > 0 ? round(orders / cartAdds, 4) : 0,
    viewToOrderRate: views > 0 ? round(orders / views, 4) : 0,
    returnRate: units > 0 ? round(returns / units, 4) : 0,
    inStockRate: round(inStockRate, 3),
    stockUnits,
    daysOfCover,
  };

  return {
    score,
    stage: classifyStage({
      demandGrowth: blendGrowth({
        views,
        previousViews: prevViews,
        searchHits,
        previousSearchHits: prevSearchHits,
        cartAdds,
        previousCartAdds: prevCartAdds,
        units,
        previousUnits: prevUnits,
      }),
      components,
      sampleSize,
      units,
      cohort,
    }),
    confidence,
    sampleSize,
    components: roundComponents(components),
    metrics,
    method: KERNEL_METHOD,
  };
}

function roundComponents(components: ScoreComponents): ScoreComponents {
  const out = {} as ScoreComponents;
  for (const key of SCORE_COMPONENT_KEYS) out[key] = round(components[key], 4);
  return out;
}

/**
 * Where the subject sits on its curve.
 *
 * A decision tree rather than a formula because the stages are not ordered on
 * one axis: `PEAKING` and `EMERGING` are both interesting, in opposite
 * directions, and collapsing them into a single "momentum" number is how a
 * dashboard ends up recommending that you restock something on its way down.
 *
 * The order of the branches matters. `EMERGING` is tested before `RISING`
 * precisely so a low-volume climber is not swallowed by the generic case.
 */
/**
 * Blended demand growth: the average of the growth signals that **have any
 * evidence behind them**, with sales as the last resort.
 *
 * Averaging all three unconditionally is the obvious implementation and it is
 * wrong in one important case. A platform that has not instrumented product
 * views yet has zero views this window and zero last window, so `viewGrowth`
 * and `cartGrowth` are legitimately 0 — and a flat average then puts every
 * product that sold anything at a growth index near zero, which the classifier
 * reads as `DECLINING`. The first night the engine runs, on a shop with real
 * orders and no page-view tracking, it would report the entire catalogue as in
 * decline. That is not a missing signal, it is a wrong one.
 *
 * So each term is included only where the counts say it was measured, and if
 * none of the three was, units growth answers instead. An engine should be
 * silent about what it cannot see and honest about what it can.
 */
export function blendGrowth(input: {
  views: number;
  previousViews: number;
  searchHits: number;
  previousSearchHits: number;
  cartAdds: number;
  previousCartAdds: number;
  units: number;
  previousUnits: number;
}): number {
  const terms: Array<[current: number, previous: number]> = [
    [input.views, input.previousViews],
    [input.searchHits, input.previousSearchHits],
    [input.cartAdds, input.previousCartAdds],
  ];

  let weighted = 0;
  let weight = 0;
  for (const [current, previous] of terms) {
    const evidence = growthEvidence(current, previous);
    if (evidence === 0) continue;
    weighted += growthShape(current, previous) * evidence;
    weight += evidence;
  }
  if (weight > 0) return clamp(weighted / weight);

  // Nothing upstream of the till is instrumented. Sales are a lagging
  // indicator and a poor substitute, but they are a real measurement.
  if (input.units + input.previousUnits > 0) {
    return growthShape(input.units, input.previousUnits);
  }
  return 0;
}

export function classifyStage(input: {
  demandGrowth: number;
  components: ScoreComponents;
  sampleSize: number;
  units: number;
  cohort: CohortContext;
}): TrendStage {
  const { demandGrowth: growth, components, sampleSize, units, cohort } = input;
  if (sampleSize < MIN_EXPOSURE_FOR_STAGE) return TrendStage.DORMANT;

  const material = units >= Math.max(cohort.p75Units, 1);
  const small = units <= Math.max(cohort.medianUnits, 1);

  if (
    small &&
    growth >= STAGE_THRESHOLDS.emergingGrowth &&
    components.acceleration >= STAGE_THRESHOLDS.emergingAcceleration
  ) {
    return TrendStage.EMERGING;
  }
  if (growth >= STAGE_THRESHOLDS.risingGrowth) return TrendStage.RISING;
  if (material && growth >= STAGE_THRESHOLDS.peakingGrowthFloor) {
    return TrendStage.PEAKING;
  }
  if (growth <= STAGE_THRESHOLDS.decliningGrowth) return TrendStage.DECLINING;
  if (growth < STAGE_THRESHOLDS.coolingGrowth) return TrendStage.COOLING;
  return TrendStage.STEADY;
}

/**
 * The number a leaderboard sorts by.
 *
 * Not the score itself: a product with one perfect day would top every list.
 * Shrinking toward zero by confidence keeps the ordering honest while still
 * letting a genuinely new product beat an established one — the floor of 0.35
 * means a high-confidence average never permanently outranks a low-confidence
 * excellent.
 */
export function rankingScore(score: number, confidence: number): number {
  return round(score * (0.35 + 0.65 * clamp(confidence)), 4);
}

/** The Arabic label for a stage, used by the templates and the serializer. */
export const STAGE_LABELS_AR: Record<TrendStage, string> = {
  [TrendStage.DORMANT]: 'خامل',
  [TrendStage.EMERGING]: 'صاعد مبكرًا',
  [TrendStage.RISING]: 'في ارتفاع',
  [TrendStage.PEAKING]: 'في الذروة',
  [TrendStage.STEADY]: 'مستقر',
  [TrendStage.COOLING]: 'يتباطأ',
  [TrendStage.DECLINING]: 'في تراجع',
};
