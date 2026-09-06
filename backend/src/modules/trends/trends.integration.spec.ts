import assert from 'node:assert/strict';
import test from 'node:test';
import {
  AnalyticsEventType,
  PrismaClient,
  TrendInsightAudience,
  TrendStage,
  TrendSubjectKind,
  TrendWindow,
} from '@prisma/client';

import { PrismaService } from '../../prisma/prisma.service';
import { ExchangeRateService } from '../pricing/exchange-rate.service';
import { SignalCollectorService } from './collection/signal-collector.service';
import { TrendRunRecorder } from './collection/trend-run.recorder';
import { TrendSignalService } from './collection/trend-signal.service';
import { addDays, dayKey, utcToday } from './collection/day';
import { AdminTrendsService } from './dashboards/admin-trends.service';
import { SellerTrendsService } from './dashboards/seller-trends.service';
import { TrendForecastService } from './forecasting/trend-forecast.service';
import { DisabledTrendLlm } from './insights/llm/trend-llm';
import { TrendInsightsService } from './insights/trend-insights.service';
import { TrendScoringService } from './scoring/trend-scoring.service';
import { SearchIntelligenceService } from './search/search-intelligence.service';
import { normaliseQuery } from './kernel/query-normalizer';

/**
 * The Trend Engine against the real database.
 *
 * The kernel's unit tests prove the arithmetic in isolation. This proves the
 * claim the feature is actually built on: that a fortnight of *planted
 * activity* in the ordinary tables comes out the other end as a score, a
 * stage, a forecast and an Arabic sentence — with no model configured, and
 * with every number traceable to a row somebody could go and look at.
 *
 * Every case runs inside a transaction that is rolled back, so the seeded shop
 * is unchanged afterwards. The language model is the disabled provider, which
 * is the point: the deterministic path has to work on its own, and it is the
 * one that ships when nothing is configured.
 */
const prisma = new PrismaClient();

class Rollback extends Error {}
type Tx = Parameters<Parameters<typeof prisma.$transaction>[0]>[0];

let reachable = false;

test.before(async () => {
  try {
    await prisma.$queryRaw`SELECT 1`;
    reachable = true;
  } catch {
    reachable = false;
  }
});

test.after(() => prisma.$disconnect());

function dbTest(name: string, body: (world: World) => Promise<void>): void {
  test(name, async (t) => {
    if (!reachable) {
      t.skip('no database reachable');
      return;
    }
    let failure: unknown;
    try {
      await prisma.$transaction(
        async (tx) => {
          try {
            await body(build(tx));
          } catch (error) {
            failure = error;
          }
          throw new Rollback();
        },
        { timeout: 120_000 },
      );
    } catch (error) {
      if (!(error instanceof Rollback)) throw error;
    }
    if (failure) throw failure;
  });
}

/** Nested transactions flattened onto the one the test rolls back. */
function asPrisma(tx: Tx): PrismaService {
  return new Proxy(tx as unknown as Record<string, unknown>, {
    get(target, prop, receiver) {
      if (prop === '$transaction') {
        return async (fn: unknown) => {
          if (Array.isArray(fn)) return Promise.all(fn);
          return (fn as (inner: Tx) => unknown)(tx);
        };
      }
      return Reflect.get(target, prop, receiver);
    },
  }) as unknown as PrismaService;
}

interface World {
  db: PrismaService;
  collector: SignalCollectorService;
  scoring: TrendScoringService;
  forecasts: TrendForecastService;
  searchIntel: SearchIntelligenceService;
  insights: TrendInsightsService;
  sellerDash: SellerTrendsService;
  adminDash: AdminTrendsService;
  signals: TrendSignalService;
}

function build(tx: Tx): World {
  const db = asPrisma(tx);
  const runs = new TrendRunRecorder(db);
  const rates = new ExchangeRateService(db);
  const collector = new SignalCollectorService(db, rates, runs);
  const scoring = new TrendScoringService(db, runs);
  const forecasts = new TrendForecastService(db, runs);
  const searchIntel = new SearchIntelligenceService(db, runs);
  const insights = new TrendInsightsService(db, runs, new DisabledTrendLlm());
  const sellerDash = new SellerTrendsService(db, forecasts, insights);
  const adminDash = new AdminTrendsService(db, forecasts, insights, searchIntel);
  return {
    db,
    collector,
    scoring,
    forecasts,
    searchIntel,
    insights,
    sellerDash,
    adminDash,
    signals: new TrendSignalService(db),
  };
}

// ── Planting activity ────────────────────────────────────────────────────

/** A product from the seeded shop, with the seller who lists it. */
/**
 * A live offer whose product has had no activity at all today.
 *
 * The k-anonymity case needs a product it can be the *only* source of views
 * for, so that the distinct-viewer count it creates is genuinely below the
 * floor. Picking the first live offer worked only while the demo dataset was
 * stale enough to have written nothing for today; a freshly seeded shop has
 * views on its popular products from this morning, which both inflated the view
 * count and pushed the viewer count above the floor the test exists to check.
 */
async function quietOffer(db: PrismaService) {
  const today = utcToday();
  const busy = await db.analyticsEvent.findMany({
    where: { occurredAt: { gte: today }, productId: { not: null } },
    select: { productId: true },
    distinct: ['productId'],
  });
  const noisy = busy
    .map((row) => row.productId)
    .filter((id): id is string => id !== null);

  const offer = await db.sellerOffer.findFirst({
    where: {
      isActive: true,
      status: 'ACTIVE',
      stock: { gt: 0 },
      ...(noisy.length ? { productId: { notIn: noisy } } : {}),
    },
    select: {
      productId: true,
      sellerId: true,
      product: { select: { id: true, title: true, categoryId: true } },
    },
  });
  assert.ok(offer, 'the seeded shop has no live offer that is quiet today');
  return offer;
}

async function someOffer(db: PrismaService) {
  const offer = await db.sellerOffer.findFirst({
    where: { isActive: true, status: 'ACTIVE', stock: { gt: 0 } },
    select: {
      productId: true,
      sellerId: true,
      product: { select: { id: true, title: true, categoryId: true } },
    },
  });
  assert.ok(offer, 'the seeded shop has no live offer to analyse');
  return offer;
}

/**
 * Write a fortnight of views and cart adds for one product, climbing steeply
 * in the second week.
 *
 * Deliberately written as **analytics events**, not as fact rows: the point of
 * the test is that the collector turns ordinary activity into facts, and
 * seeding the facts directly would skip the half of the pipeline most likely
 * to be wrong.
 */
async function plantClimb(
  db: PrismaService,
  productId: string,
  days = 14,
): Promise<void> {
  const today = utcToday();
  const rows: Array<{
    type: AnalyticsEventType;
    productId: string;
    occurredAt: Date;
  }> = [];

  for (let offset = days - 1; offset >= 0; offset -= 1) {
    const day = addDays(today, -offset);
    const secondWeek = offset < days / 2;
    const views = secondWeek ? 40 + (days / 2 - offset) * 18 : 10;
    const carts = secondWeek ? 4 + (days / 2 - offset) * 2 : 1;

    for (let i = 0; i < views; i += 1) {
      rows.push({
        type: AnalyticsEventType.PRODUCT_VIEW,
        productId,
        // Noon, so the row lands unambiguously inside its own UTC day.
        occurredAt: new Date(day.getTime() + 12 * 3_600_000),
      });
    }
    for (let i = 0; i < carts; i += 1) {
      rows.push({
        type: AnalyticsEventType.CART_ADD,
        productId,
        occurredAt: new Date(day.getTime() + 13 * 3_600_000),
      });
    }
  }

  await db.analyticsEvent.createMany({ data: rows });
}

async function rollupWindow(world: World, days = 14): Promise<void> {
  const today = utcToday();
  for (let offset = days - 1; offset >= 0; offset -= 1) {
    await world.collector.rollupDay(addDays(today, -offset));
  }
}

// ── The pipeline, end to end ─────────────────────────────────────────────

dbTest('activity becomes a daily fact row with the right totals', async (world) => {
  const offer = await someOffer(world.db);
  await plantClimb(world.db, offer.productId, 4);
  await rollupWindow(world, 4);

  const today = utcToday();
  const fact = await world.db.productDemandDaily.findUnique({
    where: { productId_day: { productId: offer.productId, day: today } },
  });

  assert.ok(fact, 'no fact row was written for today');
  assert.ok(fact.views > 0, 'views were not collected');
  assert.equal(fact.categoryId, offer.product.categoryId, 'category denormalised');
  // Supply is snapshotted from the live offers, not invented.
  assert.ok(fact.liveOffers >= 1);
  assert.equal(fact.inStock, true);
});

dbTest('the roll-up is idempotent — running a day twice does not double it', async (world) => {
  const offer = await someOffer(world.db);
  await plantClimb(world.db, offer.productId, 2);

  const today = utcToday();
  await world.collector.rollupDay(today);
  const first = await world.db.productDemandDaily.findUnique({
    where: { productId_day: { productId: offer.productId, day: today } },
  });

  await world.collector.rollupDay(today);
  const second = await world.db.productDemandDaily.findUnique({
    where: { productId_day: { productId: offer.productId, day: today } },
  });

  assert.ok(first && second);
  assert.equal(second.views, first.views, 'a second run doubled the views');
  assert.equal(second.id, first.id, 'a second run inserted a duplicate row');
});

dbTest('a climbing product is scored, staged and ranked', async (world) => {
  const offer = await someOffer(world.db);
  await plantClimb(world.db, offer.productId);
  await rollupWindow(world);
  await world.scoring.scoreAll();

  const score = await world.db.productTrendScore.findUnique({
    where: {
      productId_window_capturedOn: {
        productId: offer.productId,
        window: TrendWindow.D7,
        capturedOn: utcToday(),
      },
    },
  });

  assert.ok(score, 'the climbing product was not scored');
  assert.ok(score.score > 0 && score.score <= 100, `score out of range: ${score.score}`);
  const rising: TrendStage[] = [
    TrendStage.EMERGING,
    TrendStage.RISING,
    TrendStage.PEAKING,
  ];
  assert.ok(rising.includes(score.stage), `expected a rising stage, got ${score.stage}`);
  assert.ok(score.confidence > 0, 'a product with real traffic has no confidence');
  assert.ok(score.rank !== null, 'no leaderboard rank was assigned');
  // The evidence travels with the judgement.
  assert.ok(score.metrics, 'the score carries no metrics to explain itself');
  assert.ok(score.viewGrowth > 0.5, `view growth should be strong: ${score.viewGrowth}`);
});

dbTest('scoring is idempotent for the same capture day', async (world) => {
  const offer = await someOffer(world.db);
  await plantClimb(world.db, offer.productId);
  await rollupWindow(world);

  await world.scoring.scoreAll();
  const first = await world.db.productTrendScore.count({
    where: { capturedOn: utcToday() },
  });
  await world.scoring.scoreAll();
  const second = await world.db.productTrendScore.count({
    where: { capturedOn: utcToday() },
  });
  assert.equal(second, first, 'a second scoring run duplicated rows');
});

dbTest('a forecast is produced from the collected sales history', async (world) => {
  const offer = await someOffer(world.db);
  await plantClimb(world.db, offer.productId);
  await rollupWindow(world);
  await world.forecasts.forecastAll();

  const platform = await world.forecasts.latest({
    subjectKind: TrendSubjectKind.PLATFORM,
    subjectKey: 'PLATFORM',
    horizonDays: 7,
  });

  assert.ok(platform, 'no platform forecast was written');
  assert.equal(platform.horizonDays, 7);
  assert.ok(Array.isArray(platform.points));
  assert.equal((platform.points as unknown[]).length, 7, 'seven days, seven points');
  assert.ok(platform.confidence >= 0 && platform.confidence <= 1);
  assert.ok(Number(platform.totalRevenueSyp) >= 0);
});

// ── Search intelligence ──────────────────────────────────────────────────

dbTest('a search that returns nothing becomes an unmet demand signal', async (world) => {
  const today = utcToday();
  const query = 'فستان سهرة أخضر طويل';
  const termKey = normaliseQuery(query).termKey;
  assert.ok(termKey, 'the query normalised to nothing');

  // Twenty women asked, over three days, and the catalogue had no answer.
  for (let offset = 2; offset >= 0; offset -= 1) {
    const day = addDays(today, -offset);
    await world.db.analyticsEvent.createMany({
      data: Array.from({ length: 8 }, () => ({
        type: AnalyticsEventType.SEARCH_ZERO_RESULT,
        occurredAt: new Date(day.getTime() + 11 * 3_600_000),
        metadata: { q: query, results: 0, product_ids: [] },
      })),
    });
    await world.collector.rollupDay(day);
  }

  const daily = await world.db.searchTermDaily.findUnique({
    where: { termKey_day: { termKey, day: today } },
  });
  assert.ok(daily, 'the search term was not rolled up');
  // At least the eight planted here. The demo seed browses the shop too, and
  // asserting an exact total would make this case depend on what else the
  // database happens to hold — which is the opposite of what it is testing.
  assert.ok(daily.searches >= 8, `only ${daily.searches} searches rolled up`);
  assert.equal(
    daily.zeroResults,
    daily.searches,
    'every search for this term missed, so the two must agree',
  );
  // The spelling she typed is kept for display; the key is the facet set.
  assert.notEqual(daily.termKey, query);

  await world.searchIntel.refresh();
  const signal = await world.db.unmetDemandSignal.findUnique({
    where: { termKey },
    include: { suggestedCategory: true },
  });

  assert.ok(signal, 'no unmet demand signal was raised');
  assert.equal(signal.missRate, 1, 'every search missed');
  assert.ok(signal.demandScore > 0);
  assert.ok(signal.suggestionAr, 'the buying team was given no sentence');
  // The facets are what make it sourceable rather than a curiosity.
  const facets = signal.facets as { colours?: string[]; occasion?: string | null };
  assert.ok(facets.colours?.includes('green'), 'the colour was not understood');
  assert.equal(facets.occasion, 'evening');
});

dbTest('three spellings of one question are one signal, not three', async (world) => {
  const today = utcToday();
  const spellings = ['فستان سهرة أخضر', 'فساتين سهره خضراء', 'الفستان الأخضر للسهرة'];

  for (const query of spellings) {
    await world.db.analyticsEvent.createMany({
      data: Array.from({ length: 4 }, () => ({
        type: AnalyticsEventType.SEARCH_ZERO_RESULT,
        occurredAt: new Date(today.getTime() + 11 * 3_600_000),
        metadata: { q: query, results: 0, product_ids: [] },
      })),
    });
  }
  await world.collector.rollupDay(today);

  // One row, not three. The count is `>= 12` rather than `12` because the
  // demo seed searches for the same thing — what is being asserted is that
  // three spellings collapsed onto one key, not the size of the total.
  const key = normaliseQuery(spellings[0]).termKey;
  const rows = await world.db.searchTermDaily.findMany({
    where: { day: today, termKey: key },
  });
  assert.equal(rows.length, 1, 'the three spellings did not merge');
  assert.ok(
    rows[0].searches >= 12,
    `expected at least the twelve planted, got ${rows[0].searches}`,
  );
  for (const spelling of spellings) {
    assert.equal(
      normaliseQuery(spelling).termKey,
      key,
      `«${spelling}» landed on a different key`,
    );
  }
});

// ── Insights ─────────────────────────────────────────────────────────────

dbTest('insights are generated in Arabic with no model configured', async (world) => {
  const offer = await someOffer(world.db);
  await plantClimb(world.db, offer.productId);
  await rollupWindow(world);
  await world.scoring.scoreAll();
  await world.forecasts.forecastAll();
  await world.searchIntel.refresh();
  const result = await world.insights.generate({ window: TrendWindow.D7 });

  assert.ok(
    result.admin + result.seller > 0,
    'a steeply climbing product produced no insight at all',
  );

  const rows = await world.db.trendInsight.findMany({
    where: { generatedOn: utcToday() },
    take: 20,
  });
  assert.ok(rows.length > 0);

  for (const row of rows) {
    assert.ok(/[؀-ۿ]/.test(row.bodyAr), `not Arabic: ${row.bodyAr}`);
    assert.ok(row.titleAr.length > 0);
    // With no provider configured every row is template-phrased, and says so.
    assert.equal(row.narrator, 'reem-trend-templates-v1');
    // The evidence is always stored beside the sentence.
    assert.ok(row.metrics, `${row.kind} has no metrics behind it`);
    assert.ok(row.priority >= 0);
    assert.ok(row.expiresAt > row.generatedOn, 'an insight with no shelf life');
  }
});

dbTest('a second insight run refreshes today rather than stacking duplicates', async (world) => {
  const offer = await someOffer(world.db);
  await plantClimb(world.db, offer.productId);
  await rollupWindow(world);
  await world.scoring.scoreAll();

  await world.insights.generate({ window: TrendWindow.D7 });
  const first = await world.db.trendInsight.count({
    where: { generatedOn: utcToday() },
  });
  await world.insights.generate({ window: TrendWindow.D7 });
  const second = await world.db.trendInsight.count({
    where: { generatedOn: utcToday() },
  });

  assert.ok(first > 0);
  assert.equal(second, first, 'the second run stacked duplicate insights');
});

// ── Dashboards ───────────────────────────────────────────────────────────

dbTest('the seller dashboard shows her product with its score and forecast', async (world) => {
  const offer = await someOffer(world.db);
  await plantClimb(world.db, offer.productId);
  await rollupWindow(world);
  await world.scoring.scoreAll();
  await world.forecasts.forecastAll();
  await world.insights.generate({ window: TrendWindow.D7 });

  const overview = await world.sellerDash.overview(offer.sellerId, TrendWindow.D7);

  assert.equal(dayKey(overview.asOf), dayKey(utcToday()));
  assert.equal(overview.windowDays, 7);
  const row = [...overview.trending, ...overview.emerging].find(
    (entry) => entry.productId === offer.productId,
  );
  assert.ok(row, 'her climbing product is not on her own dashboard');
  assert.ok(row.score > 0);
  assert.equal(row.title, offer.product.title);
  // Demand is product-level; the sales figures are hers.
  assert.ok(row.views > 0, 'the demand signal did not reach the dashboard');
  assert.ok(Array.isArray(overview.series));
  assert.ok(overview.forecast.horizonDays === 14);
});

dbTest('a seller sees only products she actually lists', async (world) => {
  const offer = await someOffer(world.db);
  await plantClimb(world.db, offer.productId);
  await rollupWindow(world);
  await world.scoring.scoreAll();

  // A seller who does *not* list this product. The exclusion matters: a
  // product with two sellers is on both their dashboards, and correctly so —
  // they compete for one page and the demand on it is demand both of them can
  // act on. The isolation being tested is against sellers with no offer at all.
  const stranger = await world.db.user.findFirst({
    where: {
      role: 'SELLER',
      id: { not: offer.sellerId },
      sellerOffers: { none: { productId: offer.productId } },
    },
    select: { id: true },
  });
  if (!stranger) return;

  const theirs = await world.sellerDash.products(stranger.id, TrendWindow.D7, {
    limit: 200,
  });
  assert.ok(
    !theirs.rows.some((row) => row.productId === offer.productId),
    "a seller can see a product she does not list on her own dashboard",
  );
});

dbTest('the admin dashboard reports the platform, its categories and its colours', async (world) => {
  const offer = await someOffer(world.db);
  await plantClimb(world.db, offer.productId);
  await rollupWindow(world);
  await world.scoring.scoreAll();
  await world.forecasts.forecastAll();
  await world.searchIntel.refresh();
  await world.insights.generate({ window: TrendWindow.D7 });

  const overview = await world.adminDash.overview(TrendWindow.D7);

  assert.ok(overview.headline.views > 0, 'the platform reports no views');

  // Growth is asserted as a *computed number*, not as a positive one.
  //
  // This used to require `viewsGrowthPct > 0` after planting a climb on a
  // single product, which only ever held because the demand tables were
  // empty — one product was the whole platform. Once the trend engine had
  // actually run over the seeded catalogue the platform had its own direction
  // (mildly downward), and one planted product could not outweigh it. The
  // test was measuring the emptiness of the database, not the dashboard.
  //
  // What the plant genuinely supports is asserted below instead: the product
  // that climbed shows up among the ones the platform reports as emerging.
  assert.ok(
    Number.isFinite(overview.headline.viewsGrowthPct),
    `growth should be a computed figure: ${overview.headline.viewsGrowthPct}`,
  );
  assert.ok(
    overview.emergingProducts.some((row) => row.productId === offer.productId),
    'the product that climbed should be reported as emerging',
  );
  assert.ok(overview.categoryTrends.length > 0, 'no category was scored');
  assert.equal(overview.series.length, 14, 'two windows of daily series');
  assert.ok(Array.isArray(overview.colourTrends));
  assert.ok(Array.isArray(overview.priceTrends));
  assert.ok(overview.forecast.horizonDays === 30);

  // Every colour share is a real proportion, not a raw count wearing a %.
  for (const colour of overview.colourTrends) {
    assert.ok(colour.sharePct >= 0 && colour.sharePct <= 100, `${colour.value}: ${colour.sharePct}`);
  }
});

dbTest('a category roll-up includes its descendants, not just its own products', async (world) => {
  const offer = await someOffer(world.db);
  const category = await world.db.category.findUnique({
    where: { id: offer.product.categoryId },
    select: { id: true, parentId: true },
  });
  assert.ok(category);
  if (!category.parentId) return; // A root-level product proves nothing here.

  await plantClimb(world.db, offer.productId, 2);
  await world.collector.rollupDay(utcToday());

  const parent = await world.db.categoryDemandDaily.findUnique({
    where: { categoryId_day: { categoryId: category.parentId, day: utcToday() } },
  });
  assert.ok(parent, 'the parent category has no row of its own');
  assert.ok(parent.views > 0, 'the parent did not inherit its child’s demand');
});

// ── Privacy ──────────────────────────────────────────────────────────────

dbTest('a distinct-viewer count below the k-anonymity floor is stored as zero', async (world) => {
  const offer = await quietOffer(world.db);
  const customers = await world.db.user.findMany({
    where: { role: 'CUSTOMER', disabledAt: null },
    select: { id: true },
    take: 2,
  });
  if (customers.length < 2) return;

  const today = utcToday();
  await world.db.analyticsEvent.createMany({
    data: customers.map((customer) => ({
      type: AnalyticsEventType.PRODUCT_VIEW,
      productId: offer.productId,
      userId: customer.id,
      occurredAt: new Date(today.getTime() + 12 * 3_600_000),
    })),
  });
  await world.collector.rollupDay(today);

  const fact = await world.db.productDemandDaily.findUnique({
    where: { productId_day: { productId: offer.productId, day: today } },
  });
  assert.ok(fact);
  assert.equal(fact.views, 2, 'the views themselves are counted');
  assert.equal(
    fact.viewers,
    0,
    'two identifiable viewers were reported as a distinct count',
  );
});

dbTest('a fact row carries counts and money, and no identity at all', async (world) => {
  const offer = await someOffer(world.db);
  await plantClimb(world.db, offer.productId, 2);
  await world.collector.rollupDay(utcToday());

  const fact = await world.db.productDemandDaily.findUnique({
    where: { productId_day: { productId: offer.productId, day: utcToday() } },
  });
  assert.ok(fact);
  // The schema is the guarantee; this asserts it stays that way.
  const columns = Object.keys(fact);
  for (const forbidden of ['userId', 'sessionId', 'user_id', 'session_id', 'phone']) {
    assert.ok(
      !columns.includes(forbidden),
      `a daily fact row carries ${forbidden}`,
    );
  }
});

// ── Bookkeeping ──────────────────────────────────────────────────────────

dbTest('every stage records a run that says what it wrote', async (world) => {
  const offer = await someOffer(world.db);
  await plantClimb(world.db, offer.productId, 3);
  await world.collector.rollup({ lookbackDays: 3 });
  await world.scoring.scoreAll();

  const runs = await world.db.trendEngineRun.findMany({
    orderBy: { startedAt: 'desc' },
    take: 5,
  });
  assert.ok(runs.length >= 2, 'the stages left no trace');
  for (const run of runs) {
    assert.equal(run.status, 'SUCCEEDED', `${run.kind}: ${run.error ?? ''}`);
    assert.ok(run.finishedAt, `${run.kind} never finished`);
    assert.ok(run.durationMs !== null);
  }
});

dbTest('an insight can be acknowledged by its owner and by nobody else', async (world) => {
  const offer = await someOffer(world.db);
  await plantClimb(world.db, offer.productId);
  await rollupWindow(world);
  await world.scoring.scoreAll();
  await world.insights.generate({ window: TrendWindow.D7 });

  const sellerInsight = await world.db.trendInsight.findFirst({
    where: { audience: TrendInsightAudience.SELLER, sellerId: { not: null } },
  });
  if (!sellerInsight?.sellerId) return;

  const updated = await world.insights.updateStatus(
    sellerInsight.id,
    'ACKNOWLEDGED',
    { id: sellerInsight.sellerId, sellerId: sellerInsight.sellerId },
  );
  assert.equal(updated.status, 'ACKNOWLEDGED');
  assert.equal(updated.acknowledgedBy, sellerInsight.sellerId);

  await assert.rejects(
    () =>
      world.insights.updateStatus(sellerInsight.id, 'DISMISSED', {
        id: 'intruder',
        sellerId: '00000000-0000-0000-0000-000000000000',
      }),
    /not found/i,
    "another seller was able to change someone else's insight",
  );
});
