/**
 * Sales forecasting.
 *
 * Holt's linear trend with damping, a half-strength weekday index, and two
 * honest fallbacks for when there is not enough history to fit either. Pure,
 * like everything else in `kernel/`.
 *
 * Why this method and not something cleverer: a damped Holt is the model that
 * wins forecasting competitions on short, noisy, weekly-seasonal retail series
 * of exactly this length, it has three parameters that can be grid-searched in
 * a millisecond, and — the part that matters here — when it is wrong it is
 * wrong *smoothly*. A model that occasionally predicts forty units for a
 * product that sells two would cost a seller real money in stock, and no
 * accuracy gain is worth that shape of error.
 *
 * The seam for machine learning is `TrendForecastMethod.MODEL`: a future
 * predictor writes the same `ForecastResult` and the same rows, and every
 * consumer keeps working.
 */

import { TrendForecastMethod } from '@prisma/client';
import {
  FORECAST_MIN_SEASONAL_DAYS,
  FORECAST_MIN_TREND_DAYS,
  FORECAST_SEASONALITY_DAMPING,
} from '../trend.constants';
import { clamp, mean, round, stdDev, sum } from './trend-math';

export interface ForecastPoint {
  /** ISO date, `YYYY-MM-DD`. */
  date: string;
  /** Point forecast, never negative. */
  units: number;
  /** 80% interval. */
  low: number;
  high: number;
}

export interface ForecastResult {
  method: TrendForecastMethod;
  points: ForecastPoint[];
  /** Sum of the point forecasts. */
  totalUnits: number;
  /** 0–1. Derived from in-sample error relative to the level. */
  confidence: number;
  /** Mean absolute error of the fitted model on its own history. */
  backtestMae: number | null;
  /** Fitted parameters, for the ops panel and for reproducibility. */
  parameters: Record<string, number> | null;
}

/**
 * The history a forecast is fitted to: a value per day, oldest first, with no
 * gaps. The collector guarantees the no-gaps part by writing zero rows for
 * quiet days, which is why the forecaster can index by position.
 */
export interface ForecastInput {
  /** Daily values, oldest first. Units, or any other non-negative count. */
  values: readonly number[];
  /** The date of `values[0]`, so the output can be dated. */
  startDate: Date;
  horizonDays: number;
}

const ALPHA_GRID = [0.15, 0.3, 0.45, 0.6, 0.8];
const BETA_GRID = [0.02, 0.05, 0.12, 0.25];
const PHI_GRID = [0.8, 0.9, 0.98];

/** 80% two-sided normal quantile. */
const Z80 = 1.2816;

export function forecast(input: ForecastInput): ForecastResult {
  const values = input.values.map((value) =>
    Number.isFinite(value) && value > 0 ? value : 0,
  );
  const horizon = Math.max(1, Math.floor(input.horizonDays));

  if (!values.length || sum(values) === 0) {
    return flat(TrendForecastMethod.INSUFFICIENT_DATA, 0, 0, input, horizon);
  }
  if (values.length < FORECAST_MIN_SEASONAL_DAYS) {
    const level = mean(values);
    return flat(
      TrendForecastMethod.MOVING_AVERAGE,
      level,
      stdDev(values),
      input,
      horizon,
    );
  }
  if (values.length < FORECAST_MIN_TREND_DAYS) {
    return seasonalNaive(values, input, horizon);
  }
  return holtDamped(values, input, horizon);
}

/**
 * Holt's damped trend, with the weekday shape divided out before fitting and
 * multiplied back in afterwards.
 *
 * Deseasonalising first is what keeps the trend term from chasing Fridays.
 */
function holtDamped(
  values: readonly number[],
  input: ForecastInput,
  horizon: number,
): ForecastResult {
  const weekday = weekdayIndex(values, input.startDate);
  const deseasonalised = values.map(
    (value, index) => value / weekday[dayOfWeek(input.startDate, index)],
  );

  let best: {
    alpha: number;
    beta: number;
    phi: number;
    sse: number;
    level: number;
    trend: number;
    residuals: number[];
  } | null = null;

  for (const alpha of ALPHA_GRID) {
    for (const beta of BETA_GRID) {
      for (const phi of PHI_GRID) {
        const fit = fitHolt(deseasonalised, alpha, beta, phi);
        if (!best || fit.sse < best.sse) best = { alpha, beta, phi, ...fit };
      }
    }
  }
  // `deseasonalised` is non-empty here, so the grid always produces a fit.
  if (!best) return seasonalNaive(values, input, horizon);

  const sigma = stdDev(best.residuals);
  const mae = mean(best.residuals.map(Math.abs));

  const points: ForecastPoint[] = [];
  // Damped trend accumulates as φ + φ² + … + φʰ, so the projection flattens
  // out instead of running to infinity — the whole point of the damping.
  let damping = 0;
  for (let h = 1; h <= horizon; h += 1) {
    damping += best.phi ** h;
    const base = best.level + damping * best.trend;
    const index = weekday[dayOfWeek(input.startDate, values.length + h - 1)];
    const point = Math.max(0, base * index);
    // Variance grows with the horizon; √h is the standard random-walk shape
    // and is the conservative choice against a damped trend.
    const spread = Z80 * sigma * Math.sqrt(h) * index;
    points.push({
      date: isoDate(addDays(input.startDate, values.length + h - 1)),
      units: round(point, 3),
      low: round(Math.max(0, point - spread), 3),
      high: round(point + spread, 3),
    });
  }

  return {
    method: TrendForecastMethod.HOLT_DAMPED,
    points,
    totalUnits: round(sum(points.map((p) => p.units)), 3),
    confidence: confidenceFromError(mae, mean(values)),
    backtestMae: round(mae, 4),
    parameters: {
      alpha: best.alpha,
      beta: best.beta,
      phi: best.phi,
      level: round(best.level, 4),
      trend: round(best.trend, 4),
      sigma: round(sigma, 4),
    },
  };
}

function fitHolt(
  values: readonly number[],
  alpha: number,
  beta: number,
  phi: number,
): { sse: number; level: number; trend: number; residuals: number[] } {
  let level = values[0] ?? 0;
  // Seed the slope from the first week so the fit does not spend its first
  // fortnight climbing out of a zero trend.
  const seedSpan = Math.min(7, values.length - 1);
  let trend = seedSpan > 0 ? ((values[seedSpan] ?? 0) - level) / seedSpan : 0;

  let sse = 0;
  const residuals: number[] = [];
  for (let t = 1; t < values.length; t += 1) {
    const predicted = level + phi * trend;
    const actual = values[t] ?? 0;
    const error = actual - predicted;
    residuals.push(error);
    sse += error * error;

    const nextLevel = alpha * actual + (1 - alpha) * predicted;
    trend = beta * (nextLevel - level) + (1 - beta) * phi * trend;
    level = nextLevel;
  }
  return { sse, level, trend, residuals };
}

/**
 * The last full week, repeated. Used when there is a season but not enough
 * history to trust a slope — which is most products in their first month.
 */
function seasonalNaive(
  values: readonly number[],
  input: ForecastInput,
  horizon: number,
): ForecastResult {
  const week = values.slice(-7);
  const residuals: number[] = [];
  for (let t = 7; t < values.length; t += 1) {
    residuals.push((values[t] ?? 0) - (values[t - 7] ?? 0));
  }
  const sigma = residuals.length ? stdDev(residuals) : stdDev(values);
  const mae = residuals.length ? mean(residuals.map(Math.abs)) : stdDev(values);

  const points: ForecastPoint[] = [];
  for (let h = 1; h <= horizon; h += 1) {
    const point = Math.max(0, week[(h - 1) % week.length] ?? 0);
    const spread = Z80 * sigma * Math.sqrt(Math.ceil(h / 7));
    points.push({
      date: isoDate(addDays(input.startDate, values.length + h - 1)),
      units: round(point, 3),
      low: round(Math.max(0, point - spread), 3),
      high: round(point + spread, 3),
    });
  }

  return {
    method: TrendForecastMethod.SEASONAL_NAIVE,
    points,
    totalUnits: round(sum(points.map((p) => p.units)), 3),
    confidence: confidenceFromError(mae, mean(values)),
    backtestMae: round(mae, 4),
    parameters: null,
  };
}

/** A flat line at `level`. The floor every other path degrades to. */
function flat(
  method: TrendForecastMethod,
  level: number,
  sigma: number,
  input: ForecastInput,
  horizon: number,
): ForecastResult {
  const points: ForecastPoint[] = [];
  const base = Math.max(0, level);
  for (let h = 1; h <= horizon; h += 1) {
    const spread = Z80 * sigma;
    points.push({
      date: isoDate(addDays(input.startDate, input.values.length + h - 1)),
      units: round(base, 3),
      low: round(Math.max(0, base - spread), 3),
      high: round(base + spread, 3),
    });
  }
  return {
    method,
    points,
    totalUnits: round(base * horizon, 3),
    confidence:
      method === TrendForecastMethod.INSUFFICIENT_DATA
        ? 0
        : confidenceFromError(sigma, base),
    backtestMae: method === TrendForecastMethod.INSUFFICIENT_DATA ? null : round(sigma, 4),
    parameters: null,
  };
}

/**
 * The multiplicative weekday shape, normalised to mean 1 and pulled halfway
 * back toward flat.
 *
 * The damping is not timidity. Four weeks give roughly four observations per
 * weekday, and four observations of "Fridays are busy" is not enough to
 * multiply a forecast by 1.8 — halving the effect keeps the useful part of the
 * shape and throws away most of the noise.
 */
function weekdayIndex(
  values: readonly number[],
  startDate: Date,
): Record<number, number> {
  const totals = new Array(7).fill(0);
  const counts = new Array(7).fill(0);
  for (let i = 0; i < values.length; i += 1) {
    const dow = dayOfWeek(startDate, i);
    totals[dow] += values[i] ?? 0;
    counts[dow] += 1;
  }
  const averages = totals.map((total, index) =>
    counts[index] ? total / counts[index] : 0,
  );
  const overall = mean(averages.filter((_, index) => counts[index] > 0));
  const index: Record<number, number> = {};
  for (let dow = 0; dow < 7; dow += 1) {
    const raw = overall > 0 && counts[dow] ? averages[dow] / overall : 1;
    const damped = 1 + (raw - 1) * FORECAST_SEASONALITY_DAMPING;
    // Never zero: dividing the history by the index has to stay defined.
    index[dow] = clamp(damped, 0.35, 2.5);
  }
  return index;
}

/**
 * 0–1 confidence from the in-sample error relative to the level.
 *
 * A mean absolute error equal to the mean itself is worthless and scores 0.33;
 * an error a tenth of the mean scores 0.9. The `+1` keeps a product selling
 * 0.2 units a day from scoring a spurious 1.0 for being predictably almost
 * nothing.
 */
function confidenceFromError(mae: number, level: number): number {
  if (!Number.isFinite(mae) || mae < 0) return 0;
  const scale = Math.max(Math.abs(level), 0) + 1;
  return round(clamp(1 / (1 + mae / scale)), 4);
}

/**
 * Days until stock runs out at the forecast rate.
 *
 * Walks the points rather than dividing by an average, because a forecast that
 * ramps sells out sooner than its mean suggests — and "you have eleven days"
 * is only useful if it is the right eleven.
 */
export function stockoutInDays(
  stockUnits: number,
  points: readonly ForecastPoint[],
): number | null {
  if (!Number.isFinite(stockUnits) || stockUnits <= 0) return 0;
  let remaining = stockUnits;
  for (let i = 0; i < points.length; i += 1) {
    const daily = Math.max(0, points[i]?.units ?? 0);
    if (daily <= 0) continue;
    if (remaining <= daily) return round(i + remaining / daily, 2);
    remaining -= daily;
  }
  // Survives the whole horizon. Null rather than a made-up number beyond it.
  return null;
}

// ── Date helpers. UTC throughout: a "day" is a row key, not a local calendar. ──

export function addDays(date: Date, days: number): Date {
  const next = new Date(date.getTime());
  next.setUTCDate(next.getUTCDate() + days);
  return next;
}

export function isoDate(date: Date): string {
  return date.toISOString().slice(0, 10);
}

function dayOfWeek(startDate: Date, offset: number): number {
  return addDays(startDate, offset).getUTCDay();
}
