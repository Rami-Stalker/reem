import assert from 'node:assert/strict';
import test from 'node:test';

import {
  PeerCohort,
  ProductFacts,
  adviseProduct,
  conversionOf,
  scoreProductHealth,
  towards,
  versusMedian,
} from './product-health';
import {
  CONVERSION_MIN_VIEWS,
  IMAGE_TARGET,
  PEER_MIN_COHORT,
} from '../intelligence.constants';

/**
 * The product health kernel.
 *
 * The important cases are the ones where the honest answer is "I cannot tell
 * you": a listing nobody has seen, and a category with no cohort. Getting
 * those wrong is what turns a health score into a number that punishes
 * sellers for being new.
 */

const listing: ProductFacts = {
  productId: 'p1',
  title: 'فستان سهرة كحلي بأكمام منفوخة',
  description:
    'فستان سهرة من الكريب الثقيل بلون كحلي، بأكمام منفوخة وخصر مضبّب. الطول ميدي، مبطّن بالكامل، ومناسب للأعراس والمناسبات المسائية. متوفر بقياسات من S لـ XL.',
  imageCount: 5,
  imagesWithBlurHash: 5,
  attributeCount: 6,
  hasBrand: true,
  hasGtin: false,
  impressions: 900,
  views: 300,
  searchHits: 400,
  searchClicks: 60,
  cartAdds: 30,
  favorites: 25,
  orders: 12,
  units: 13,
  priceSyp: 90_000,
  inStock: true,
  stockUnits: 14,
  reviewCount: 6,
  averageRating: 4.5,
};

const cohort: PeerCohort = {
  size: 12,
  medianConversion: 0.04,
  medianViews: 260,
  medianAttributes: 6,
  medianPriceSyp: 88_000,
  medianImages: 4,
};

// ── Shapes ───────────────────────────────────────────────────────────────

test('a count against a target, with a floor for clearly-wrong', () => {
  assert.equal(towards(5, 5), 100);
  assert.equal(towards(10, 5), 100, 'past the target is not extra credit');
  assert.equal(towards(0, 5), 0);
  // Below the minimum the score is damped: two photographs is not 40% of a
  // good listing, it is a listing with a problem.
  assert.ok(towards(2, 5, 3) < towards(2, 5, 0));
});

test('versus a median: the median is solid, not perfect', () => {
  assert.equal(versusMedian(4, 4), 70, 'at the median is a good listing');
  assert.equal(versusMedian(0, 4), 0, 'and the axis can reach the bottom');
  assert.equal(versusMedian(8, 4), 100, 'twice the median is full marks');
  assert.equal(versusMedian(40, 4), 100, 'capped');
  // The case the floor used to hide: a twentieth of the category's rate has
  // to read as a failure, or the advice that depends on it never fires.
  assert.ok(versusMedian(0.002, 0.04) < 10);
});

test('conversion is orders over views, and zero views is zero', () => {
  assert.equal(conversionOf({ ...listing, views: 100, orders: 4 }), 0.04);
  assert.equal(conversionOf({ ...listing, views: 0, orders: 0 }), 0);
});

// ── Withholding judgement ────────────────────────────────────────────────

test('a listing nobody has seen is unmeasured, not bad', () => {
  const fresh: ProductFacts = {
    ...listing,
    impressions: 0,
    views: 0,
    searchHits: 0,
    searchClicks: 0,
    cartAdds: 0,
    favorites: 0,
    orders: 0,
    units: 0,
  };

  const result = scoreProductHealth(fresh, cohort);
  const discovery = result.axes.find((a) => a.key === 'discoverability');
  const conversion = result.axes.find((a) => a.key === 'conversion');

  assert.equal(discovery?.score, null, 'never shown is not badly discovered');
  assert.equal(conversion?.score, null, 'no views means no conversion rate');
  assert.equal(discovery?.weight, 0);
  assert.equal(conversion?.weight, 0);

  // It is still scored on the things that *are* true of it — a good listing
  // with no traffic should read as a good listing.
  assert.ok(result.score > 70, `content and images still count: ${result.score}`);
});

test('a cohort too small to speak withholds the comparison', () => {
  const tiny: PeerCohort = { ...cohort, size: PEER_MIN_COHORT - 1 };
  const result = scoreProductHealth(listing, tiny);

  assert.equal(result.peers, null, 'no honest comparison from three listings');
  const performance = result.axes.find((a) => a.key === 'performance');
  assert.equal(performance?.score, null);
});

test('conversion below the view floor is withheld', () => {
  const quiet = { ...listing, views: CONVERSION_MIN_VIEWS - 1, orders: 0 };
  const axis = scoreProductHealth(quiet, cohort).axes.find(
    (a) => a.key === 'conversion',
  );
  assert.equal(axis?.score, null);
  assert.equal(axis?.evidence, 'thin');
});

test('a category where nobody has viewed anything cannot judge performance', () => {
  // A quiet aisle is not a failing listing. Every product in a category with
  // no traffic used to score zero here, which reads as an accusation.
  const asleep: PeerCohort = { ...cohort, medianViews: 0, medianConversion: 0 };
  const unseen: ProductFacts = { ...listing, views: 0, orders: 0, cartAdds: 0, favorites: 0 };

  const axis = scoreProductHealth(unseen, asleep).axes.find(
    (a) => a.key === 'performance',
  );
  assert.equal(axis?.score, null);
  assert.equal(axis?.evidence, 'unmeasurable');
  assert.equal(axis?.weight, 0, 'and it must not drag the score down');
});

test('a listing with views in a quiet category is above its market', () => {
  const asleep: PeerCohort = { ...cohort, medianViews: 0 };
  const seen = { ...listing, views: 120 };
  const axis = scoreProductHealth(seen, asleep).axes.find(
    (a) => a.key === 'performance',
  );
  assert.ok((axis?.score ?? 0) > 0, 'having any attention at all counts');
});

test('a category where nothing converts falls back to an absolute yardstick', () => {
  const degenerate: PeerCohort = { ...cohort, medianConversion: 0 };
  const seen = { ...listing, views: 124, orders: 0 };

  const axis = scoreProductHealth(seen, degenerate).axes.find(
    (a) => a.key === 'conversion',
  );
  // Still scored — 124 views and no orders is a real problem — but marked as
  // the weaker basis it is, so confidence does not claim a peer comparison
  // that could not be made.
  assert.equal(axis?.score, 0);
  assert.equal(axis?.evidence, 'thin');
});

test('weights renormalise over the axes that could be scored', () => {
  const fresh = { ...listing, impressions: 0, views: 0, searchHits: 0 };
  const result = scoreProductHealth(fresh, cohort);
  const carried = result.axes.reduce((t, a) => t + a.weight, 0);
  assert.ok(Math.abs(carried - 100) < 0.5, `got ${carried}`);
});

// ── The arithmetic ───────────────────────────────────────────────────────

test('a well-made listing that sells scores well', () => {
  const result = scoreProductHealth(listing, cohort);
  assert.ok(result.score > 75, `got ${result.score}`);
  assert.ok(result.confidence > 0.7, 'a full cohort and real traffic');
  assert.ok(result.peers);
  assert.equal(result.peers.peers, 12);
});

test('a bare listing is marked down on what it is missing', () => {
  const bare: ProductFacts = {
    ...listing,
    title: 'فستان',
    description: 'فستان حلو',
    imageCount: 1,
    imagesWithBlurHash: 0,
    attributeCount: 1,
    hasBrand: false,
    hasGtin: false,
  };

  const result = scoreProductHealth(bare, cohort);
  assert.ok(result.score < 60, `got ${result.score}`);

  const content = result.axes.find((a) => a.key === 'content');
  const imagery = result.axes.find((a) => a.key === 'imagery');
  assert.ok((content?.score ?? 100) < 45);
  assert.ok((imagery?.score ?? 100) < 40);
});

test('the price premium is measured against the cohort median', () => {
  const dear = scoreProductHealth({ ...listing, priceSyp: 132_000 }, cohort);
  assert.ok(dear.peers);
  // 132,000 against a median of 88,000 is +50%.
  assert.equal(dear.peers.pricePremiumBps, 5000);
});

// ── Advice: the three sentences the brief asked for by name ──────────────

test('«add more photographs»', () => {
  const advice = adviseProduct(
    { ...listing, imageCount: 2, imagesWithBlurHash: 2 },
    scoreProductHealth({ ...listing, imageCount: 2, imagesWithBlurHash: 2 }, cohort),
  );
  const line = advice.find((a) => a.code === 'MORE_IMAGES');
  assert.ok(line);
  assert.equal(line.severity, 'critical', 'two photographs is below the floor');
  assert.match(line.ar, new RegExp(String(IMAGE_TARGET)));
});

test('«this gets views but few orders»', () => {
  const seen = { ...listing, views: 500, orders: 1, cartAdds: 4, favorites: 3 };
  const advice = adviseProduct(seen, scoreProductHealth(seen, cohort));
  const line = advice.find((a) => a.code === 'VIEWS_NO_CONVERSION');
  assert.ok(line, 'high views and no orders must be raised');
  assert.equal(line.severity, 'critical');
  assert.match(line.ar, /500/, 'quotes her actual view count');
});

test('«your price is above similar products»', () => {
  const dear = { ...listing, priceSyp: 132_000 };
  const advice = adviseProduct(dear, scoreProductHealth(dear, cohort));
  const line = advice.find((a) => a.code === 'PRICE_ABOVE_PEERS');
  assert.ok(line);
  assert.match(line.ar, /50%/, 'says how much above');
});

test('price advice is silent without a cohort to compare against', () => {
  const dear = { ...listing, priceSyp: 400_000 };
  const advice = adviseProduct(dear, scoreProductHealth(dear, null));
  assert.ok(
    !advice.some((a) => a.axis === 'price'),
    'no cohort, no opinion about price',
  );
});

test('a sold-out listing still taking views is critical', () => {
  const gone = { ...listing, inStock: false, stockUnits: 0 };
  const advice = adviseProduct(gone, scoreProductHealth(gone, cohort));
  const line = advice.find((a) => a.code === 'OUT_OF_STOCK');
  assert.equal(line?.severity, 'critical');
});

test('advice leads with what is critical', () => {
  const bad: ProductFacts = {
    ...listing,
    imageCount: 0,
    imagesWithBlurHash: 0,
    views: 500,
    orders: 0,
    inStock: false,
    stockUnits: 0,
  };
  const advice = adviseProduct(bad, scoreProductHealth(bad, cohort));
  assert.ok(advice.length >= 3);
  assert.equal(advice[0].severity, 'critical');
});

test('a good listing is told little, and nothing alarming', () => {
  const advice = adviseProduct(listing, scoreProductHealth(listing, cohort));
  assert.ok(
    !advice.some((a) => a.severity === 'critical'),
    `nothing critical here, got ${advice.map((a) => a.code).join(', ')}`,
  );
});
