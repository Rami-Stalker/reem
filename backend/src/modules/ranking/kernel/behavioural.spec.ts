import assert from 'node:assert/strict';
import test from 'node:test';

import { CUE_RULES, CueFacts, cuesFor } from './behavioural';

/**
 * The line between persuasion and a dark pattern.
 *
 * Every one of these tests is really the same test: when the claim is not
 * true, or not informative, the card says nothing. A marketplace women
 * recommend to each other cannot spend that recommendation on a false urgency
 * badge, and there is no conversion rate that buys it back.
 */

const facts = (over: Partial<CueFacts> = {}): CueFacts => ({
  recentOrders: 0,
  windowDays: 30,
  favourites: 0,
  stock: 50,
  liveOffers: 3,
  rating: 0,
  reviews: 0,
  compareAtPrice: null,
  price: 100_000,
  ...over,
});

const kinds = (f: CueFacts) => cuesFor(f).map((c) => c.kind);

test('an ordinary listing claims nothing', () => {
  assert.deepEqual(
    cuesFor(facts()),
    [],
    'a card with no badge is a card telling the truth about a full shelf',
  );
});

// ── Scarcity ─────────────────────────────────────────────────────────────────

test('scarcity is shown only when the shelf is really nearly empty', () => {
  assert.ok(kinds(facts({ stock: 2, liveOffers: 1 })).includes('scarcity'));
  assert.ok(!kinds(facts({ stock: 40, liveOffers: 1 })).includes('scarcity'));
});

test('one shop running low is not the marketplace running out', () => {
  // Four boutiques stock it; one of them has two left. Saying "only 2 left"
  // would be true of that offer and false of the thing the shopper is buying.
  assert.ok(
    !kinds(facts({ stock: 2, liveOffers: 4 })).includes('scarcity'),
    'this is the commonest false-urgency badge in marketplaces',
  );
});

test('nothing in stock produces no scarcity badge either', () => {
  assert.ok(!kinds(facts({ stock: 0, liveOffers: 1 })).includes('scarcity'));
});

test('the last one says so plainly', () => {
  const [cue] = cuesFor(facts({ stock: 1, liveOffers: 1 }));
  assert.equal(cue.kind, 'scarcity');
  assert.equal(cue.value, 1);
  assert.ok(cue.ar.includes('واحدة'));
});

// ── Social proof ─────────────────────────────────────────────────────────────

test('three sales is true and tells a shopper nothing', () => {
  assert.ok(
    !kinds(facts({ recentOrders: 3 })).includes('social_proof'),
    'the floor is where the claim stops being informative, not where it stops being true',
  );
});

test('real volume is worth saying, with its window', () => {
  const [cue] = cuesFor(
    facts({ recentOrders: CUE_RULES.minRecentOrders + 7, windowDays: 30 }),
  );
  assert.equal(cue.kind, 'social_proof');
  assert.ok(cue.ar.includes('30'), 'a count without a window is not a fact');
});

test('saves only speak when nothing stronger can', () => {
  // Purchases available: the weaker claim must not crowd out the better one.
  const withSales = cuesFor(facts({ recentOrders: 20, favourites: 500 }));
  assert.equal(
    withSales.filter((c) => c.kind === 'social_proof').length,
    1,
  );
  assert.ok(withSales[0].ar.includes('اشترتها'));

  // Nothing else to say: saves are then genuinely the best evidence there is.
  const savesOnly = cuesFor(facts({ favourites: 40 }));
  assert.equal(savesOnly.length, 1);
  assert.ok(savesOnly[0].ar.includes('حفظتها'));
});

// ── Anchoring ────────────────────────────────────────────────────────────────

test('an anchor needs a price that was genuinely charged', () => {
  assert.ok(!kinds(facts({ compareAtPrice: null })).includes('anchor'));
});

test('a higher "was" price is refused when it is not higher', () => {
  assert.ok(
    !kinds(facts({ price: 100_000, compareAtPrice: 90_000 })).includes('anchor'),
  );
});

test('a trivial discount is not worth a badge', () => {
  assert.ok(
    !kinds(facts({ price: 97_000, compareAtPrice: 100_000 })).includes('anchor'),
    'a 3% badge trains shoppers to ignore every badge',
  );
});

test('a real discount states the real percentage', () => {
  const cue = cuesFor(
    facts({ price: 60_000, compareAtPrice: 100_000 }),
  ).find((c) => c.kind === 'anchor')!;
  assert.equal(cue.value, 40);
  assert.ok(cue.ar.includes('40'));
});

// ── Quality ──────────────────────────────────────────────────────────────────

test('one glowing review is not a recommendation', () => {
  assert.ok(!kinds(facts({ rating: 5, reviews: 1 })).includes('quality'));
});

test('a well-reviewed listing may say so', () => {
  const cue = cuesFor(facts({ rating: 4.7, reviews: 60 })).find(
    (c) => c.kind === 'quality',
  )!;
  assert.ok(cue.ar.includes('4.7'));
  assert.ok(cue.ar.includes('60'));
});

test('a mediocre rating is simply not mentioned', () => {
  assert.ok(
    !kinds(facts({ rating: 3.4, reviews: 200 })).includes('quality'),
    'silence, rather than spinning a bad number',
  );
});

// ── Order ────────────────────────────────────────────────────────────────────

test('the strongest honest claim comes first', () => {
  const cues = cuesFor(
    facts({
      stock: 1,
      liveOffers: 1,
      recentOrders: 30,
      rating: 4.8,
      reviews: 100,
      price: 50_000,
      compareAtPrice: 100_000,
    }),
  );
  assert.equal(
    cues[0].kind,
    'scarcity',
    'a client with room for one badge should get the most informative one',
  );
  assert.ok(cues.length >= 3);
});
