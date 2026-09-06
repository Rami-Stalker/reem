import assert from 'node:assert/strict';
import test from 'node:test';
import { GraphEdge } from '@prisma/client';

import {
  AffinityFacts,
  complementScore,
  exclusiveSlots,
  decay,
  edgeWeight,
  priceCloseness,
  repetition,
  similarityScore,
  substituteScore,
} from './graph-math';
import {
  SUBSTITUTE_MAX_RATING_DROP,
  SUBSTITUTE_MAX_SAVING_BPS,
  SUBSTITUTE_MIN_SAVING_BPS,
  SUBSTITUTE_MIN_SIMILARITY,
} from '../graph.constants';

const opts = {
  minSavingBps: SUBSTITUTE_MIN_SAVING_BPS,
  maxSavingBps: SUBSTITUTE_MAX_SAVING_BPS,
  minSimilarity: SUBSTITUTE_MIN_SIMILARITY,
  maxRatingDrop: SUBSTITUTE_MAX_RATING_DROP,
};

const dress = (over: Partial<AffinityFacts> = {}): AffinityFacts => ({
  productId: 'p1',
  categoryId: 'c-dresses',
  colours: ['navy'],
  materials: ['crepe'],
  slot: 'DRESS',
  occasions: ['wedding'],
  priceSyp: 120_000,
  rating: 4.5,
  reviewsCount: 12,
  ...over,
});

// ── Decay ────────────────────────────────────────────────────────────────

test('a behaviour halves over its half-life', () => {
  assert.equal(decay(0, 30), 1);
  assert.equal(decay(30, 30), 0.5);
  assert.equal(decay(60, 30), 0.25);
});

test('repetition helps, but nowhere near linearly', () => {
  assert.equal(repetition(1), 1);
  assert.ok(repetition(9) > repetition(2));
  assert.ok(
    repetition(9) < 3,
    'nine views must not be worth nine times one — that is indecision, not devotion',
  );
});

test('owning outlives looking', () => {
  const age = 120;
  const owned = edgeWeight({ kind: GraphEdge.OWNS, observations: 1, ageDays: age });
  const viewed = edgeWeight({ kind: GraphEdge.VIEWED, observations: 1, ageDays: age });

  assert.ok(owned > viewed * 10, `${owned} vs ${viewed}`);
  assert.ok(viewed < 1, 'a four-month-old glance is worth almost nothing');
});

test('a fresh view still counts for something', () => {
  const fresh = edgeWeight({ kind: GraphEdge.VIEWED, observations: 1, ageDays: 0 });
  assert.ok(fresh > 0 && fresh <= 100);
});

// ── Similarity ───────────────────────────────────────────────────────────

test('a different category is never similar', () => {
  assert.equal(
    similarityScore(dress(), dress({ productId: 'p2', categoryId: 'c-candles' })),
    0,
    'a dress and a candle are not alternatives however much they share',
  );
});

test('a product is not similar to itself', () => {
  assert.equal(similarityScore(dress(), dress()), 0);
});

test('the closer two pieces are, the higher the score', () => {
  const twin = dress({ productId: 'p2' });
  const cousin = dress({
    productId: 'p3',
    colours: ['red'],
    materials: ['satin'],
    occasions: ['daily'],
  });

  assert.ok(similarityScore(dress(), twin) > similarityScore(dress(), cousin));
});

test('price distance pulls similarity down', () => {
  const near = dress({ productId: 'p2', priceSyp: 130_000 });
  const far = dress({ productId: 'p3', priceSyp: 600_000 });

  assert.ok(similarityScore(dress(), near) > similarityScore(dress(), far));
  assert.equal(priceCloseness(120_000, 480_000), 0, 'fourfold is not comparable');
  assert.equal(priceCloseness(100_000, 100_000), 1);
  assert.equal(priceCloseness(null, 100_000), 0);
});

// ── Complements ──────────────────────────────────────────────────────────

test('two things in the same slot never complement each other', () => {
  const otherDress = dress({ productId: 'p2', colours: ['black'] });
  assert.equal(
    complementScore(dress(), otherDress, 5),
    0,
    'a second dress does not complete an outfit',
  );
});

test('garments worn instead of each other never complement', () => {
  // The bug live data caught: the graph offered an evening abaya as a
  // complement to an evening dress. Nobody wears both.
  const abaya = dress({ productId: 'p2', categoryId: 'c-dresses', slot: 'ABAYA' });
  assert.equal(complementScore(dress(), abaya, 3), 0);

  // Reem Closet counts outfits as (dresses + abayas + min(tops, bottoms)),
  // so a base garment also stands in for a top-and-bottom pair.
  assert.ok(exclusiveSlots('DRESS', 'ABAYA'));
  assert.ok(exclusiveSlots('ABAYA', 'TOP'));
  assert.ok(exclusiveSlots('DRESS', 'BOTTOM'));

  // And the one pair that genuinely needs each other still does.
  assert.ok(!exclusiveSlots('TOP', 'BOTTOM'));
  assert.ok(!exclusiveSlots('DRESS', 'SHOES'));
  assert.ok(!exclusiveSlots('DRESS', null));
});

test('a top and a bottom do complement each other', () => {
  const top = dress({ productId: 'p2', categoryId: 'c-tops', slot: 'TOP' });
  const bottom = dress({ productId: 'p3', categoryId: 'c-skirts', slot: 'BOTTOM' });
  assert.ok(complementScore(top, bottom, 0) > 0);
});

test('different slots for the same occasion complement', () => {
  const bag = dress({
    productId: 'p2',
    categoryId: 'c-bags',
    slot: 'BAG',
    colours: ['black'],
  });
  assert.ok(complementScore(dress(), bag, 0) > 30);
});

test('being actually bought together outweighs every inference', () => {
  const bag = dress({
    productId: 'p2',
    categoryId: 'c-bags',
    slot: 'BAG',
    colours: ['gold'],
    occasions: ['daily'],
  });

  const inferred = complementScore(dress(), bag, 0);
  const observed = complementScore(dress(), bag, 4);
  assert.ok(observed > inferred + 20, `${observed} vs ${inferred}`);
});

test('co-occurrence saturates', () => {
  const bag = dress({ productId: 'p2', categoryId: 'c-bags', slot: 'BAG' });
  const twice = complementScore(dress(), bag, 2);
  const twenty = complementScore(dress(), bag, 20);
  assert.ok(twenty - twice < 20, 'twenty times is not ten times the signal');
});

// ── Substitutes ──────────────────────────────────────────────────────────

test('a dearer product is never a better-value substitute', () => {
  const dearer = dress({ productId: 'p2', priceSyp: 200_000 });
  assert.equal(substituteScore(dress(), dearer, opts), null);
});

test('a trivial saving is not worth unsettling a decision', () => {
  const barely = dress({ productId: 'p2', priceSyp: 117_000 }); // 2.5%
  assert.equal(substituteScore(dress(), barely, opts), null);
});

test('a real saving on a real equivalent is offered', () => {
  const cheaper = dress({ productId: 'p2', priceSyp: 90_000 });
  const result = substituteScore(dress(), cheaper, opts);

  assert.ok(result);
  assert.equal(result.savingBps, 2500);
  assert.ok(result.score > 40);
});

test('a saving too large to be believed is refused', () => {
  // Live data: a knit sweater offered as a cheaper cashmere cardigan at 72%
  // less, and a ring as a cheaper pearl earring. A gap that big is evidence
  // the two are different products, not evidence of value.
  const bargain = dress({ productId: 'p2', priceSyp: 30_000 }); // 75% less
  assert.equal(substituteScore(dress(), bargain, opts), null);

  // Just inside the ceiling still works.
  const steep = dress({ productId: 'p3', priceSyp: 50_000 }); // 58% less
  assert.ok(substituteScore(dress(), steep, opts));
});

test('sharing only a category and a slot is not enough to substitute', () => {
  // The earring-for-a-ring case: `similarityScore` gives 40 for the category
  // and 15 for the slot, so a floor of 55 let two products that agree on
  // nothing else through.
  const unrelated = dress({
    productId: 'p2',
    priceSyp: 90_000,
    colours: ['orange'],
    materials: ['plastic'],
    occasions: ['home'],
  });
  assert.ok(
    similarityScore(dress(), unrelated) < SUBSTITUTE_MIN_SIMILARITY,
    'category and slot alone must not clear the bar',
  );
  assert.equal(substituteScore(dress(), unrelated, opts), null);
});

test('"better value" may not mean "worse, but less"', () => {
  const cheapAndBad = dress({ productId: 'p2', priceSyp: 80_000, rating: 3.1 });
  assert.equal(
    substituteScore(dress(), cheapAndBad, opts),
    null,
    'a rating this much lower is a different product, not a saving',
  );
});

test('an unrated bargain is not offered against a well-rated piece', () => {
  const unrated = dress({ productId: 'p2', priceSyp: 80_000, rating: 0, reviewsCount: 0 });
  assert.equal(substituteScore(dress(), unrated, opts), null);
});

test('but two unrated products may substitute for each other', () => {
  const base = dress({ rating: 0, reviewsCount: 0 });
  const cheaper = dress({ productId: 'p2', priceSyp: 80_000, rating: 0, reviewsCount: 0 });
  assert.ok(substituteScore(base, cheaper, opts));
});

test('a loosely comparable bargain is not a substitute', () => {
  const different = dress({
    productId: 'p2',
    priceSyp: 60_000,
    colours: ['orange'],
    materials: ['jersey'],
    occasions: ['home'],
    slot: 'TOP',
  });
  assert.equal(substituteScore(dress(), different, opts), null);
});
