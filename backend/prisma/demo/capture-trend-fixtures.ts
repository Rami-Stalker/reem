/**
 * Runs the Trend Engine over the seeded shop and captures what it produces.
 *
 *   npx ts-node -r tsconfig-paths/register prisma/demo/capture-trend-fixtures.ts
 *
 * Two jobs, and the second is the point:
 *
 *  1. It **backfills and runs the pipeline** against the demo data, so a
 *     developer opening either dashboard sees real scores rather than an empty
 *     state. Safe to re-run: every write is an upsert keyed on the day.
 *  2. It **writes the two dashboard payloads to `test/fixtures/`**, verbatim,
 *     through the same serializers the controller uses. Those files are what
 *     the Flutter contract test parses — so a renamed field or a Money shape
 *     that stops being `{amount, currency}` fails a test rather than a phone.
 *
 * Fixtures captured from a live pipeline rather than hand-written on purpose:
 * a hand-written fixture only ever proves that the app can parse the fixture.
 */
import { writeFileSync, mkdirSync } from 'node:fs';
import { dirname, resolve } from 'node:path';
import { PrismaClient, TrendWindow } from '@prisma/client';

import { PrismaService } from '../../src/prisma/prisma.service';
import { ExchangeRateService } from '../../src/modules/pricing/exchange-rate.service';
import { SignalCollectorService } from '../../src/modules/trends/collection/signal-collector.service';
import { TrendRunRecorder } from '../../src/modules/trends/collection/trend-run.recorder';
import { AdminTrendsService } from '../../src/modules/trends/dashboards/admin-trends.service';
import { SellerTrendsService } from '../../src/modules/trends/dashboards/seller-trends.service';
import { TrendForecastService } from '../../src/modules/trends/forecasting/trend-forecast.service';
import { DisabledTrendLlm } from '../../src/modules/trends/insights/llm/trend-llm';
import { TrendInsightsService } from '../../src/modules/trends/insights/trend-insights.service';
import { TrendScoringService } from '../../src/modules/trends/scoring/trend-scoring.service';
import { SearchIntelligenceService } from '../../src/modules/trends/search/search-intelligence.service';
import { addDays, utcToday } from '../../src/modules/trends/collection/day';
import { runTrendActivity } from './trend-activity';
import {
  serializeAdminProduct,
  serializeAttributeTrend,
  serializeCategoryTrend,
  serializeForecast,
  serializeInsight,
  serializeSearchTerm,
  serializeSellerProduct,
  serializeUnmetDemand,
} from '../../src/modules/trends/trends.serializer';

const BACKFILL_DAYS = 60;

async function main(): Promise<void> {
  const prisma = new PrismaClient() as unknown as PrismaService;
  const runs = new TrendRunRecorder(prisma);
  const rates = new ExchangeRateService(prisma);
  const collector = new SignalCollectorService(prisma, rates, runs);
  const scoring = new TrendScoringService(prisma, runs);
  const forecasts = new TrendForecastService(prisma, runs);
  const searchIntel = new SearchIntelligenceService(prisma, runs);
  const insights = new TrendInsightsService(prisma, runs, new DisabledTrendLlm());
  const sellerDash = new SellerTrendsService(prisma, forecasts, insights);
  const adminDash = new AdminTrendsService(prisma, forecasts, insights, searchIntel);

  // The engine reads browsing, and only the demo pass produces it. Running
  // it here means the fixtures below are captured from a shop that has been
  // looked at, not just bought from.
  console.log('Planting demo browsing activity…');
  const events = await runTrendActivity(prisma as unknown as PrismaClient);
  console.log(`  ${events} analytics events`);

  const today = utcToday();
  console.log(`Backfilling ${BACKFILL_DAYS} days of facts…`);
  let rows = 0;
  for (let offset = BACKFILL_DAYS - 1; offset >= 0; offset -= 1) {
    rows += await collector.rollupDay(addDays(today, -offset));
    if (offset % 15 === 0) {
      console.log(`  ${BACKFILL_DAYS - offset}/${BACKFILL_DAYS} days, ${rows} rows`);
    }
  }

  console.log('Scoring…');
  const scored = await scoring.scoreAll();
  console.log('Forecasting…');
  const forecasted = await forecasts.forecastAll();
  console.log('Search intelligence…');
  const demand = await searchIntel.refresh();
  console.log('Insights…');
  const written = await insights.generate({ window: TrendWindow.D7 });

  console.log(
    `\n  ${rows} facts · ${scored.products} product scores · ` +
      `${scored.categories} category scores · ${forecasted.rows} forecasts · ` +
      `${demand.signals} demand signals · ` +
      `${written.admin + written.seller} insights\n`,
  );

  // ── The admin payload ──────────────────────────────────────────────────
  const admin = await adminDash.overview(TrendWindow.D7);
  write('test/fixtures/trends_admin_overview.json', {
    as_of: admin.asOf.toISOString().slice(0, 10),
    window: admin.window,
    window_days: admin.windowDays,
    headline: {
      window_days: admin.headline.windowDays,
      views: admin.headline.views,
      previous_views: admin.headline.previousViews,
      views_growth_pct: admin.headline.viewsGrowthPct,
      searches: admin.headline.searches,
      search_growth_pct: admin.headline.searchGrowthPct,
      cart_adds: admin.headline.cartAdds,
      cart_growth_pct: admin.headline.cartGrowthPct,
      orders: admin.headline.orders,
      orders_growth_pct: admin.headline.ordersGrowthPct,
      units: admin.headline.units,
      revenue: { amount: admin.headline.revenueSyp.toFixed(2), currency: 'SYP' },
      revenue_growth_pct: admin.headline.revenueGrowthPct,
      view_to_cart_rate: admin.headline.viewToCartRate,
      cart_to_order_rate: admin.headline.cartToOrderRate,
      stages: admin.headline.stages,
    },
    series: admin.series.map((point) => ({
      date: point.date,
      views: point.views,
      search_hits: point.searchHits,
      cart_adds: point.cartAdds,
      orders: point.orders,
      units: point.units,
      revenue: { amount: point.revenueSyp.toFixed(2), currency: 'SYP' },
    })),
    category_trends: admin.categoryTrends.map(serializeCategoryTrend),
    colour_trends: admin.colourTrends.map(serializeAttributeTrend),
    price_trends: admin.priceTrends.map(serializeAttributeTrend),
    emerging_products: admin.emergingProducts.map(serializeAdminProduct),
    declining_products: admin.decliningProducts.map(serializeAdminProduct),
    search_trends: admin.searchTrends.map(serializeSearchTerm),
    unmet_demand: admin.unmetDemand.map(serializeUnmetDemand),
    unmet_demand_total: admin.unmetDemandTotal,
    forecast: serializeForecast(admin.forecast),
    insights: admin.insights.map(serializeInsight),
  });

  // ── The seller payload ─────────────────────────────────────────────────
  //
  // The seller with the most to be *told*, not the one who sold the most. The
  // page's headline section is the recommended actions, and a fixture of the
  // busiest shop that happens to have a clean week demonstrates none of it.
  const advised = await prisma.trendInsight.groupBy({
    by: ['sellerId'],
    where: { audience: 'SELLER', sellerId: { not: null }, generatedOn: today },
    _count: { _all: true },
    orderBy: { _count: { sellerId: 'desc' } },
    take: 1,
  });
  const busiest = await prisma.sellerDemandDaily.groupBy({
    by: ['sellerId'],
    _sum: { units: true },
    orderBy: { _sum: { units: 'desc' } },
    take: 1,
  });
  const sellerId = advised[0]?.sellerId ?? busiest[0]?.sellerId;
  if (!sellerId) {
    console.warn('No seller has any activity; skipping the seller fixture.');
    await (prisma as unknown as PrismaClient).$disconnect();
    return;
  }

  const seller = await sellerDash.overview(sellerId, TrendWindow.D7);
  write('test/fixtures/trends_seller_overview.json', {
    as_of: seller.asOf.toISOString().slice(0, 10),
    window: seller.window,
    window_days: seller.windowDays,
    headline: {
      units: seller.headline.units,
      previous_units: seller.headline.previousUnits,
      revenue: { amount: seller.headline.revenueSyp.toFixed(2), currency: 'SYP' },
      previous_revenue: {
        amount: seller.headline.previousRevenueSyp.toFixed(2),
        currency: 'SYP',
      },
      views: seller.headline.views,
      average_score: seller.headline.averageScore,
      rising_products: seller.headline.risingProducts,
      declining_products: seller.headline.decliningProducts,
    },
    demand_signals: {
      window_days: seller.demandSignals.windowDays,
      views: seller.demandSignals.views,
      previous_views: seller.demandSignals.previousViews,
      search_hits: seller.demandSignals.searchHits,
      cart_adds: seller.demandSignals.cartAdds,
      favorites: seller.demandSignals.favorites,
      units: seller.demandSignals.units,
    },
    trending_products: seller.trending.map(serializeSellerProduct),
    emerging_products: seller.emerging.map(serializeSellerProduct),
    low_conversion_alerts: seller.lowConversion.map(serializeSellerProduct),
    stock_opportunities: seller.stockOpportunities.map(serializeSellerProduct),
    forecast: serializeForecast(seller.forecast),
    series: seller.series.map((point) => ({
      date: point.date,
      units: point.units,
      orders: point.orders,
      revenue: { amount: point.revenueSyp.toFixed(2), currency: 'SYP' },
    })),
    recommended_actions: seller.insights.map(serializeInsight),
    product_count: seller.productCount,
  });

  await (prisma as unknown as PrismaClient).$disconnect();
}

function write(relative: string, payload: unknown): void {
  // Written relative to the repository root, not to `backend/`.
  const path = resolve(__dirname, '../../..', relative);
  mkdirSync(dirname(path), { recursive: true });
  writeFileSync(path, `${JSON.stringify(payload, null, 2)}\n`, 'utf8');
  console.log(`  wrote ${relative}`);
}

main().catch((error: unknown) => {
  console.error(error);
  process.exitCode = 1;
});
