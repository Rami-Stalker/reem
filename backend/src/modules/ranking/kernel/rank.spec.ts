import assert from 'node:assert/strict';
import test from 'node:test';

import {
  ListingFacts,
  RATING_PRIOR,
  SellerRankFacts,
  scoreListing,
  scoreSeller,
  smoothedRating,
} from './rank';

/**
 * The ordering rules, pinned.
 *
 * Most of these guard against a specific way a first ranking goes wrong, and
 * each of those ways is one somebody will notice from the outside: a seller
 * asking why her dress fell, or a competitor working out that one review from
 * a friend puts a listing on page one.
 */

const listing = (over: Partial<ListingFacts> = {}): ListingFacts => ({
  views: 1000,
  orders: 30,
  favourites: 80,
  reviews: 40,
  rating: 4.4,
  liveOffers: 2,
  stock: 12,
  ageDays: 60,
  daysSinceLastOrder: 3,
  refunds: 1,
  ...over,
});

const value = (facts: ListingFacts, key: string) =>
  scoreListing(facts).components.find((c) => c.key === key)!.value;

// ── The three corrections ────────────────────────────────────────────────────

test('one five-star review does not beat a well-reviewed listing', () => {
  const lucky = smoothedRating(5, 1);
  const proven = smoothedRating(4.6, 300);

  assert.ok(
    proven > lucky,
    `a single review must not outrank three hundred: ${proven} vs ${lucky}`,
  );
  assert.ok(
    Math.abs(lucky - RATING_PRIOR) < 0.2,
    'and one review should land near the prior, not near five',
  );
});

test('a rating with real volume behind it is trusted', () => {
  assert.ok(Math.abs(smoothedRating(4.8, 500) - 4.8) < 0.05);
});

test('ranking is on conversion, not on lifetime orders', () => {
  // An old listing with a big total but almost nobody converting.
  const stale = listing({ views: 100_000, orders: 400, daysSinceLastOrder: 90 });
  // A newer listing far fewer people saw, but which sells to those who did.
  const converting = listing({ views: 800, orders: 60, daysSinceLastOrder: 2 });

  assert.ok(
    scoreListing(converting).score > scoreListing(stale).score,
    'ranking on totals freezes the page around whatever sold well two years ago',
  );
});

test('views alone move the score very little', () => {
  // The signal a seller can manufacture is the one that must not pay.
  const honest = listing({ views: 1000 });
  const inflated = listing({ views: 20_000 });

  assert.ok(
    scoreListing(inflated).score < scoreListing(honest).score,
    'buying views should make conversion look worse, never better',
  );
});

test('a listing that sells and comes back has not converted anybody', () => {
  const kept = listing({ orders: 30, refunds: 0 });
  const returned = listing({ orders: 30, refunds: 25 });

  assert.ok(
    scoreListing(kept).score > scoreListing(returned).score,
    'a refunded sale cost two deliveries and a customer’s afternoon',
  );
});

// ── The components ───────────────────────────────────────────────────────────

test('something nobody can buy does not sit at the top of a page', () => {
  const available = listing({ liveOffers: 3, stock: 20 });
  const soldOut = listing({ liveOffers: 3, stock: 0 });

  assert.equal(value(soldOut, 'availability'), 0);
  assert.ok(scoreListing(available).score > scoreListing(soldOut).score);
});

test('a listing selling today outranks one that sold last season', () => {
  const now = listing({ daysSinceLastOrder: 1 });
  const then = listing({ daysSinceLastOrder: 120 });
  assert.ok(value(now, 'demand') > value(then, 'demand') * 5);
});

test('a new listing gets enough allowance to be seen at all', () => {
  const fresh = listing({ ageDays: 1, views: 5, orders: 0, reviews: 0, daysSinceLastOrder: null });
  assert.ok(
    value(fresh, 'freshness') > 0.9,
    'without this nothing new accumulates the traffic the other components need',
  );
  assert.ok(scoreListing(fresh).score > 0);
});

test('and that allowance decays, so it cannot be lived on', () => {
  const old = listing({ ageDays: 180 });
  assert.ok(value(old, 'freshness') < 0.01);
});

test('thin traffic is scored but flagged as thin', () => {
  const quiet = listing({ views: 8, orders: 2, reviews: 1 });
  const reading = scoreListing(quiet);
  assert.equal(reading.confident, false);
  assert.ok(reading.score > 0, 'not buried — just not yet evidence');
});

test('every component explains itself in Arabic', () => {
  const reading = scoreListing(listing());
  assert.ok(reading.components.length >= 6);
  assert.ok(
    reading.components.every((c) => c.ar.length > 0),
    'a seller asking why her dress is on page three deserves an answer',
  );
});

test('the weights sum to one, so the score is a percentage of something', () => {
  const reading = scoreListing(listing());
  const total = reading.components.reduce((sum, c) => sum + c.weight, 0);
  assert.ok(Math.abs(total - 1) < 1e-9, `weights summed to ${total}`);
  assert.ok(reading.score >= 0 && reading.score <= 100);
});

// ── Sellers ──────────────────────────────────────────────────────────────────

const seller = (over: Partial<SellerRankFacts> = {}): SellerRankFacts => ({
  delivered: 100,
  cancelled: 2,
  refunded: 5,
  rating: 4.5,
  reviews: 60,
  liveListings: 40,
  responseHours: 5,
  daysSinceLastSale: 2,
  ...over,
});

test('a reliable quiet shop outranks a busy one that cancels', () => {
  const reliable = seller({ delivered: 60, cancelled: 0 });
  const flaky = seller({ delivered: 300, cancelled: 70 });

  assert.ok(
    scoreSeller(reliable).score > scoreSeller(flaky).score,
    'a cancelled order costs a customer, and customers are the scarce thing',
  );
});

test('answering matters, and not answering matters more', () => {
  const quick = seller({ responseHours: 2 });
  const slow = seller({ responseHours: 60 });
  const silent = seller({ responseHours: null });

  assert.ok(scoreSeller(quick).score > scoreSeller(slow).score);
  assert.ok(
    scoreSeller(silent).score > scoreSeller(slow).score,
    'a shop nobody has asked is not a shop that ignores people',
  );
});

test('a seller rating is smoothed too', () => {
  const lucky = seller({ rating: 5, reviews: 1, delivered: 12 });
  const proven = seller({ rating: 4.5, reviews: 200, delivered: 12 });
  assert.ok(scoreSeller(proven).score > scoreSeller(lucky).score);
});

test('a new boutique is scored but not yet trusted', () => {
  const reading = scoreSeller(seller({ delivered: 3, reviews: 0 }));
  assert.equal(reading.confident, false);
});

test('a shop that has stopped selling drifts down', () => {
  const active = seller({ daysSinceLastSale: 1 });
  const dormant = seller({ daysSinceLastSale: 120 });
  assert.ok(scoreSeller(active).score > scoreSeller(dormant).score);
});
