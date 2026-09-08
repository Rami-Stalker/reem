import assert from 'node:assert/strict';
import test from 'node:test';

import { DiagnosisFacts, Period, diagnose } from './diagnosis';

/**
 * "It was selling and now it is not — what changed?"
 *
 * The value of this engine is entirely in naming *one* cause. Six possible
 * reasons on a screen is not a diagnosis, and the wrong one costs a seller a
 * week: telling her to improve her photographs when a competitor undercut her
 * by a third is worse than telling her nothing.
 */

const period = (over: Partial<Period> = {}): Period => ({
  views: 400,
  orders: 20,
  price: 100_000,
  liveOffers: 1,
  stock: 10,
  bestMarketPrice: 100_000,
  reviews: 20,
  rating: 4.5,
  days: 30,
  ...over,
});

const facts = (over: Partial<DiagnosisFacts> = {}): DiagnosisFacts => ({
  recent: period(),
  previous: period(),
  outOfStockNow: false,
  categoryOrdersChangePercent: null,
  ...over,
});

test('a listing that is not declining is told so plainly', () => {
  assert.equal(diagnose(facts()).code, 'not_declining');
});

test('too little traffic produces an honest refusal, not a guess', () => {
  const reading = diagnose(
    facts({
      recent: period({ views: 4, orders: 0 }),
      previous: period({ views: 6, orders: 1 }),
    }),
  );
  assert.equal(reading.code, 'insufficient_evidence');
  assert.ok(
    reading.actionAr.length > 0,
    'even a refusal should say what would make an answer possible',
  );
});

// ── The causes, each isolated ────────────────────────────────────────────────

test('an empty shelf is diagnosed before anything else', () => {
  // Deliberately also undercut and losing views: neither matters for the days
  // there was nothing to sell.
  const reading = diagnose(
    facts({
      recent: period({
        orders: 4,
        views: 150,
        price: 130_000,
        bestMarketPrice: 90_000,
        liveOffers: 3,
      }),
      previous: period({ orders: 20, views: 400 }),
      outOfStockNow: true,
    }),
  );
  assert.equal(reading.code, 'out_of_stock');
  assert.ok(reading.ar.includes('نفد'));
});

test('being undercut is named, rather than blamed on the photographs', () => {
  const reading = diagnose(
    facts({
      recent: period({
        orders: 5,
        price: 130_000,
        bestMarketPrice: 85_000,
        liveOffers: 4,
      }),
      previous: period({ orders: 20 }),
    }),
  );
  assert.equal(reading.code, 'undercut');
  assert.ok(
    reading.actionAr.includes('السعر'),
    'the remedy has to match the cause, or it costs her a week',
  );
});

test('a sole seller is never told she was undercut', () => {
  // One live offer: there is nobody to be undercut by, whatever the price.
  const reading = diagnose(
    facts({
      recent: period({
        orders: 5,
        price: 130_000,
        bestMarketPrice: 85_000,
        liveOffers: 1,
      }),
      previous: period({ orders: 20 }),
    }),
  );
  assert.notEqual(reading.code, 'undercut');
});

test('fewer viewers with the same conversion is a visibility problem', () => {
  const reading = diagnose(
    facts({
      // Half the views, same proportion buying.
      recent: period({ views: 180, orders: 9 }),
      previous: period({ views: 400, orders: 20 }),
    }),
  );
  assert.equal(reading.code, 'lost_visibility');
  assert.ok(
    reading.ar.includes('المشاهدات'),
    'the listing still convinces whoever sees it — that is the useful half',
  );
});

test('the same viewers buying less is a listing problem', () => {
  const reading = diagnose(
    facts({
      recent: period({ views: 400, orders: 6 }),
      previous: period({ views: 400, orders: 20 }),
    }),
  );
  assert.equal(reading.code, 'conversion_fell');
});

test('a fallen rating is named as the cause when it is one', () => {
  const reading = diagnose(
    facts({
      recent: period({ views: 400, orders: 6, rating: 2.9, reviews: 14 }),
      previous: period({ views: 400, orders: 20, rating: 4.6 }),
    }),
  );
  assert.equal(reading.code, 'rating_damage');
  assert.ok(reading.actionAr.includes('المراجعات'));
});

test('a whole category cooling is not the seller’s fault, and is said so', () => {
  const reading = diagnose(
    facts({
      // Orders down, but views and conversion both roughly held.
      recent: period({ views: 300, orders: 14 }),
      previous: period({ views: 320, orders: 20 }),
      categoryOrdersChangePercent: -0.45,
    }),
  );
  assert.equal(reading.code, 'category_cooled');
  assert.ok(
    reading.actionAr.includes('لا تخفّضي'),
    'the wrong advice here costs her margin for nothing',
  );
});

// ── Discipline ───────────────────────────────────────────────────────────────

test('exactly one cause is named, with the rest as context', () => {
  const reading = diagnose(
    facts({
      recent: period({ views: 150, orders: 5 }),
      previous: period({ views: 400, orders: 20 }),
      categoryOrdersChangePercent: -0.4,
    }),
  );

  assert.equal(reading.code, 'lost_visibility');
  assert.ok(
    reading.alsoAr.length > 0,
    'the seasonal move is real context and belongs beside the cause',
  );
  assert.ok(
    reading.alsoAr[0].includes('موسمي'),
    'but it is context, not a second diagnosis',
  );
});

test('every diagnosis carries the figures it rests on', () => {
  const reading = diagnose(
    facts({
      recent: period({ orders: 4 }),
      previous: period({ orders: 20 }),
    }),
  );
  assert.ok(Object.keys(reading.evidence).length >= 4);
  assert.equal(reading.evidence.orders_now, 4);
  assert.equal(reading.evidence.orders_before, 20);
});

test('a small wobble is not called a decline', () => {
  const reading = diagnose(
    facts({
      recent: period({ orders: 18 }),
      previous: period({ orders: 20 }),
    }),
  );
  assert.equal(
    reading.code,
    'not_declining',
    'a 10% move is noise, and diagnosing it teaches her to ignore the engine',
  );
});

test('windows of different lengths are compared per day', () => {
  // Same daily rate, different window lengths.
  const reading = diagnose(
    facts({
      recent: period({ orders: 10, views: 200, days: 15 }),
      previous: period({ orders: 20, views: 400, days: 30 }),
    }),
  );
  assert.equal(reading.code, 'not_declining');
});
