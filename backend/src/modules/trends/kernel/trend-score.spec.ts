import assert from 'node:assert/strict';
import test from 'node:test';
import { TrendStage } from '@prisma/client';
import {
  SCORE_COMPONENT_KEYS,
  SCORE_WEIGHTS,
  VELOCITY_HALF_UNITS_PER_DAY,
} from '../trend.constants';
import {
  conversionComponent,
  growthComponent,
  logGrowth,
  qualityComponent,
  quantile,
  saturate,
  splitWindows,
  wilsonLowerBound,
} from './trend-math';
import {
  DemandDay,
  emptyDemandDay,
  rankingScore,
  scoreTrend,
  windowDays,
  windowEnum,
} from './trend-score';

// ── The invariant the whole scale rests on ─────────────────────────────

test('the component weights sum to exactly one', () => {
  // If they drift, every score on the platform silently rescales and no two
  // weeks are comparable. Worth an assertion of its own.
  const total = SCORE_COMPONENT_KEYS.reduce(
    (sum, key) => sum + SCORE_WEIGHTS[key],
    0,
  );
  assert.ok(Math.abs(total - 1) < 1e-9, `weights sum to ${total}`);
});

// ── The math primitives ────────────────────────────────────────────────

test('growth is smoothed, so a two-event product cannot post an infinite rate', () => {
  // 0 → 2 is an infinite ratio unsmoothed. Smoothed it is ln(5/3), a nudge.
  assert.ok(logGrowth(2, 0) < Math.log(2));
  assert.ok(Number.isFinite(logGrowth(50, 0)));
});

test('a growth component with no traffic behind it scores zero, not the flat 0.5', () => {
  // The bug this guards: a dead catalogue where every product sits at the
  // midpoint of three components and the whole scale compresses upward.
  assert.equal(growthComponent(0, 0), 0);
  assert.ok(growthComponent(2, 2) < 0.2, 'two events is barely evidence');
  assert.ok(growthComponent(200, 200) > 0.45, 'flat but real sits near 0.5');
  assert.ok(growthComponent(200, 200) < 0.55);
});

test('growth is monotone in the ratio and bounded', () => {
  const collapse = growthComponent(10, 200);
  const flat = growthComponent(100, 100);
  const surge = growthComponent(300, 100);
  assert.ok(collapse < flat, 'a collapse scores below flat');
  assert.ok(flat < surge, 'a tripling scores above flat');
  assert.ok(surge <= 1 && collapse >= 0);
});

test('saturate has no ceiling to sit flat against', () => {
  assert.equal(saturate(1.5, 1.5), 0.5);
  assert.ok(saturate(3, 1.5) > saturate(1.5, 1.5));
  assert.ok(saturate(30, 1.5) > saturate(3, 1.5));
  assert.ok(saturate(3000, 1.5) < 1);
  assert.equal(saturate(0, 1.5), 0);
});

test('conversion is shrunk toward the platform prior', () => {
  // One order from four views is 25%, and means nothing.
  const noisy = conversionComponent({ views: 4, cartAdds: 1, orders: 1 });
  const solid = conversionComponent({ views: 400, cartAdds: 100, orders: 60 });
  assert.ok(noisy < solid, 'four views cannot outrank four hundred');
  assert.ok(noisy < 0.45, 'a tiny sample stays near the prior');
});

test('one five-star review does not outrank four hundred at 4.7', () => {
  const lucky = qualityComponent(5, 1);
  const proven = qualityComponent(Math.round(4.7 * 400), 400);
  assert.ok(proven > lucky);
});

test('the Wilson bound is below the naive proportion and rises with n', () => {
  assert.ok(wilsonLowerBound(9, 10) < 0.9);
  assert.ok(wilsonLowerBound(900, 1000) > wilsonLowerBound(9, 10));
  assert.equal(wilsonLowerBound(0, 0), 0);
});

test('quantile interpolates and survives an empty series', () => {
  assert.equal(quantile([1, 2, 3, 4], 0.5), 2.5);
  assert.equal(quantile([], 0.5), 0);
  assert.equal(quantile([7], 0.9), 7);
});

test('splitWindows takes the tail as current and the tail before it as previous', () => {
  const series = [1, 2, 3, 4, 5, 6];
  assert.deepEqual(splitWindows(series, 2), { current: [5, 6], previous: [3, 4] });
  // A short series is scored on what exists rather than throwing.
  assert.deepEqual(splitWindows([1, 2], 3), { current: [1, 2], previous: [] });
});

// ── Building series for the scorer ─────────────────────────────────────

function series(
  length: number,
  shape: (index: number) => Partial<DemandDay>,
): DemandDay[] {
  return Array.from({ length }, (_, index) => {
    const day = new Date(Date.UTC(2026, 0, 1 + index)).toISOString().slice(0, 10);
    return { ...emptyDemandDay(day), inStock: true, stockUnits: 40, ...shape(index) };
  });
}

// ── The scorer ─────────────────────────────────────────────────────────

test('an empty history scores zero and is DORMANT', () => {
  const result = scoreTrend(series(14, () => ({ inStock: false, stockUnits: 0 })), 7);
  assert.equal(result.score, 0);
  assert.equal(result.stage, TrendStage.DORMANT);
  assert.equal(result.confidence, 0);
  assert.equal(result.sampleSize, 0);
});

test('a score is always in range and never NaN, whatever the inputs', () => {
  const hostile = series(14, (i) => ({
    views: i % 3 === 0 ? 0 : 1000,
    cartAdds: -5,
    orders: Number.NaN as unknown as number,
    units: Number.POSITIVE_INFINITY as unknown as number,
    reviews: 0,
    ratingSum: 99,
  }));
  const result = scoreTrend(hostile, 7);
  assert.ok(Number.isFinite(result.score));
  assert.ok(result.score >= 0 && result.score <= 100);
  for (const key of SCORE_COMPONENT_KEYS) {
    const value = result.components[key];
    assert.ok(Number.isFinite(value), `${key} is ${value}`);
    assert.ok(value >= 0 && value <= 1, `${key} out of range: ${value}`);
  }
});

test('the score is not a best-seller list: a climbing product with no sales beats a flat one with sales', () => {
  // This is the requirement in one assertion. The climber has never sold a
  // single unit; the incumbent sells steadily and is going nowhere.
  const climber = scoreTrend(
    series(14, (i) => ({
      views: i < 7 ? 12 : 90 + (i - 7) * 30,
      cartAdds: i < 7 ? 1 : 4 + (i - 7) * 2,
      favorites: i < 7 ? 0 : 3,
      orders: 0,
      units: 0,
    })),
    7,
  );
  const incumbent = scoreTrend(
    series(14, () => ({ views: 60, cartAdds: 4, orders: 2, units: 2 })),
    7,
  );

  assert.ok(
    climber.score > incumbent.score,
    `climber ${climber.score} should beat incumbent ${incumbent.score}`,
  );
});

test('a low-volume accelerating product is classified EMERGING, before it is a best seller', () => {
  const result = scoreTrend(
    series(14, (i) => ({
      views: i < 7 ? 8 : 40 + (i - 7) * 35,
      searchHits: i < 7 ? 2 : 10 + (i - 7) * 8,
      cartAdds: i < 7 ? 1 : 3 + (i - 7) * 3,
      orders: i >= 12 ? 1 : 0,
      units: i >= 12 ? 1 : 0,
    })),
    7,
    // The cohort typically sells 20 a week; this product has sold 2.
    { medianUnits: 20, p75Units: 60 },
  );
  assert.equal(result.stage, TrendStage.EMERGING);
});

test('a high-volume flat product is PEAKING, not EMERGING', () => {
  const result = scoreTrend(
    series(14, () => ({ views: 400, searchHits: 60, cartAdds: 40, orders: 20, units: 25 })),
    7,
    { medianUnits: 20, p75Units: 60 },
  );
  assert.equal(result.stage, TrendStage.PEAKING);
});

test('a collapsing product is DECLINING', () => {
  const result = scoreTrend(
    series(14, (i) => ({
      views: i < 7 ? 300 : 25,
      searchHits: i < 7 ? 40 : 2,
      cartAdds: i < 7 ? 20 : 1,
      orders: i < 7 ? 8 : 0,
      units: i < 7 ? 9 : 0,
    })),
    7,
    { medianUnits: 20, p75Units: 60 },
  );
  assert.equal(result.stage, TrendStage.DECLINING);
});

test('a product with almost no traffic is DORMANT however steep its ratios', () => {
  const result = scoreTrend(
    series(14, (i) => ({ views: i === 13 ? 3 : 0, cartAdds: 0, orders: 0 })),
    7,
  );
  assert.equal(result.stage, TrendStage.DORMANT);
});

test('confidence rises with exposure, and a purchase counts for more than a glance', () => {
  const glances = scoreTrend(series(14, () => ({ views: 8 })), 7);
  const buys = scoreTrend(series(14, () => ({ views: 8, orders: 1, units: 1 })), 7);
  assert.ok(buys.confidence > glances.confidence);
  assert.ok(buys.sampleSize > glances.sampleSize);
});

test('being out of stock costs the availability component but does not hide the demand', () => {
  const shape = (i: number): Partial<DemandDay> => ({
    views: i < 7 ? 40 : 160,
    cartAdds: i < 7 ? 3 : 12,
  });
  const stocked = scoreTrend(series(14, shape), 7);
  const sold_out = scoreTrend(
    series(14, (i) => ({ ...shape(i), inStock: false, stockUnits: 0 })),
    7,
  );

  assert.ok(sold_out.score < stocked.score, 'out of stock is penalised');
  assert.equal(
    sold_out.components.viewGrowth,
    stocked.components.viewGrowth,
    'but the demand signal itself is untouched',
  );
});

test('velocity is half-scored at the configured units per day', () => {
  const result = scoreTrend(
    series(14, () => ({ units: VELOCITY_HALF_UNITS_PER_DAY, orders: 1, views: 10 })),
    7,
  );
  assert.ok(Math.abs(result.components.salesVelocity - 0.5) < 0.01);
});

test('metrics report the raw window figures the components came from', () => {
  const result = scoreTrend(
    series(14, (i) => ({
      views: i < 7 ? 10 : 20,
      cartAdds: i < 7 ? 1 : 2,
      orders: i < 7 ? 0 : 1,
      units: i < 7 ? 0 : 1,
      reviews: i === 13 ? 2 : 0,
      ratingSum: i === 13 ? 9 : 0,
    })),
    7,
  );
  assert.equal(result.metrics.views, 140);
  assert.equal(result.metrics.previousViews, 70);
  assert.equal(result.metrics.orders, 7);
  assert.equal(result.metrics.averageRating, 4.5);
  assert.equal(result.metrics.viewToOrderRate, 0.05);
});

test('the ranking score shrinks a thin sample without erasing it', () => {
  const thin = rankingScore(90, 0.05);
  const proven = rankingScore(70, 0.95);
  assert.ok(thin < proven, 'a proven 70 outranks a one-day 90');
  assert.ok(
    thin > rankingScore(30, 0.95),
    'but an excellent thin score still outranks a proven mediocre one',
  );
});

test('window enum and days round-trip', () => {
  assert.equal(windowDays(windowEnum(7)), 7);
  assert.equal(windowDays(windowEnum(14)), 14);
  assert.equal(windowDays(windowEnum(30)), 30);
});

// ── Growth blending ─────────────────────────────────────────────────────

test('a platform with no view tracking is not told its whole catalogue is declining', () => {
  // The first night the engine runs on a real shop, page views may not be
  // instrumented at all. Averaging three legitimately-zero growth terms put
  // every product that had ever sold into DECLINING — a wrong signal, not a
  // missing one. Sales answer instead when nothing upstream was measured.
  const growing = scoreTrend(
    series(14, (i) => ({
      views: 0,
      searchHits: 0,
      cartAdds: 0,
      orders: i < 7 ? 1 : 4,
      units: i < 7 ? 1 : 5,
    })),
    7,
    { medianUnits: 10, p75Units: 25 },
  );
  assert.notEqual(growing.stage, TrendStage.DECLINING, 'sales were climbing');
  const climbing: TrendStage[] = [
    TrendStage.RISING,
    TrendStage.EMERGING,
    TrendStage.PEAKING,
  ];
  assert.ok(
    climbing.includes(growing.stage),
    `expected a rising stage, got ${growing.stage}`,
  );
});

test('an uninstrumented product whose sales are falling is still DECLINING', () => {
  const falling = scoreTrend(
    series(14, (i) => ({
      views: 0,
      searchHits: 0,
      cartAdds: 0,
      orders: i < 7 ? 6 : 1,
      units: i < 7 ? 8 : 1,
    })),
    7,
    { medianUnits: 10, p75Units: 25 },
  );
  assert.equal(falling.stage, TrendStage.DECLINING);
});

test('a measured signal outranks the sales fallback', () => {
  // Views are collapsing while sales hold up. The instrumented signal is the
  // leading one and must win, or the engine reports the decline a week late.
  const result = scoreTrend(
    series(14, (i) => ({
      views: i < 7 ? 400 : 20,
      cartAdds: i < 7 ? 30 : 2,
      orders: 3,
      units: 3,
    })),
    7,
    { medianUnits: 10, p75Units: 25 },
  );
  assert.equal(result.stage, TrendStage.DECLINING);
});

test('a thin but growing signal does not drag a climbing product down', () => {
  // The bug the demo data caught: `searchGrowth` on ten hits against five is
  // a real doubling, but evidence-gated it is 0.4 — below neutral — and the
  // average of a strong view ramp with two thin terms fell under the rising
  // threshold. A product with a steep view curve was classified COOLING.
  const climbing = scoreTrend(
    series(14, (i) => ({
      views: i < 7 ? 30 : 130,
      searchHits: i < 7 ? 1 : 2,
      cartAdds: i < 7 ? 1 : 3,
    })),
    7,
    { medianUnits: 5, p75Units: 20 },
  );
  assert.notEqual(climbing.stage, TrendStage.COOLING);
  assert.notEqual(climbing.stage, TrendStage.DECLINING);
});

test('the blend is weighted by evidence, so the loudest measured signal wins', () => {
  // Views collapsed on hundreds of observations; searches ticked up on three.
  // The collapse is the real news.
  const collapsing = scoreTrend(
    series(14, (i) => ({
      views: i < 7 ? 300 : 20,
      searchHits: i < 7 ? 1 : 2,
      cartAdds: i < 7 ? 20 : 1,
    })),
    7,
    { medianUnits: 5, p75Units: 20 },
  );
  assert.equal(collapsing.stage, TrendStage.DECLINING);
});
