import assert from 'node:assert/strict';
import test from 'node:test';

import {
  CategoryDemand,
  PriceTrendInput,
  StockWatchInput,
  UnmetTerm,
  growthOf,
  opportunities,
  priceTrends,
  risingCategories,
  sellerUnmetDemand,
  stockAlerts,
} from './demand-radar';
import {
  RISING_GROWTH,
  UNMET_MIN_MISS_RATE,
  UNMET_MIN_SEARCHES,
} from '../intelligence.constants';

/**
 * The demand radar kernel.
 *
 * What is being tested is mostly *restraint*: the radar's job is to say very
 * little, and every gate below exists to stop it turning a small number into
 * a business recommendation.
 */

// ── Growth ───────────────────────────────────────────────────────────────

test('growth damps a tiny base instead of exploding on it', () => {
  // One search becoming four is not 300% growth in any sense worth acting on.
  assert.equal(growthOf(4, 1), 1, 'the floor of 3 under the denominator');
  assert.equal(growthOf(150, 100), 0.5);
  assert.equal(growthOf(50, 100), -0.5);
  assert.equal(growthOf(0, 0), 0);
});

// ── Rising categories ────────────────────────────────────────────────────

const cat = (over: Partial<CategoryDemand> = {}): CategoryDemand => ({
  categoryId: 'c1',
  name: 'فساتين',
  recent: 300,
  previous: 200,
  trendScore: 70,
  sellerListings: 4,
  sellerUnits: 10,
  ...over,
});

test('only categories actually rising are shown', () => {
  const rows = [
    cat({ categoryId: 'up', recent: 300, previous: 200 }),
    cat({ categoryId: 'flat', recent: 202, previous: 200 }),
    cat({ categoryId: 'down', recent: 120, previous: 200 }),
  ];
  const rising = risingCategories(rows);
  assert.deepEqual(
    rising.map((r) => r.categoryId),
    ['up'],
  );
  assert.ok(rising[0].growth >= RISING_GROWTH);
});

test('a category she already sells in outranks a faster one she does not', () => {
  const rows = [
    cat({ categoryId: 'hers', recent: 300, previous: 200, sellerListings: 5 }),
    cat({ categoryId: 'stranger', recent: 500, previous: 200, sellerListings: 0 }),
  ];
  const rising = risingCategories(rows);
  const hers = rising.find((r) => r.categoryId === 'hers');
  const stranger = rising.find((r) => r.categoryId === 'stranger');

  assert.equal(hers?.presence, 'selling');
  assert.equal(stranger?.presence, 'absent');
  // The stranger grows faster, but a foothold is worth more than momentum she
  // would have to enter a new category from nothing to catch.
  assert.ok(
    (hers?.relevance ?? 0) > 0 && (stranger?.relevance ?? 0) > 0,
    'both are surfaced',
  );
});

// ── Unmet demand ─────────────────────────────────────────────────────────

const term = (over: Partial<UnmetTerm> = {}): UnmetTerm => ({
  termKey: 'abaya-linen',
  display: 'عباية كتان',
  searches: 40,
  zeroResults: 30,
  missRate: 0.75,
  growth: 0.3,
  demandScore: 60,
  suggestedCategoryId: 'c-abaya',
  suggestionAr: null,
  ...over,
});

test('a term nobody searched much is not a business recommendation', () => {
  const thin = term({ searches: UNMET_MIN_SEARCHES - 1 });
  assert.deepEqual(sellerUnmetDemand([thin], new Set()), []);
});

test('a popular search that mostly finds things is not unmet demand', () => {
  // The gate that matters most: plenty of searches, but they are being served.
  const served = term({ searches: 500, missRate: UNMET_MIN_MISS_RATE - 0.05 });
  assert.deepEqual(sellerUnmetDemand([served], new Set()), []);
});

test('demand in her own aisle outranks demand outside it', () => {
  const mine = term({ termKey: 'a', suggestedCategoryId: 'c-mine' });
  const other = term({ termKey: 'b', suggestedCategoryId: 'c-other' });
  const out = sellerUnmetDemand([mine, other], new Set(['c-mine']));

  assert.equal(out[0].termKey, 'a');
  assert.equal(out[0].inHerCategories, true);
  assert.equal(out[1].inHerCategories, false);
  assert.ok(out[0].opportunity > out[1].opportunity);
});

test('demand outside her categories is still shown — it is a reason to expand', () => {
  const out = sellerUnmetDemand([term({ suggestedCategoryId: 'elsewhere' })], new Set());
  assert.equal(out.length, 1, 'never filtered to zero on category alone');
});

// ── Stock ────────────────────────────────────────────────────────────────

const watch = (over: Partial<StockWatchInput> = {}): StockWatchInput => ({
  productId: 'p1',
  title: 'فستان كحلي',
  stockUnits: 40,
  dailyUnits: 1,
  recentViews: 100,
  previousViews: 80,
  inStock: true,
  ...over,
});

test('low stock only matters when demand is actually there', () => {
  const quiet = watch({ stockUnits: 2, dailyUnits: 0, recentViews: 0, previousViews: 0 });
  assert.deepEqual(stockAlerts([quiet]), [], 'nothing selling, nothing to warn about');
});

test('plenty of stock under heavy demand is good news, not an alert', () => {
  const healthy = watch({ stockUnits: 400, dailyUnits: 2, recentViews: 900 });
  assert.deepEqual(stockAlerts([healthy]), []);
});

test('sold out while people are still arriving is the most urgent state', () => {
  const gone = watch({ stockUnits: 0, inStock: false, recentViews: 120 });
  const [alert] = stockAlerts([gone]);
  assert.equal(alert.severity, 'critical');
  assert.equal(alert.coverDays, 0);
  assert.match(alert.ar, /120/, 'says how much demand is being wasted');
});

test('sold out with nobody looking is not worth interrupting her for', () => {
  const gone = watch({ stockUnits: 0, inStock: false, recentViews: 0 });
  assert.deepEqual(stockAlerts([gone]), []);
});

test('running low with rising demand outranks running low quietly', () => {
  const rising = watch({
    productId: 'rising',
    stockUnits: 2,
    dailyUnits: 1,
    recentViews: 300,
    previousViews: 100,
  });
  const flat = watch({
    productId: 'flat',
    stockUnits: 6,
    dailyUnits: 1,
    recentViews: 100,
    previousViews: 100,
  });

  const alerts = stockAlerts([flat, rising]);
  assert.equal(alerts[0].productId, 'rising');
  assert.equal(alerts[0].severity, 'critical');
  assert.equal(alerts[1].severity, 'warning');
});

// ── Prices ───────────────────────────────────────────────────────────────

test('price movement is reported with her own position in it', () => {
  const rows: PriceTrendInput[] = [
    {
      categoryId: 'c1',
      name: 'فساتين',
      recentMedian: 110_000,
      previousMedian: 100_000,
      sellerMedian: 140_000,
    },
  ];
  const [trend] = priceTrends(rows);
  assert.equal(trend.changeBps, 1000, '+10%');
  assert.ok(trend.sellerPremiumBps && trend.sellerPremiumBps > 2000);
  assert.match(trend.ar, /ترتفع/);
  assert.match(trend.ar, /أعلى/, 'and where she sits in it');
});

test('a category with no history is skipped rather than guessed', () => {
  const rows: PriceTrendInput[] = [
    { categoryId: 'c1', name: 'جديد', recentMedian: 90_000, previousMedian: null, sellerMedian: null },
  ];
  assert.deepEqual(priceTrends(rows), []);
});

// ── The one list she reads ───────────────────────────────────────────────

test('restocking proven demand outranks entering a new category', () => {
  const list = opportunities({
    stock: stockAlerts([watch({ stockUnits: 0, inStock: false, recentViews: 200 })]),
    unmet: sellerUnmetDemand([term()], new Set(['c-abaya'])),
    rising: risingCategories([cat({ sellerListings: 0, recent: 900, previous: 200 })]),
  });

  assert.ok(list.length >= 3);
  assert.equal(list[0].code, 'RESTOCK_DEMAND', 'demand she already proved comes first');
  assert.ok(
    list.findIndex((o) => o.code === 'UNMET_IN_CATEGORY') <
      list.findIndex((o) => o.code === 'ENTER_CATEGORY'),
    'serving her own aisle beats opening a new one',
  );

  // Every line has to be a sentence she can act on.
  assert.ok(list.every((o) => o.ar.length > 10));
});

test('an empty radar is empty rather than padded', () => {
  assert.deepEqual(opportunities({ stock: [], unmet: [], rising: [] }), []);
});
