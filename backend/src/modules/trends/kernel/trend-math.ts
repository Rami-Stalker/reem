/**
 * The arithmetic the Trend Engine is built out of.
 *
 * Every function here is pure, total and deterministic: same inputs, same
 * number, no clock, no database, no network. That is not stylistic — it is the
 * reason a seller can be told "your score went from 41 to 63" and the claim can
 * be re-derived a month later from the same rows.
 *
 * The shapes are chosen so that no input can produce a NaN, an Infinity or a
 * value outside its stated range, because these numbers end up multiplied
 * together and one NaN silently blanks a whole dashboard.
 */

import {
  CONFIDENCE_HALF_EXPOSURE,
  CONVERSION_CEILING,
  CONVERSION_EVIDENCE_HALF,
  CONVERSION_PRIOR,
  EXPOSURE_WEIGHTS,
  GROWTH_EVIDENCE_HALF,
  GROWTH_SCALE,
  GROWTH_SMOOTHING,
  WILSON_Z,
} from '../trend.constants';

/** Clamp into [min, max], mapping NaN to `min` rather than propagating it. */
export function clamp(value: number, min = 0, max = 1): number {
  if (!Number.isFinite(value)) return min;
  return value < min ? min : value > max ? max : value;
}

/** Sum, ignoring anything that is not a finite number. */
export function sum(values: readonly number[]): number {
  let total = 0;
  for (const value of values) if (Number.isFinite(value)) total += value;
  return total;
}

export function mean(values: readonly number[]): number {
  return values.length ? sum(values) / values.length : 0;
}

/** Population standard deviation. Zero for an empty or constant series. */
export function stdDev(values: readonly number[]): number {
  if (values.length < 2) return 0;
  const m = mean(values);
  const variance =
    sum(values.map((value) => (value - m) ** 2)) / values.length;
  return Math.sqrt(Math.max(variance, 0));
}

/**
 * Linear-interpolated quantile of an unsorted series. `q` is clamped to [0,1].
 * Used for the cohort medians the stage classifier compares against, and for
 * the median price a category carries.
 */
export function quantile(values: readonly number[], q: number): number {
  const finite = values.filter((value) => Number.isFinite(value));
  if (!finite.length) return 0;
  const sorted = [...finite].sort((a, b) => a - b);
  const position = clamp(q) * (sorted.length - 1);
  const lower = Math.floor(position);
  const upper = Math.ceil(position);
  if (lower === upper) return sorted[lower];
  return sorted[lower] + (sorted[upper] - sorted[lower]) * (position - lower);
}

export function median(values: readonly number[]): number {
  return quantile(values, 0.5);
}

/**
 * A saturating 0→1 normaliser: `half` is the input that returns 0.5.
 *
 * Preferred to a hard cap everywhere a rate is turned into a component,
 * because it never has a ceiling a product can sit flat against — twice the
 * half-point is 0.67, ten times is 0.87 — so the ordering between two very
 * strong products survives normalisation.
 */
export function saturate(value: number, half: number): number {
  if (!Number.isFinite(value) || value <= 0) return 0;
  if (!Number.isFinite(half) || half <= 0) return 1;
  return value / (value + half);
}

/**
 * Laplace-smoothed log growth between two windows.
 *
 * Returns a signed log-ratio: 0 is flat, positive is growth. Smoothing is
 * added to both sides so a jump from zero is a finite number and a two-event
 * product cannot post an infinite rate.
 */
export function logGrowth(
  current: number,
  previous: number,
  smoothing = GROWTH_SMOOTHING,
): number {
  const cur = Math.max(0, Number.isFinite(current) ? current : 0);
  const prev = Math.max(0, Number.isFinite(previous) ? previous : 0);
  return Math.log((cur + smoothing) / (prev + smoothing));
}

/**
 * A growth component in [0, 1], evidence-weighted.
 *
 * Two things are folded together here, and both are necessary:
 *
 *  - the *shape*: `0.5 + 0.5·tanh(logRatio / scale)` puts flat at 0.5, a
 *    tripling near 0.88 and a collapse near 0.12, with no hard ceiling.
 *  - the *evidence*: multiplied by `n / (n + k)`, so a product with no traffic
 *    scores 0 rather than the 0.5 a flat line would otherwise earn. Without
 *    this, every dead product in the catalogue would sit at the midpoint of
 *    three of the nine components and the whole scale would compress.
 */
export function growthComponent(
  current: number,
  previous: number,
  options: { smoothing?: number; scale?: number; evidenceHalf?: number } = {},
): number {
  const evidence = growthEvidence(current, previous, options.evidenceHalf);
  if (evidence === 0) return 0;
  return clamp(evidence * growthShape(current, previous, options));
}

/**
 * The *shape* of a growth ratio, with no evidence weighting: 0.5 is flat, a
 * tripling is near 0.88, a collapse near 0.12.
 *
 * Separated from `growthComponent` because the two uses need different things
 * and conflating them was a real bug. **Scoring** wants the evidence factor —
 * no traffic, no points. **Classifying a direction** must not have it: a
 * product whose searches doubled from five to ten is growing, and multiplying
 * that by a small evidence factor produces 0.4, which reads as *shrinking* and
 * drags the blended index below the rising threshold. A product with a steep
 * view ramp and a thin search signal was being classified `COOLING`.
 */
export function growthShape(
  current: number,
  previous: number,
  options: { smoothing?: number; scale?: number } = {},
): number {
  const smoothing = options.smoothing ?? GROWTH_SMOOTHING;
  const scale = options.scale ?? GROWTH_SCALE;
  return clamp(
    0.5 + 0.5 * Math.tanh(logGrowth(current, previous, smoothing) / scale),
  );
}

/** How much a growth reading is worth believing, 0–1, from its own counts. */
export function growthEvidence(
  current: number,
  previous: number,
  evidenceHalf = GROWTH_EVIDENCE_HALF,
): number {
  const cur = Math.max(0, Number.isFinite(current) ? current : 0);
  const prev = Math.max(0, Number.isFinite(previous) ? previous : 0);
  return saturate(cur + prev, evidenceHalf);
}

/**
 * A rate shrunk toward a prior, then normalised against a ceiling.
 *
 * `(successes + prior·strength) / (trials + strength)` is the posterior mean of
 * a Beta-Binomial — the standard, and the honest, answer to "this product
 * converted one of its four views".
 */
export function shrunkRate(
  successes: number,
  trials: number,
  prior: number,
  strength: number,
): number {
  const s = Math.max(0, Number.isFinite(successes) ? successes : 0);
  const n = Math.max(0, Number.isFinite(trials) ? trials : 0);
  const denominator = n + strength;
  if (denominator <= 0) return prior;
  return clamp((s + prior * strength) / denominator);
}

/**
 * The conversion component: the funnel, in one number.
 *
 * Both halves are scored, then combined 40/60 in favour of cart→order. The
 * back half is weighted higher because it is the half a seller controls —
 * price, stock, shipping promise — while view→cart is largely the photograph.
 *
 * The evidence factor at the end is not decoration. Shrinking toward the prior
 * means a product with *no* traffic scores the prior, and the prior is not
 * zero — so without this, every dead row in the catalogue would collect a few
 * points for a funnel it never had, and an empty platform would show a floor
 * of five rather than a floor of nought. Evidence-gating is the same rule the
 * growth components follow, for the same reason: no data, no points.
 */
export function conversionComponent(input: {
  views: number;
  cartAdds: number;
  orders: number;
}): number {
  const evidence = saturate(
    Math.max(0, input.views) * EXPOSURE_WEIGHTS.views +
      Math.max(0, input.cartAdds) * EXPOSURE_WEIGHTS.cartAdds +
      Math.max(0, input.orders) * EXPOSURE_WEIGHTS.orders,
    CONVERSION_EVIDENCE_HALF,
  );
  if (evidence === 0) return 0;

  const viewToCart = shrunkRate(
    input.cartAdds,
    input.views,
    CONVERSION_PRIOR.viewToCart,
    CONVERSION_PRIOR.strength,
  );
  const cartToOrder = shrunkRate(
    input.orders,
    input.cartAdds,
    CONVERSION_PRIOR.cartToOrder,
    CONVERSION_PRIOR.strength,
  );
  const front = clamp(viewToCart / CONVERSION_CEILING.viewToCart);
  const back = clamp(cartToOrder / CONVERSION_CEILING.cartToOrder);
  return clamp(evidence * (front * 0.4 + back * 0.6));
}

/**
 * Wilson score lower bound for a proportion.
 *
 * The reason ratings are not averaged: a single five-star review averages to
 * 5.0 and would outrank a product with four hundred reviews at 4.7. The Wilson
 * lower bound asks "what is the worst this could plausibly be", which is the
 * question a ranking should be asking.
 */
export function wilsonLowerBound(
  positives: number,
  total: number,
  z = WILSON_Z,
): number {
  const n = Math.max(0, Number.isFinite(total) ? total : 0);
  if (n <= 0) return 0;
  const p = clamp(Math.max(0, positives) / n);
  const z2 = z * z;
  const denominator = 1 + z2 / n;
  const centre = p + z2 / (2 * n);
  const margin = z * Math.sqrt((p * (1 - p) + z2 / (4 * n)) / n);
  return clamp((centre - margin) / denominator);
}

/**
 * The quality component from a star total.
 *
 * Stars are mapped to a proportion by `(avg − 1) / 4`, so one star is 0 and
 * five is 1 — a one-star review is not 20% positive, it is a complaint.
 */
export function qualityComponent(ratingSum: number, reviews: number): number {
  const n = Math.max(0, Math.floor(reviews));
  if (n <= 0) return 0;
  const average = clamp(ratingSum / n, 0, 5);
  const positives = (clamp(average, 1, 5) - 1) / 4;
  return wilsonLowerBound(positives * n, n);
}

/**
 * Acceleration: is the growth itself growing?
 *
 * The window is cut into three equal thirds and the log-growth of the second
 * transition is compared against the first. This is what separates a product
 * that doubled last week and has been flat since from one that is still
 * pulling away — and it is the term that lets `EMERGING` be detected before
 * the sales that would put a product on a best-seller list.
 */
export function accelerationComponent(daily: readonly number[]): number {
  if (daily.length < 6) return 0;
  const size = Math.floor(daily.length / 3);
  const early = sum(daily.slice(0, size));
  const middle = sum(daily.slice(size, size * 2));
  const late = sum(daily.slice(daily.length - size));

  const evidence = saturate(early + middle + late, GROWTH_EVIDENCE_HALF);
  if (evidence === 0) return 0;

  const first = logGrowth(middle, early);
  const second = logGrowth(late, middle);
  const shaped = 0.5 + 0.5 * Math.tanh((second - first) / GROWTH_SCALE);
  return clamp(evidence * shaped);
}

/**
 * Exposure — the evidence behind a score, in comparable units.
 *
 * A purchase is worth eight views because it is eight times as informative
 * about demand, not because it is eight times as common.
 */
export function exposure(input: {
  views: number;
  cartAdds: number;
  orders: number;
}): number {
  return Math.round(
    Math.max(0, input.views) * EXPOSURE_WEIGHTS.views +
      Math.max(0, input.cartAdds) * EXPOSURE_WEIGHTS.cartAdds +
      Math.max(0, input.orders) * EXPOSURE_WEIGHTS.orders,
  );
}

/** 0–1 confidence from exposure. Half-strength at `CONFIDENCE_HALF_EXPOSURE`. */
export function confidenceFromExposure(exposureUnits: number): number {
  return saturate(exposureUnits, CONFIDENCE_HALF_EXPOSURE);
}

/**
 * Least-squares slope of a series against its index, normalised by its own
 * mean so the answer is a fractional change per day rather than an absolute
 * one — comparable between a product selling two a day and one selling two
 * hundred.
 */
export function normalisedSlope(values: readonly number[]): number {
  const n = values.length;
  if (n < 2) return 0;
  const xMean = (n - 1) / 2;
  const yMean = mean(values);
  let numerator = 0;
  let denominator = 0;
  for (let i = 0; i < n; i += 1) {
    numerator += (i - xMean) * ((values[i] ?? 0) - yMean);
    denominator += (i - xMean) ** 2;
  }
  if (denominator === 0) return 0;
  const slope = numerator / denominator;
  const scale = Math.max(Math.abs(yMean), 1e-6);
  const normalised = slope / scale;
  return Number.isFinite(normalised) ? normalised : 0;
}

/**
 * Centred simple moving average. Returns a series of the same length, with the
 * edges averaged over whatever window is available, so it can be charted
 * directly instead of being padded by the caller.
 */
export function movingAverage(
  values: readonly number[],
  window: number,
): number[] {
  const size = Math.max(1, Math.floor(window));
  const half = Math.floor(size / 2);
  return values.map((_, index) => {
    const start = Math.max(0, index - half);
    const end = Math.min(values.length, index + half + 1);
    return mean(values.slice(start, end));
  });
}

/** Round to a fixed number of decimals, for stable JSON and stable diffs. */
export function round(value: number, decimals = 4): number {
  if (!Number.isFinite(value)) return 0;
  const factor = 10 ** decimals;
  return Math.round(value * factor) / factor;
}

/**
 * Split a daily series into "this window" and "the window before it".
 *
 * The series is expected oldest-first and to cover `2 × window` days; short
 * series are handled by taking whatever the front holds, which makes the first
 * fortnight of a new platform score low rather than crash.
 */
export function splitWindows<T>(
  series: readonly T[],
  window: number,
): { current: T[]; previous: T[] } {
  const size = Math.max(1, Math.floor(window));
  const current = series.slice(-size);
  const previous = series.slice(Math.max(0, series.length - size * 2), -size);
  return { current, previous };
}
