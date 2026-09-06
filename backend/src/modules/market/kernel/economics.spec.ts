import assert from 'node:assert/strict';
import test from 'node:test';
import { MarketFinding } from '@prisma/client';

import {
  MarketFacts,
  MarketNorms,
  growthOf,
  launchPotential,
  readMarket,
  scale,
} from './economics';

/**
 * The economics kernel.
 *
 * The cases that matter are the ones where demand and supply point in
 * opposite directions, because that is the whole reason this layer exists:
 * every other system in Reem can already count. Only this one says what the
 * counts mean together.
 */

const norms: MarketNorms = {
  halfViews: 200,
  halfProducts: 12,
  halfSellers: 6,
  medianConversion: 0.03,
};

const facts = (over: Partial<MarketFacts> = {}): MarketFacts => ({
  views: 200,
  searches: 20,
  cartAdds: 10,
  favourites: 8,
  orders: 6,
  units: 7,
  recentViews: 110,
  previousViews: 90,
  liveProducts: 12,
  liveOffers: 14,
  stockUnits: 90,
  sellers: 5,
  openNeeds: 0,
  medianPriceSyp: 100_000,
  parentMedianPriceSyp: 100_000,
  ...over,
});

const codes = (f: MarketFacts): MarketFinding[] =>
  readMarket(f, norms).findings.map((x) => x.code);

// ── Shapes ───────────────────────────────────────────────────────────────

test('the scale flattens a long tail instead of crushing it', () => {
  assert.equal(scale(0, 200), 0);
  assert.equal(scale(200, 200), 50, 'the half-point is the half-point');

  // The difference that matters is at the bottom, not the top.
  const small = scale(40, 200) - scale(10, 200);
  const large = scale(4030, 200) - scale(4000, 200);
  assert.ok(
    small > large * 10,
    'thirty views should matter more at ten than at four thousand',
  );
});

test('growth damps a tiny base', () => {
  assert.equal(growthOf(4, 1), 1);
  assert.equal(growthOf(150, 100), 0.5);
});

// ── The reading this layer exists for ────────────────────────────────────

test('demand well ahead of supply is a gap', () => {
  const hungry = facts({
    views: 900,
    searches: 120,
    cartAdds: 40,
    liveProducts: 1,
    stockUnits: 4,
    sellers: 1,
  });
  const reading = readMarket(hungry, norms);

  assert.ok(reading.tension > 25, `tension ${reading.tension}`);
  assert.ok(reading.findings.some((f) => f.code === MarketFinding.SUPPLY_GAP));
  assert.ok(reading.demandScore > reading.supplyScore);
});

test('the same demand with a crowded aisle is not a gap', () => {
  const crowded = facts({
    views: 900,
    searches: 120,
    cartAdds: 40,
    liveProducts: 120,
    stockUnits: 900,
    sellers: 20,
  });
  const found = codes(crowded);

  assert.ok(!found.includes(MarketFinding.SUPPLY_GAP));
  assert.ok(found.includes(MarketFinding.CROWDED));
});

test('plenty listed and nobody looking is oversupply', () => {
  const quiet = facts({
    views: 8,
    searches: 0,
    cartAdds: 0,
    favourites: 0,
    orders: 0,
    recentViews: 4,
    previousViews: 4,
    liveProducts: 90,
    stockUnits: 400,
    sellers: 10,
  });
  assert.ok(codes(quiet).includes(MarketFinding.OVERSUPPLIED));
});

test('a listing nobody can buy is not supply', () => {
  // The distinction the whole STOCKED_OUT finding rests on.
  const empty = facts({ liveProducts: 40, stockUnits: 0, views: 400 });
  const reading = readMarket(empty, norms);

  assert.equal(reading.supplyScore, 0, 'forty listings with no stock is no supply');
  assert.ok(reading.findings.some((f) => f.code === MarketFinding.STOCKED_OUT));
});

test('an open need counts for more than a view', () => {
  const looked = readMarket(facts({ views: 300, openNeeds: 0 }), norms);
  const needed = readMarket(facts({ views: 300, openNeeds: 12 }), norms);

  assert.ok(
    needed.demandScore > looked.demandScore,
    'a gap in a saved outfit is a stronger want than a glance',
  );
});

// ── Direction ────────────────────────────────────────────────────────────

test('direction needs volume as well as growth', () => {
  const climbing = facts({ recentViews: 300, previousViews: 100 });
  assert.ok(codes(climbing).includes(MarketFinding.RISING));

  const tiny = facts({ views: 8, recentViews: 6, previousViews: 2 });
  assert.ok(
    !codes(tiny).includes(MarketFinding.RISING),
    'six views is not a trend',
  );

  const falling = facts({ recentViews: 40, previousViews: 200 });
  assert.ok(codes(falling).includes(MarketFinding.COOLING));
});

// ── Conversion ───────────────────────────────────────────────────────────

test('attention that does not convert is named as such', () => {
  const seen = facts({ views: 600, orders: 1 });
  assert.ok(codes(seen).includes(MarketFinding.WEAK_CONVERSION));
});

test('conversion is withheld below the view floor', () => {
  const quiet = facts({ views: 12, orders: 0, searches: 0 });
  const reading = readMarket(quiet, norms);

  assert.equal(reading.conversionScore, 0);
  assert.ok(
    !reading.findings.some((f) => f.code === MarketFinding.WEAK_CONVERSION),
    'twelve views cannot prove a conversion problem',
  );
});

test('a market nobody has visited has no confidence', () => {
  const empty = facts({ views: 0, searches: 0, cartAdds: 0, favourites: 0, orders: 0 });
  assert.equal(readMarket(empty, norms).confidence, 0);
});

test('every finding carries the numbers behind it', () => {
  const reading = readMarket(
    facts({ views: 900, liveProducts: 1, stockUnits: 3, sellers: 1 }),
    norms,
  );
  assert.ok(reading.findings.length > 0);
  for (const finding of reading.findings) {
    assert.ok(finding.strength > 0 && finding.strength <= 100);
    assert.ok(Object.keys(finding.evidence).length > 0, `${finding.code} has no evidence`);
  }
});

// ── Launch potential ─────────────────────────────────────────────────────

test('a new, wanted, unserved product is worth launching', () => {
  const reading = readMarket(
    facts({
      views: 600,
      // Converting at the platform median: this is a promising product, not
      // one already failing. The first draft of this fixture gave it a 1%
      // rate and then wondered why the launch score was low — the kernel was
      // right and the fixture was describing a different product.
      orders: 18,
      cartAdds: 30,
      liveProducts: 2,
      stockUnits: 40,
      recentViews: 400,
      previousViews: 150,
    }),
    norms,
  );
  const score = launchPotential({ reading, ageDays: 2, stockUnits: 40 });
  assert.ok(score > 60, `got ${score}`);
});

test('something out of stock is never a drop candidate', () => {
  const reading = readMarket(facts(), norms);
  assert.equal(launchPotential({ reading, ageDays: 1, stockUnits: 0 }), 0);
});

test('a product that already failed to convert is not given a spotlight', () => {
  // It does not need an event, it needs a better price or better photographs.
  const reading = readMarket(facts({ views: 800, orders: 1 }), norms);
  const failing = launchPotential({ reading, ageDays: 2, stockUnits: 50 });
  const healthy = launchPotential({
    reading: readMarket(facts({ views: 800, orders: 40 }), norms),
    ageDays: 2,
    stockUnits: 50,
  });

  assert.ok(failing < healthy, `${failing} should be below ${healthy}`);
});

test('newness fades', () => {
  const reading = readMarket(facts(), norms);
  const fresh = launchPotential({ reading, ageDays: 0, stockUnits: 50 });
  const old = launchPotential({ reading, ageDays: 90, stockUnits: 50 });

  assert.ok(fresh > old);
  assert.ok(old >= 0, 'an older product is still scoreable, just not new');
});
