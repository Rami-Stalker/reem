import { Injectable } from '@nestjs/common';
import {
  Prisma,
  TrendInsightAudience,
  TrendStage,
  TrendSubjectKind,
  TrendWindow,
} from '@prisma/client';
import { PrismaService } from '../../../prisma/prisma.service';
import { addDays, dayKey, lastDays, utcToday } from '../collection/day';
import { TrendForecastService } from '../forecasting/trend-forecast.service';
import { TrendInsightsService } from '../insights/trend-insights.service';
import { TrendScoreMetrics, windowDays } from '../kernel/trend-score';
import { clamp, round, sum } from '../kernel/trend-math';

/**
 * Stage groupings the dashboard buckets by.
 *
 * Typed as `TrendStage[]` rather than inferred: a bare array literal narrows
 * to its own members, and `.includes(someStage)` then fails to compile for
 * every stage not in the literal — which is the opposite of what a membership
 * test is for.
 */
const TRENDING_STAGES: TrendStage[] = [
  TrendStage.EMERGING,
  TrendStage.RISING,
  TrendStage.PEAKING,
];
const RISING_STAGES: TrendStage[] = [TrendStage.EMERGING, TrendStage.RISING];
const FALLING_STAGES: TrendStage[] = [TrendStage.COOLING, TrendStage.DECLINING];

/**
 * The seller's answer to "what should I do today".
 *
 * Every panel here reads pre-computed rows — a score, a forecast, an insight —
 * so the page opens at the same speed whether she sells four products or four
 * hundred, and whether the platform did a hundred orders yesterday or a
 * hundred thousand. Nothing is fitted, scored or aggregated at request time.
 *
 * The one rule that shapes the numbers: **demand is product-level, sales are
 * hers.** Two sellers listing the same handbag compete for one product page,
 * so the views and searches it collects are demand for the bag and both of
 * them should see it. What each of them actually sold, and what each of them
 * has on the shelf, comes from her own rows.
 */
@Injectable()
export class SellerTrendsService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly forecasts: TrendForecastService,
    private readonly insights: TrendInsightsService,
  ) {}

  /** Everything the dashboard needs, in one round trip. */
  async overview(sellerId: string, window: TrendWindow) {
    const asOf = utcToday();
    const days = windowDays(window);

    const [products, insights, forecast, series] = await Promise.all([
      this.products(sellerId, window, { limit: 100 }),
      this.insights.feed({
        audience: TrendInsightAudience.SELLER,
        sellerId,
        limit: 20,
      }),
      this.salesForecast(sellerId, 14),
      this.dailySeries(sellerId, days * 2),
    ]);

    const rows = products.rows;
    const trending = rows
      .filter((row) => TRENDING_STAGES.includes(row.stage))
      .slice(0, 10);
    const emerging = rows
      .filter((row) => row.stage === TrendStage.EMERGING)
      .slice(0, 10);
    const lowConversion = rows
      .filter((row) => row.alerts.lowConversion)
      .sort((a, b) => b.views - a.views)
      .slice(0, 10);
    const stockOpportunities = rows
      .filter((row) => row.alerts.stockRisk || row.alerts.soldOutWithDemand)
      .sort(
        (a, b) => (a.stockoutInDays ?? 999) - (b.stockoutInDays ?? 999),
      )
      .slice(0, 10);

    return {
      asOf,
      window,
      windowDays: days,
      headline: this.headline(rows, series, days),
      trending,
      emerging,
      lowConversion,
      stockOpportunities,
      demandSignals: this.demandSignals(rows, days),
      forecast,
      series,
      insights: insights.rows,
      productCount: products.total,
    };
  }

  /**
   * Her products, scored.
   *
   * The join is `seller_demand_daily` → `product_trend_scores`: the first says
   * which products are hers, the second says what the market thinks of them.
   * A product she stopped listing drops out of the first and therefore off the
   * page, without anything having to remember to remove it.
   */
  async products(
    sellerId: string,
    window: TrendWindow,
    options: { limit?: number; offset?: number; stage?: TrendStage } = {},
  ) {
    const asOf = utcToday();
    const days = windowDays(window);
    const from = addDays(asOf, -(days - 1));

    const mine = await this.prisma.sellerDemandDaily.groupBy({
      by: ['productId'],
      where: { sellerId, day: { gte: addDays(asOf, -90), lte: asOf } },
      _sum: { units: true, revenueSyp: true, orders: true, returns: true, cancels: true },
      _max: { stockUnits: true, priceSyp: true },
    });
    if (!mine.length) return { rows: [], total: 0 };

    const productIds = mine.map((row) => row.productId);
    const mineById = new Map(mine.map((row) => [row.productId, row]));

    // Her own numbers inside the window, separately from the 90-day totals.
    const inWindow = await this.prisma.sellerDemandDaily.groupBy({
      by: ['productId'],
      where: { sellerId, day: { gte: from, lte: asOf } },
      _sum: { units: true, revenueSyp: true, orders: true },
    });
    const windowById = new Map(inWindow.map((row) => [row.productId, row]));

    const scores = await this.prisma.productTrendScore.findMany({
      where: {
        productId: { in: productIds },
        window,
        capturedOn: { gte: addDays(asOf, -7), lte: asOf },
      },
      orderBy: { capturedOn: 'asc' },
      include: {
        product: {
          select: {
            id: true,
            title: true,
            slug: true,
            categoryId: true,
            category: { select: { nameAr: true } },
            media: { orderBy: { sortOrder: 'asc' }, take: 1, select: { url: true } },
          },
        },
      },
    });
    // Ascending, so the last write per product is the freshest capture.
    const latest = new Map<string, (typeof scores)[number]>();
    for (const score of scores) latest.set(score.productId, score);

    const forecastRows = await this.forecasts.latestForMany({
      subjectKind: TrendSubjectKind.PRODUCT,
      subjectKeys: productIds,
      scopeKey: sellerId,
      horizonDays: 14,
      asOf,
    });

    const rows = productIds
      .map((productId) => {
        const score = latest.get(productId);
        if (!score) return null;
        const metrics = score.metrics as unknown as TrendScoreMetrics | null;
        const totals = mineById.get(productId);
        const windowTotals = windowById.get(productId);
        const forecast = forecastRows.get(productId);
        const stockUnits = totals?._max.stockUnits ?? 0;

        const views = metrics?.views ?? 0;
        const cartAdds = metrics?.cartAdds ?? 0;
        const myUnits = windowTotals?._sum.units ?? 0;
        const myOrders = windowTotals?._sum.orders ?? 0;

        return {
          productId,
          title: score.product.title,
          slug: score.product.slug,
          imageUrl: score.product.media[0]?.url ?? null,
          categoryId: score.categoryId,
          categoryNameAr: score.product.category?.nameAr ?? '',
          capturedOn: score.capturedOn,

          score: score.score,
          previousScore: score.previousScore,
          delta: score.delta,
          stage: score.stage,
          confidence: score.confidence,
          rank: score.rank,
          categoryRank: score.categoryRank,
          components: {
            viewGrowth: score.viewGrowth,
            searchGrowth: score.searchGrowth,
            cartGrowth: score.cartGrowth,
            conversion: score.conversion,
            salesVelocity: score.salesVelocity,
            acceleration: score.acceleration,
            engagement: score.engagement,
            quality: score.quality,
            availability: score.availability,
          },

          // Market-wide demand for the product…
          views,
          previousViews: metrics?.previousViews ?? 0,
          searchHits: metrics?.searchHits ?? 0,
          cartAdds,
          favorites: metrics?.favorites ?? 0,
          viewToCartRate: metrics?.viewToCartRate ?? 0,
          cartToOrderRate: metrics?.cartToOrderRate ?? 0,
          viewToOrderRate: metrics?.viewToOrderRate ?? 0,

          // …and her own outcome.
          myUnits,
          myOrders,
          myRevenueSyp: round(Number(windowTotals?._sum.revenueSyp ?? 0), 2),
          lifetimeUnits: totals?._sum.units ?? 0,
          returns: totals?._sum.returns ?? 0,
          stockUnits,
          priceSyp:
            totals?._max.priceSyp === null || totals?._max.priceSyp === undefined
              ? null
              : Number(totals._max.priceSyp),

          forecastUnits: forecast?.totalUnits ?? null,
          forecastHorizonDays: forecast?.horizonDays ?? null,
          forecastConfidence: forecast?.confidence ?? null,
          stockoutInDays: forecast?.stockoutInDays ?? null,

          alerts: {
            // Attention without a sale, on volume worth reacting to.
            lowConversion: views >= 60 && myOrders === 0,
            weakCartThrough: cartAdds >= 10 && (metrics?.cartToOrderRate ?? 0) < 0.15,
            stockRisk:
              (forecast?.stockoutInDays ?? null) !== null &&
              (forecast?.stockoutInDays ?? 999) <= 7,
            soldOutWithDemand: stockUnits === 0 && views >= 30,
            overstock:
              (metrics?.daysOfCover ?? null) !== null &&
              (metrics?.daysOfCover ?? 0) > 90 &&
              stockUnits >= 10,
          },
        };
      })
      .filter((row): row is NonNullable<typeof row> => row !== null)
      .filter((row) => (options.stage ? row.stage === options.stage : true));

    rows.sort((a, b) => b.score - a.score);

    const offset = Math.max(options.offset ?? 0, 0);
    const limit = Math.min(Math.max(options.limit ?? 25, 1), 200);
    return { rows: rows.slice(offset, offset + limit), total: rows.length };
  }

  /** One product, in full, for the detail sheet. */
  async product(sellerId: string, productId: string, window: TrendWindow) {
    const asOf = utcToday();
    const { rows } = await this.products(sellerId, window, { limit: 200 });
    const row = rows.find((entry) => entry.productId === productId);
    if (!row) return null;

    const [history, facts, forecast, insights] = await Promise.all([
      this.prisma.productTrendScore.findMany({
        where: {
          productId,
          window,
          capturedOn: { gte: addDays(asOf, -60), lte: asOf },
        },
        orderBy: { capturedOn: 'asc' },
        select: { capturedOn: true, score: true, stage: true, confidence: true },
      }),
      this.prisma.productDemandDaily.findMany({
        where: {
          productId,
          day: { gte: addDays(asOf, -60), lte: asOf },
        },
        orderBy: { day: 'asc' },
        select: {
          day: true,
          views: true,
          searchHits: true,
          cartAdds: true,
          favorites: true,
          units: true,
          orders: true,
          stockUnits: true,
        },
      }),
      this.forecasts.latest({
        subjectKind: TrendSubjectKind.PRODUCT,
        subjectKey: productId,
        scopeKey: sellerId,
        horizonDays: 30,
        asOf,
      }),
      this.prisma.trendInsight.findMany({
        where: {
          sellerId,
          productId,
          expiresAt: { gte: new Date() },
        },
        orderBy: { priority: 'desc' },
        take: 10,
      }),
    ]);

    return { ...row, history, facts, forecast, insights };
  }

  /**
   * How much she will sell, over `horizonDays`.
   *
   * Summed from her per-product forecasts rather than fitted on her total,
   * because a shop's total is the sum of independent product curves and
   * forecasting the sum throws away every one of them — a new product ramping
   * while an old one dies looks flat in aggregate and is not.
   */
  async salesForecast(sellerId: string, horizonDays = 14) {
    const asOf = utcToday();
    const rows = await this.prisma.trendForecast.findMany({
      where: {
        scopeKey: sellerId,
        subjectKind: TrendSubjectKind.PRODUCT,
        horizonDays,
        generatedOn: { gte: addDays(asOf, -7), lte: asOf },
      },
      orderBy: { generatedOn: 'asc' },
    });
    if (!rows.length) {
      return {
        horizonDays,
        totalUnits: 0,
        totalRevenueSyp: 0,
        confidence: 0,
        points: [] as Array<{ date: string; units: number; low: number; high: number }>,
        products: 0,
        generatedOn: null as Date | null,
      };
    }

    const latest = new Map<string, (typeof rows)[number]>();
    for (const row of rows) latest.set(row.subjectKey, row);

    // Add the per-product curves day by day, so the shop's chart is the sum of
    // its parts and the two never disagree.
    const byDate = new Map<string, { units: number; low: number; high: number }>();
    let totalUnits = 0;
    let totalRevenue = 0;
    const confidences: number[] = [];

    for (const row of latest.values()) {
      totalUnits += row.totalUnits;
      totalRevenue += Number(row.totalRevenueSyp);
      confidences.push(row.confidence);
      for (const point of forecastPoints(row.points)) {
        const cell = byDate.get(point.date) ?? { units: 0, low: 0, high: 0 };
        cell.units += point.units;
        cell.low += point.low;
        cell.high += point.high;
        byDate.set(point.date, cell);
      }
    }

    const points = [...byDate.entries()]
      .sort(([a], [b]) => a.localeCompare(b))
      .map(([date, cell]) => ({
        date,
        units: round(cell.units, 2),
        low: round(cell.low, 2),
        high: round(cell.high, 2),
      }));

    return {
      horizonDays,
      totalUnits: round(totalUnits, 2),
      totalRevenueSyp: round(totalRevenue, 2),
      // Units-weighted: a confident forecast of two units should not drag down
      // a shop whose volume is somewhere else.
      confidence: round(
        clamp(
          totalUnits > 0
            ? [...latest.values()].reduce(
                (acc, row) => acc + row.confidence * row.totalUnits,
                0,
              ) / totalUnits
            : sum(confidences) / Math.max(confidences.length, 1),
        ),
        3,
      ),
      points,
      products: latest.size,
      generatedOn: [...latest.values()][0]?.generatedOn ?? null,
    };
  }

  // ── Internals ──────────────────────────────────────────────────────────

  /** Her daily units and revenue, for the sparkline under the headline. */
  private async dailySeries(sellerId: string, days: number) {
    const asOf = utcToday();
    const calendar = lastDays(asOf, days);
    const facts = await this.prisma.sellerDemandDaily.groupBy({
      by: ['day'],
      where: { sellerId, day: { gte: calendar[0], lte: asOf } },
      _sum: { units: true, revenueSyp: true, orders: true },
    });
    const byDay = new Map(facts.map((row) => [dayKey(row.day), row]));

    return calendar.map((date) => {
      const row = byDay.get(dayKey(date));
      return {
        date: dayKey(date),
        units: row?._sum.units ?? 0,
        orders: row?._sum.orders ?? 0,
        revenueSyp: round(Number(row?._sum.revenueSyp ?? 0), 2),
      };
    });
  }

  private headline(
    rows: Array<{ score: number; stage: TrendStage; views: number }>,
    series: Array<{ units: number; revenueSyp: number }>,
    days: number,
  ) {
    const current = series.slice(-days);
    const previous = series.slice(-days * 2, -days);
    const units = sum(current.map((row) => row.units));
    const previousUnits = sum(previous.map((row) => row.units));
    const revenue = sum(current.map((row) => row.revenueSyp));
    const previousRevenue = sum(previous.map((row) => row.revenueSyp));

    return {
      units,
      previousUnits,
      revenueSyp: round(revenue, 2),
      previousRevenueSyp: round(previousRevenue, 2),
      views: sum(rows.map((row) => row.views)),
      averageScore: rows.length
        ? round(sum(rows.map((row) => row.score)) / rows.length, 1)
        : 0,
      risingProducts: rows.filter((row) => RISING_STAGES.includes(row.stage))
        .length,
      decliningProducts: rows.filter((row) =>
        FALLING_STAGES.includes(row.stage),
      ).length,
    };
  }

  /**
   * The demand side of her shop in five numbers, with the window-over-window
   * change beside each. This is the panel that answers "is interest growing?"
   * separately from "did I sell more", which are different questions and are
   * routinely confused.
   */
  private demandSignals(
    rows: Array<{
      views: number;
      previousViews: number;
      searchHits: number;
      cartAdds: number;
      favorites: number;
      myUnits: number;
    }>,
    windowDaysCount: number,
  ) {
    const views = sum(rows.map((row) => row.views));
    const previousViews = sum(rows.map((row) => row.previousViews));
    return {
      windowDays: windowDaysCount,
      views,
      previousViews,
      searchHits: sum(rows.map((row) => row.searchHits)),
      cartAdds: sum(rows.map((row) => row.cartAdds)),
      favorites: sum(rows.map((row) => row.favorites)),
      units: sum(rows.map((row) => row.myUnits)),
    };
  }
}

/** `TrendForecast.points`, validated on the way out of JSON. */
export function forecastPoints(
  value: Prisma.JsonValue | null,
): Array<{ date: string; units: number; low: number; high: number }> {
  if (!Array.isArray(value)) return [];
  return value.flatMap((entry) => {
    if (!entry || typeof entry !== 'object' || Array.isArray(entry)) return [];
    const row = entry as Record<string, unknown>;
    if (typeof row.date !== 'string' || typeof row.units !== 'number') return [];
    return [
      {
        date: row.date,
        units: row.units,
        low: typeof row.low === 'number' ? row.low : row.units,
        high: typeof row.high === 'number' ? row.high : row.units,
      },
    ];
  });
}
