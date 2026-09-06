import { Injectable } from '@nestjs/common';
import {
  TrendAttributeDimension,
  TrendInsightAudience,
  TrendStage,
  TrendSubjectKind,
  TrendWindow,
} from '@prisma/client';
import { PrismaService } from '../../../prisma/prisma.service';
import { addDays, dayKey, lastDays, utcToday } from '../collection/day';
import { TrendForecastService } from '../forecasting/trend-forecast.service';
import { TrendInsightsService } from '../insights/trend-insights.service';
import { SearchIntelligenceService } from '../search/search-intelligence.service';
import { TrendScoreMetrics, windowDays } from '../kernel/trend-score';
import { growthPct } from '../kernel/insight-rules';
import { round, sum } from '../kernel/trend-math';
import { PLATFORM_SCOPE } from '../trend.constants';
import { forecastPoints } from './seller-trends.service';

/**
 * The market, from the platform's chair.
 *
 * Where the seller dashboard answers "what should I do about my products", this
 * answers "what is happening to demand" — which is a different question and is
 * mostly asked one level up from a product: a category, a colour, a price band,
 * a search term nobody could answer.
 *
 * Like the seller's, every panel reads a pre-computed row. The heaviest query
 * in this file is a `groupBy` over a window of the fact tables, which is
 * bounded by the size of the catalogue rather than by traffic.
 */
@Injectable()
export class AdminTrendsService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly forecasts: TrendForecastService,
    private readonly insights: TrendInsightsService,
    private readonly searchIntel: SearchIntelligenceService,
  ) {}

  async overview(window: TrendWindow) {
    const asOf = utcToday();
    const days = windowDays(window);

    const [
      headline,
      categories,
      colours,
      priceBands,
      emerging,
      declining,
      searchTrends,
      unmet,
      forecast,
      insights,
      series,
    ] = await Promise.all([
      this.headline(days),
      this.categoryTrends(window, 12),
      this.attributeTrends(TrendAttributeDimension.COLOR, days, PLATFORM_SCOPE, 12),
      this.attributeTrends(TrendAttributeDimension.PRICE_BAND, days, PLATFORM_SCOPE, 8),
      this.products(window, { stage: TrendStage.EMERGING, limit: 12 }),
      this.products(window, { stage: TrendStage.DECLINING, limit: 12 }),
      this.searchIntel.risingTerms({ windowDays: 30, limit: 12 }),
      this.searchIntel.unmetDemand({ limit: 10 }),
      this.demandForecast(30),
      this.insights.feed({ audience: TrendInsightAudience.ADMIN, limit: 20 }),
      this.platformSeries(days * 2),
    ]);

    return {
      asOf,
      window,
      windowDays: days,
      headline,
      series,
      categoryTrends: categories,
      colourTrends: colours,
      priceTrends: priceBands,
      emergingProducts: emerging.rows,
      decliningProducts: declining.rows,
      searchTrends,
      unmetDemand: unmet.rows,
      unmetDemandTotal: unmet.total,
      forecast,
      insights: insights.rows,
    };
  }

  // ── Overall ────────────────────────────────────────────────────────────

  private async headline(days: number) {
    const asOf = utcToday();
    const currentFrom = addDays(asOf, -(days - 1));
    const previousFrom = addDays(currentFrom, -days);

    const [current, previous, stages] = await Promise.all([
      this.totals(currentFrom, asOf),
      this.totals(previousFrom, addDays(currentFrom, -1)),
      this.stageCounts(asOf, days),
    ]);

    return {
      windowDays: days,
      views: current.views,
      previousViews: previous.views,
      viewsGrowthPct: growthPct(current.views, previous.views),
      searches: current.searchHits,
      previousSearches: previous.searchHits,
      searchGrowthPct: growthPct(current.searchHits, previous.searchHits),
      cartAdds: current.cartAdds,
      cartGrowthPct: growthPct(current.cartAdds, previous.cartAdds),
      orders: current.orders,
      ordersGrowthPct: growthPct(current.orders, previous.orders),
      units: current.units,
      revenueSyp: current.revenueSyp,
      previousRevenueSyp: previous.revenueSyp,
      revenueGrowthPct: growthPct(current.revenueSyp, previous.revenueSyp),
      // The funnel, platform-wide. The two rates a merchandiser watches.
      viewToCartRate:
        current.views > 0 ? round(current.cartAdds / current.views, 4) : 0,
      cartToOrderRate:
        current.cartAdds > 0 ? round(current.orders / current.cartAdds, 4) : 0,
      stages,
    };
  }

  private async totals(from: Date, to: Date) {
    const row = await this.prisma.productDemandDaily.aggregate({
      where: { day: { gte: from, lte: to } },
      _sum: {
        views: true,
        searchHits: true,
        cartAdds: true,
        favorites: true,
        orders: true,
        units: true,
        revenueSyp: true,
        returns: true,
      },
    });
    return {
      views: row._sum.views ?? 0,
      searchHits: row._sum.searchHits ?? 0,
      cartAdds: row._sum.cartAdds ?? 0,
      favorites: row._sum.favorites ?? 0,
      orders: row._sum.orders ?? 0,
      units: row._sum.units ?? 0,
      revenueSyp: round(Number(row._sum.revenueSyp ?? 0), 2),
      returns: row._sum.returns ?? 0,
    };
  }

  /** How the catalogue is distributed across the curve. */
  private async stageCounts(asOf: Date, days: number) {
    const window =
      days <= 7 ? TrendWindow.D7 : days <= 14 ? TrendWindow.D14 : TrendWindow.D30;
    const rows = await this.prisma.productTrendScore.groupBy({
      by: ['stage'],
      where: { window, capturedOn: asOf },
      _count: { _all: true },
    });
    const counts: Record<string, number> = {};
    for (const stage of Object.values(TrendStage)) counts[stage] = 0;
    for (const row of rows) counts[row.stage] = row._count._all;
    return counts;
  }

  private async platformSeries(days: number) {
    const asOf = utcToday();
    const calendar = lastDays(asOf, days);
    const rows = await this.prisma.productDemandDaily.groupBy({
      by: ['day'],
      where: { day: { gte: calendar[0], lte: asOf } },
      _sum: {
        views: true,
        searchHits: true,
        cartAdds: true,
        orders: true,
        units: true,
        revenueSyp: true,
      },
    });
    const byDay = new Map(rows.map((row) => [dayKey(row.day), row]));

    return calendar.map((date) => {
      const row = byDay.get(dayKey(date));
      return {
        date: dayKey(date),
        views: row?._sum.views ?? 0,
        searchHits: row?._sum.searchHits ?? 0,
        cartAdds: row?._sum.cartAdds ?? 0,
        orders: row?._sum.orders ?? 0,
        units: row?._sum.units ?? 0,
        revenueSyp: round(Number(row?._sum.revenueSyp ?? 0), 2),
      };
    });
  }

  // ── Categories ─────────────────────────────────────────────────────────

  async categoryTrends(window: TrendWindow, limit = 25) {
    const asOf = utcToday();
    const rows = await this.prisma.categoryTrendScore.findMany({
      where: { window, capturedOn: { gte: addDays(asOf, -7), lte: asOf } },
      orderBy: { capturedOn: 'asc' },
      include: {
        category: {
          select: { id: true, nameAr: true, nameEn: true, slug: true, level: true, parentId: true },
        },
      },
    });
    const latest = new Map<string, (typeof rows)[number]>();
    for (const row of rows) latest.set(row.categoryId, row);

    const facts = await this.prisma.categoryDemandDaily.findMany({
      where: { day: asOf, categoryId: { in: [...latest.keys()] } },
      select: {
        categoryId: true,
        liveProducts: true,
        inStockProducts: true,
        medianPriceSyp: true,
      },
    });
    const shelf = new Map(facts.map((row) => [row.categoryId, row]));

    return [...latest.values()]
      .map((row) => {
        const metrics = row.metrics as unknown as TrendScoreMetrics | null;
        const supply = shelf.get(row.categoryId);
        return {
          categoryId: row.categoryId,
          nameAr: row.category?.nameAr ?? '',
          nameEn: row.category?.nameEn ?? '',
          slug: row.category?.slug ?? '',
          level: row.category?.level ?? 0,
          parentId: row.category?.parentId ?? null,
          score: row.score,
          previousScore: row.previousScore,
          delta: row.delta,
          stage: row.stage,
          confidence: row.confidence,
          rank: row.rank,
          views: metrics?.views ?? 0,
          viewsGrowthPct: growthPct(metrics?.views ?? 0, metrics?.previousViews ?? 0),
          units: metrics?.units ?? 0,
          unitsGrowthPct: growthPct(metrics?.units ?? 0, metrics?.previousUnits ?? 0),
          revenueSyp: metrics?.revenueSyp ?? 0,
          liveProducts: supply?.liveProducts ?? 0,
          inStockProducts: supply?.inStockProducts ?? 0,
          medianPriceSyp:
            supply?.medianPriceSyp === null || supply?.medianPriceSyp === undefined
              ? null
              : Number(supply.medianPriceSyp),
        };
      })
      .sort((a, b) => b.score - a.score)
      .slice(0, Math.min(Math.max(limit, 1), 200));
  }

  // ── Colours, price bands, brands ───────────────────────────────────────

  /**
   * A facet's movement, reported as a **share shift** as well as a growth
   * rate.
   *
   * The share is what makes the claim meaningful. In a week when the whole
   * platform is up forty percent, every colour is up forty percent, and
   * "الأسود ارتفع" is then a statement about the week. A colour whose share of
   * demand went from 22% to 34% has actually taken something from the others,
   * and that is the sentence a buyer can act on.
   */
  async attributeTrends(
    dimension: TrendAttributeDimension,
    days: number,
    scopeKey = PLATFORM_SCOPE,
    limit = 20,
  ) {
    const asOf = utcToday();
    const currentFrom = addDays(asOf, -(days - 1));
    const previousFrom = addDays(currentFrom, -days);

    const [current, previous] = await Promise.all([
      this.attributeTotals(dimension, scopeKey, currentFrom, asOf),
      this.attributeTotals(
        dimension,
        scopeKey,
        previousFrom,
        addDays(currentFrom, -1),
      ),
    ]);

    const total = sum([...current.values()].map((row) => row.demand));
    const previousTotal = sum([...previous.values()].map((row) => row.demand));

    return [...current.entries()]
      .map(([value, row]) => {
        const before = previous.get(value);
        const share = total > 0 ? row.demand / total : 0;
        const previousShare =
          previousTotal > 0 ? (before?.demand ?? 0) / previousTotal : 0;
        return {
          dimension,
          value,
          labelAr: row.labelAr,
          scopeKey,
          views: row.views,
          cartAdds: row.cartAdds,
          orders: row.orders,
          units: row.units,
          revenueSyp: row.revenueSyp,
          products: row.products,
          demand: row.demand,
          previousDemand: before?.demand ?? 0,
          growthPct: growthPct(row.demand, before?.demand ?? 0),
          sharePct: round(share * 100, 2),
          previousSharePct: round(previousShare * 100, 2),
          shareDeltaPct: round((share - previousShare) * 100, 2),
          windowDays: days,
        };
      })
      .sort((a, b) => b.demand - a.demand)
      .slice(0, Math.min(Math.max(limit, 1), 100));
  }

  private async attributeTotals(
    dimension: TrendAttributeDimension,
    scopeKey: string,
    from: Date,
    to: Date,
  ) {
    const rows = await this.prisma.trendAttributeDaily.groupBy({
      by: ['value'],
      where: { dimension, scopeKey, day: { gte: from, lte: to } },
      _sum: {
        views: true,
        cartAdds: true,
        favorites: true,
        orders: true,
        units: true,
        revenueSyp: true,
      },
      _max: { products: true },
    });
    const labels = await this.prisma.trendAttributeDaily.findMany({
      where: { dimension, scopeKey, day: { gte: from, lte: to } },
      select: { value: true, labelAr: true },
      distinct: ['value'],
    });
    const labelFor = new Map(labels.map((row) => [row.value, row.labelAr]));

    return new Map(
      rows.map((row) => [
        row.value,
        {
          labelAr: labelFor.get(row.value) ?? row.value,
          views: row._sum.views ?? 0,
          cartAdds: row._sum.cartAdds ?? 0,
          orders: row._sum.orders ?? 0,
          units: row._sum.units ?? 0,
          revenueSyp: round(Number(row._sum.revenueSyp ?? 0), 2),
          products: row._max.products ?? 0,
          // Attention plus intent. Views alone follow whatever the home page
          // featured; a cart add is worth five of them.
          demand: (row._sum.views ?? 0) + (row._sum.cartAdds ?? 0) * 5,
        },
      ]),
    );
  }

  // ── Products ───────────────────────────────────────────────────────────

  async products(
    window: TrendWindow,
    options: {
      stage?: TrendStage;
      categoryId?: string;
      limit?: number;
      offset?: number;
      minConfidence?: number;
    } = {},
  ) {
    const asOf = utcToday();
    const take = Math.min(Math.max(options.limit ?? 25, 1), 200);

    const where = {
      window,
      capturedOn: asOf,
      ...(options.stage ? { stage: options.stage } : {}),
      ...(options.categoryId ? { categoryId: options.categoryId } : {}),
      ...(options.minConfidence
        ? { confidence: { gte: options.minConfidence } }
        : {}),
    };

    const [rows, total] = await Promise.all([
      this.prisma.productTrendScore.findMany({
        where,
        // Declining products are interesting from the *bottom* of the
        // leaderboard, so the sort follows the question being asked.
        orderBy:
          options.stage === TrendStage.DECLINING
            ? [{ delta: 'asc' }]
            : [{ score: 'desc' }],
        skip: Math.max(options.offset ?? 0, 0),
        take,
        include: {
          product: {
            select: {
              id: true,
              title: true,
              slug: true,
              category: { select: { id: true, nameAr: true } },
              media: { orderBy: { sortOrder: 'asc' }, take: 1, select: { url: true } },
              offers: {
                where: { isActive: true, status: 'ACTIVE' },
                select: { sellerId: true, seller: { select: { name: true } } },
                take: 3,
              },
            },
          },
        },
      }),
      this.prisma.productTrendScore.count({ where }),
    ]);

    return {
      total,
      rows: rows.map((row) => {
        const metrics = row.metrics as unknown as TrendScoreMetrics | null;
        return {
          productId: row.productId,
          title: row.product.title,
          slug: row.product.slug,
          imageUrl: row.product.media[0]?.url ?? null,
          categoryId: row.categoryId,
          categoryNameAr: row.product.category?.nameAr ?? '',
          sellers: row.product.offers.map((offer) => ({
            id: offer.sellerId,
            name: offer.seller?.name ?? '',
          })),
          score: row.score,
          previousScore: row.previousScore,
          delta: row.delta,
          stage: row.stage,
          confidence: row.confidence,
          rank: row.rank,
          categoryRank: row.categoryRank,
          views: metrics?.views ?? 0,
          viewsGrowthPct: growthPct(metrics?.views ?? 0, metrics?.previousViews ?? 0),
          searchHits: metrics?.searchHits ?? 0,
          cartAdds: metrics?.cartAdds ?? 0,
          units: metrics?.units ?? 0,
          unitsGrowthPct: growthPct(metrics?.units ?? 0, metrics?.previousUnits ?? 0),
          revenueSyp: metrics?.revenueSyp ?? 0,
          viewToOrderRate: metrics?.viewToOrderRate ?? 0,
          stockUnits: metrics?.stockUnits ?? 0,
          daysOfCover: metrics?.daysOfCover ?? null,
          components: {
            viewGrowth: row.viewGrowth,
            searchGrowth: row.searchGrowth,
            cartGrowth: row.cartGrowth,
            conversion: row.conversion,
            salesVelocity: row.salesVelocity,
            acceleration: row.acceleration,
            engagement: row.engagement,
            quality: row.quality,
            availability: row.availability,
          },
        };
      }),
    };
  }

  /** One product's whole story, for the admin drill-down. */
  async product(productId: string, window: TrendWindow) {
    const asOf = utcToday();
    const [score, history, facts, forecast, insights] = await Promise.all([
      this.prisma.productTrendScore.findFirst({
        where: { productId, window, capturedOn: { lte: asOf } },
        orderBy: { capturedOn: 'desc' },
        include: {
          product: {
            select: {
              id: true,
              title: true,
              slug: true,
              category: { select: { id: true, nameAr: true } },
            },
          },
        },
      }),
      this.prisma.productTrendScore.findMany({
        where: { productId, window, capturedOn: { gte: addDays(asOf, -90) } },
        orderBy: { capturedOn: 'asc' },
        select: { capturedOn: true, score: true, stage: true, confidence: true, rank: true },
      }),
      this.prisma.productDemandDaily.findMany({
        where: { productId, day: { gte: addDays(asOf, -90), lte: asOf } },
        orderBy: { day: 'asc' },
      }),
      this.forecasts.latest({
        subjectKind: TrendSubjectKind.PRODUCT,
        subjectKey: productId,
        scopeKey: PLATFORM_SCOPE,
        horizonDays: 30,
        asOf,
      }),
      this.prisma.trendInsight.findMany({
        where: { productId, expiresAt: { gte: new Date() } },
        orderBy: { priority: 'desc' },
        take: 10,
      }),
    ]);

    if (!score) return null;
    return { score, history, facts, forecast, insights };
  }

  // ── Forecast ───────────────────────────────────────────────────────────

  async demandForecast(horizonDays = 30) {
    const asOf = utcToday();
    const row = await this.forecasts.latest({
      subjectKind: TrendSubjectKind.PLATFORM,
      subjectKey: PLATFORM_SCOPE,
      scopeKey: PLATFORM_SCOPE,
      horizonDays,
      asOf,
    });
    if (!row) {
      return {
        horizonDays,
        totalUnits: 0,
        totalRevenueSyp: 0,
        confidence: 0,
        method: null as string | null,
        points: [] as ReturnType<typeof forecastPoints>,
        generatedOn: null as Date | null,
      };
    }
    return {
      horizonDays,
      totalUnits: row.totalUnits,
      totalRevenueSyp: round(Number(row.totalRevenueSyp), 2),
      confidence: row.confidence,
      method: row.method,
      backtestMae: row.backtestMae,
      points: forecastPoints(row.points),
      generatedOn: row.generatedOn,
    };
  }

  // ── Sellers ────────────────────────────────────────────────────────────

  /**
   * Who is growing and who is not.
   *
   * Cancellation and return rates sit beside the growth on purpose: a seller
   * doubling her units while a fifth of them come back is not the same story
   * as one doubling cleanly, and a leaderboard that shows only the first
   * number rewards the wrong behaviour.
   */
  async sellerPerformance(days: number, limit = 25) {
    const asOf = utcToday();
    const currentFrom = addDays(asOf, -(days - 1));
    const previousFrom = addDays(currentFrom, -days);

    const [current, previous] = await Promise.all([
      this.sellerTotals(currentFrom, asOf),
      this.sellerTotals(previousFrom, addDays(currentFrom, -1)),
    ]);
    if (!current.size) return [];

    const sellers = await this.prisma.user.findMany({
      where: { id: { in: [...current.keys()] } },
      select: { id: true, name: true, username: true, imageUrl: true },
    });
    const profile = new Map(sellers.map((row) => [row.id, row]));

    return [...current.entries()]
      .map(([sellerId, row]) => {
        const before = previous.get(sellerId);
        const settled = row.units + row.cancels;
        return {
          sellerId,
          name: profile.get(sellerId)?.name ?? '',
          username: profile.get(sellerId)?.username ?? '',
          imageUrl: profile.get(sellerId)?.imageUrl ?? null,
          units: row.units,
          previousUnits: before?.units ?? 0,
          unitsGrowthPct: growthPct(row.units, before?.units ?? 0),
          orders: row.orders,
          revenueSyp: row.revenueSyp,
          previousRevenueSyp: before?.revenueSyp ?? 0,
          revenueGrowthPct: growthPct(row.revenueSyp, before?.revenueSyp ?? 0),
          cancelRate: settled > 0 ? round(row.cancels / settled, 4) : 0,
          returnRate: row.units > 0 ? round(row.returns / row.units, 4) : 0,
          liveProducts: row.liveProducts,
          windowDays: days,
        };
      })
      .sort((a, b) => b.revenueSyp - a.revenueSyp)
      .slice(0, Math.min(Math.max(limit, 1), 200));
  }

  private async sellerTotals(from: Date, to: Date) {
    const rows = await this.prisma.sellerDemandDaily.groupBy({
      by: ['sellerId'],
      where: { day: { gte: from, lte: to } },
      _sum: {
        units: true,
        orders: true,
        revenueSyp: true,
        cancels: true,
        returns: true,
      },
      _count: { productId: true },
    });
    return new Map(
      rows.map((row) => [
        row.sellerId,
        {
          units: row._sum.units ?? 0,
          orders: row._sum.orders ?? 0,
          revenueSyp: round(Number(row._sum.revenueSyp ?? 0), 2),
          cancels: row._sum.cancels ?? 0,
          returns: row._sum.returns ?? 0,
          liveProducts: row._count.productId,
        },
      ]),
    );
  }

  // ── Market opportunities ───────────────────────────────────────────────

  /**
   * Where the money is not being made.
   *
   * Three shapes of gap, ranked together so a merchandiser reads one list
   * instead of cross-referencing three:
   *
   *  - a **category** whose demand is climbing while most of its shelf is
   *    empty,
   *  - a **search** the catalogue cannot answer at all,
   *  - a **price band** taking share the assortment is thin in.
   */
  async opportunities(window: TrendWindow, limit = 20) {
    const days = windowDays(window);
    const [categories, unmet, bands] = await Promise.all([
      this.categoryTrends(window, 60),
      this.searchIntel.unmetDemand({ limit: 30 }),
      this.attributeTrends(
        TrendAttributeDimension.PRICE_BAND,
        days,
        PLATFORM_SCOPE,
        10,
      ),
    ]);

    const rows: Array<{
      kind: 'CATEGORY_GAP' | 'UNMET_SEARCH' | 'PRICE_BAND_GAP';
      titleAr: string;
      detailAr: string;
      score: number;
      subjectId: string | null;
      metrics: Record<string, number | string | null>;
    }> = [];

    for (const category of categories) {
      const inStockRate = category.liveProducts
        ? category.inStockProducts / category.liveProducts
        : 1;
      const rising =
        category.stage === TrendStage.RISING || category.stage === TrendStage.EMERGING;
      if (!rising || inStockRate >= 0.6 || category.liveProducts < 5) continue;
      rows.push({
        kind: 'CATEGORY_GAP',
        titleAr: category.nameAr,
        detailAr:
          `الطلب يرتفع (${category.viewsGrowthPct}٪ مشاهدات) ومتوفر فعليًا ` +
          `${category.inStockProducts} من ${category.liveProducts} منتجًا فقط.`,
        score: round(category.score * (1 - inStockRate), 2),
        subjectId: category.categoryId,
        metrics: {
          views_growth_pct: category.viewsGrowthPct,
          live_products: category.liveProducts,
          in_stock_products: category.inStockProducts,
          in_stock_rate: round(inStockRate, 3),
        },
      });
    }

    for (const signal of unmet.rows) {
      rows.push({
        kind: 'UNMET_SEARCH',
        titleAr: signal.display,
        detailAr: signal.suggestionAr ?? '',
        score: signal.demandScore,
        subjectId: signal.suggestedCategoryId,
        metrics: {
          searches: signal.searches,
          miss_rate: signal.missRate,
          demand_score: signal.demandScore,
        },
      });
    }

    for (const band of bands) {
      if (band.shareDeltaPct < 4) continue;
      rows.push({
        kind: 'PRICE_BAND_GAP',
        titleAr: band.labelAr,
        detailAr:
          `حصّة هذا النطاق من الطلب ارتفعت من ${band.previousSharePct}٪ ` +
          `إلى ${band.sharePct}٪ عبر ${band.products} منتجًا فقط.`,
        score: round(band.shareDeltaPct * 4, 2),
        subjectId: null,
        metrics: {
          share_pct: band.sharePct,
          previous_share_pct: band.previousSharePct,
          share_delta_pct: band.shareDeltaPct,
          products: band.products,
        },
      });
    }

    return rows
      .sort((a, b) => b.score - a.score)
      .slice(0, Math.min(Math.max(limit, 1), 100));
  }
}
