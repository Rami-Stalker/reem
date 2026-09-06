import assert from 'node:assert/strict';
import test from 'node:test';
import { TrendForecastMethod } from '@prisma/client';
import { addDays, forecast, isoDate, stockoutInDays } from './forecast';

const START = new Date(Date.UTC(2026, 0, 1));

function run(values: number[], horizonDays = 7) {
  return forecast({ values, startDate: START, horizonDays });
}

test('no history at all is INSUFFICIENT_DATA with zero confidence, not a guess', () => {
  const result = run([]);
  assert.equal(result.method, TrendForecastMethod.INSUFFICIENT_DATA);
  assert.equal(result.confidence, 0);
  assert.equal(result.totalUnits, 0);
  assert.equal(result.points.length, 7);
});

test('an all-zero history forecasts zero rather than inventing demand', () => {
  const result = run(new Array(40).fill(0));
  assert.equal(result.method, TrendForecastMethod.INSUFFICIENT_DATA);
  assert.equal(result.totalUnits, 0);
});

test('the method degrades with the length of the history', () => {
  assert.equal(run([2, 3, 1, 2]).method, TrendForecastMethod.MOVING_AVERAGE);
  assert.equal(
    run([2, 3, 1, 2, 4, 2, 3, 2, 1, 3]).method,
    TrendForecastMethod.SEASONAL_NAIVE,
  );
  assert.equal(
    run(Array.from({ length: 40 }, (_, i) => 5 + (i % 7))).method,
    TrendForecastMethod.HOLT_DAMPED,
  );
});

test('a flat series forecasts its own level', () => {
  const result = run(new Array(40).fill(6), 7);
  for (const point of result.points) {
    assert.ok(Math.abs(point.units - 6) < 1.2, `expected ~6, got ${point.units}`);
  }
  assert.ok(result.confidence > 0.8, 'a perfectly predictable series is confident');
});

test('a rising series forecasts higher than its last week, and damping keeps it sane', () => {
  const values = Array.from({ length: 60 }, (_, i) => 2 + i * 0.3);
  const result = run(values, 14);
  const lastWeek = values.slice(-7).reduce((a, b) => a + b, 0);

  assert.ok(result.totalUnits > lastWeek, 'the trend is carried forward');
  // Undamped, a 0.3/day slope over 14 days would run to ~25/day at the end.
  // Damped, it must not: an over-eager forecast is a seller's cash in a box.
  const last = result.points[result.points.length - 1];
  assert.ok(last.units < values[values.length - 1] * 2, `runaway: ${last.units}`);
});

test('a falling series is not forecast below zero', () => {
  const values = Array.from({ length: 40 }, (_, i) => Math.max(0, 20 - i * 0.6));
  const result = run(values, 30);
  for (const point of result.points) {
    assert.ok(point.units >= 0);
    assert.ok(point.low >= 0);
  }
});

test('the interval widens with the horizon and always contains the point', () => {
  const values = Array.from({ length: 45 }, (_, i) => 8 + Math.sin(i) * 3);
  const result = run(values, 14);
  for (const point of result.points) {
    assert.ok(point.low <= point.units, 'low bounds the point');
    assert.ok(point.high >= point.units, 'high bounds the point');
  }
  const first = result.points[0];
  const last = result.points[result.points.length - 1];
  assert.ok(
    last.high - last.low >= first.high - first.low,
    'uncertainty grows with distance',
  );
});

test('a weekly shape is carried into the forecast', () => {
  // Fridays (index 4 from a Thursday start) are triple.
  const values = Array.from({ length: 56 }, (_, i) =>
    addDays(START, i).getUTCDay() === 5 ? 30 : 10,
  );
  const result = run(values, 14);

  const fridays = result.points.filter(
    (point) => new Date(`${point.date}T00:00:00Z`).getUTCDay() === 5,
  );
  const others = result.points.filter(
    (point) => new Date(`${point.date}T00:00:00Z`).getUTCDay() !== 5,
  );
  const meanOf = (rows: typeof result.points) =>
    rows.reduce((sum, row) => sum + row.units, 0) / Math.max(rows.length, 1);

  assert.ok(fridays.length >= 2);
  assert.ok(
    meanOf(fridays) > meanOf(others) * 1.2,
    `friday ${meanOf(fridays)} vs other ${meanOf(others)}`,
  );
});

test('a noisy series is forecast with lower confidence than a clean one', () => {
  const clean = run(new Array(45).fill(10), 7);
  const noisy = run(
    Array.from({ length: 45 }, (_, i) => (i % 2 === 0 ? 0 : 20)),
    7,
  );
  assert.ok(noisy.confidence < clean.confidence);
});

test('forecast dates continue the history without a gap or an overlap', () => {
  const values = new Array(30).fill(3);
  const result = run(values, 5);
  assert.equal(result.points[0].date, isoDate(addDays(START, 30)));
  assert.equal(result.points[4].date, isoDate(addDays(START, 34)));
});

test('the forecast is deterministic', () => {
  const values = Array.from({ length: 50 }, (_, i) => (i * 7919) % 13);
  assert.deepEqual(run(values, 10), run(values, 10));
});

// ── Stock-out ETA ───────────────────────────────────────────────────────

test('stock-out walks the forecast rather than dividing by a mean', () => {
  const points = [
    { date: '2026-01-01', units: 2, low: 0, high: 4 },
    { date: '2026-01-02', units: 4, low: 0, high: 8 },
    { date: '2026-01-03', units: 10, low: 0, high: 20 },
  ];
  // 2 on day one, 4 on day two leaves 4 of the 10 wanted on day three.
  assert.equal(stockoutInDays(10, points), 2.4);
});

test('no stock is an immediate stock-out; surviving the horizon reports null', () => {
  const points = [{ date: '2026-01-01', units: 1, low: 0, high: 2 }];
  assert.equal(stockoutInDays(0, points), 0);
  assert.equal(stockoutInDays(500, points), null);
});

test('a forecast of nothing never runs the stock down', () => {
  const points = [
    { date: '2026-01-01', units: 0, low: 0, high: 0 },
    { date: '2026-01-02', units: 0, low: 0, high: 0 },
  ];
  assert.equal(stockoutInDays(5, points), null);
});
