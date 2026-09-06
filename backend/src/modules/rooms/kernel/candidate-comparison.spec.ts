import assert from 'node:assert/strict';
import test from 'node:test';
import {
  CompareInput,
  buildComparison,
  orderComparison,
  verdictFor,
} from './candidate-comparison';

/**
 * The comparison kernel is pure, so it is tested with tables written by hand.
 * The property under test throughout is the one the feature exists for: a
 * comparison should surface *differences*, not repeat what is the same.
 */

const cell = (raw: number | string | null, display?: string) => ({
  raw,
  display: display ?? String(raw ?? '—'),
});

function input(
  key: string,
  values: Record<string, { raw: number | string | null; display: string }>,
  direction?: 'lower' | 'higher' | 'none',
): CompareInput {
  return { key, label: key, direction, values };
}

// ── What differs ────────────────────────────────────────────────────────

test('a row where everybody says the same thing is marked as not differing', () => {
  const [row] = buildComparison([
    input('seller', { a: cell('رهف'), b: cell('رهف'), c: cell('رهف') }),
  ]);
  assert.equal(row.differs, false);
});

test('a row where one differs is marked as differing', () => {
  const [row] = buildComparison([
    input('seller', { a: cell('رهف'), b: cell('رهف'), c: cell('سارة') }),
  ]);
  assert.equal(row.differs, true);
});

test('a missing value is a difference, not a blank', () => {
  const [row] = buildComparison([
    input('rating', { a: cell(4.5), b: cell(null, '—') }, 'higher'),
  ]);
  // One dress rated and one unrated is exactly the kind of difference somebody
  // deciding wants to see.
  assert.equal(row.differs, true);
});

test('a single candidate has nothing to differ from', () => {
  const [row] = buildComparison([input('price', { a: cell(100) }, 'lower')]);
  assert.equal(row.differs, false);
});

// ── Best ────────────────────────────────────────────────────────────────

test('cheapest wins on a lower-is-better row', () => {
  const [row] = buildComparison([
    input('price', { a: cell(300), b: cell(200), c: cell(400) }, 'lower'),
  ]);
  assert.equal(row.values.b.best, true);
  assert.ok(!row.values.a.best);
  assert.ok(!row.values.c.best);
});

test('highest wins on a higher-is-better row', () => {
  const [row] = buildComparison([
    input('rating', { a: cell(4.1), b: cell(4.8) }, 'higher'),
  ]);
  assert.equal(row.values.b.best, true);
});

test('a tie marks every winner rather than picking one', () => {
  const [row] = buildComparison([
    input('price', { a: cell(200), b: cell(200), c: cell(400) }, 'lower'),
  ]);
  assert.equal(row.values.a.best, true);
  assert.equal(row.values.b.best, true);
  assert.ok(!row.values.c.best);
});

test('a directionless row never crowns anybody', () => {
  const [row] = buildComparison([
    input('seller', { a: cell('رهف'), b: cell('سارة') }),
  ]);
  assert.ok(!row.values.a.best);
  assert.ok(!row.values.b.best);
});

test('an identical row crowns nobody even with a direction', () => {
  const [row] = buildComparison([
    input('price', { a: cell(200), b: cell(200) }, 'lower'),
  ]);
  assert.ok(!row.values.a.best, 'nothing to win when the prices are the same');
});

// ── Ordering ────────────────────────────────────────────────────────────

test('the most decisive difference comes first', () => {
  const rows = buildComparison([
    // A 2% price gap.
    input('price', { a: cell(100), b: cell(102) }, 'lower'),
    // A 60% delivery gap.
    input('delivery', { a: cell(2), b: cell(5) }, 'lower'),
  ]);

  const ordered = orderComparison(rows);
  assert.equal(ordered[0].key, 'delivery');
});

test('rows that do not differ sink to the bottom', () => {
  const rows = buildComparison([
    input('seller', { a: cell('رهف'), b: cell('رهف') }),
    input('price', { a: cell(100), b: cell(200) }, 'lower'),
  ]);

  const ordered = orderComparison(rows);
  assert.equal(ordered[0].key, 'price');
  assert.equal(ordered[1].key, 'seller');
  assert.equal(ordered[1].differs, false);
});

test('ordering is deterministic', () => {
  const rows = buildComparison([
    input('a', { x: cell('1'), y: cell('2') }),
    input('b', { x: cell('1'), y: cell('2') }),
  ]);
  assert.deepEqual(
    orderComparison(rows).map((row) => row.key),
    orderComparison([...rows].reverse()).map((row) => row.key),
  );
});

// ── The verdict ─────────────────────────────────────────────────────────

test('two identical candidates are reported as identical', () => {
  const rows = buildComparison([
    input('price', { a: cell(200), b: cell(200) }, 'lower'),
    input('seller', { a: cell('رهف'), b: cell('رهف') }),
  ]);
  assert.equal(verdictFor(rows, ['a', 'b']).code, 'IDENTICAL');
});

test('a candidate that wins every measurable row is named', () => {
  const rows = buildComparison([
    input('price', { a: cell(100), b: cell(300) }, 'lower'),
    input('delivery', { a: cell(2), b: cell(6) }, 'lower'),
    input('rating', { a: cell(4.9), b: cell(4.0) }, 'higher'),
  ]);

  const verdict = verdictFor(rows, ['a', 'b']);
  assert.equal(verdict.code, 'ONE_CHEAPEST_AND_BEST');
  assert.equal(verdict.candidateId, 'a');
});

test('a genuine trade-off is reported as one, and names nobody', () => {
  const rows = buildComparison([
    // Cheaper but slower.
    input('price', { a: cell(100), b: cell(300) }, 'lower'),
    input('delivery', { a: cell(9), b: cell(2) }, 'lower'),
  ]);

  const verdict = verdictFor(rows, ['a', 'b']);
  // The cheapest is still worth naming, but nothing claims it is the answer.
  assert.equal(verdict.code, 'CHEAPEST_DIFFERS');
  assert.equal(verdict.candidateId, 'a');
});

test('differences with no direction are a trade-off, not a winner', () => {
  const rows = buildComparison([
    input('seller', { a: cell('رهف'), b: cell('سارة') }),
    input('colour', { a: cell('كحلي'), b: cell('أسود') }),
  ]);

  const verdict = verdictFor(rows, ['a', 'b']);
  assert.equal(verdict.code, 'TRADE_OFF');
  assert.equal(verdict.candidateId, null);
});
