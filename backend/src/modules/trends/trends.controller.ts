import {
  Body,
  Controller,
  ForbiddenException,
  Get,
  HttpCode,
  HttpStatus,
  NotFoundException,
  Param,
  ParseUUIDPipe,
  Patch,
  Post,
  Query,
} from '@nestjs/common';
import {
  TrendAttributeDimension,
  TrendInsightAudience,
  UserRole,
} from '@prisma/client';
import { CurrentUser, AuthUser } from '../../common/decorators/current-user.decorator';
import { Permissions } from '../../common/decorators/permissions.decorator';
import { Roles } from '../../common/decorators/roles.decorator';
import { AppPermission } from '../../common/permissions';
import { PLATFORM_SCOPE } from './trend.constants';
import { AdminTrendsService } from './dashboards/admin-trends.service';
import { SellerTrendsService } from './dashboards/seller-trends.service';
import { TrendInsightsService } from './insights/trend-insights.service';
import { SearchIntelligenceService } from './search/search-intelligence.service';
import { TrendRunRecorder } from './collection/trend-run.recorder';
import { TrendsOrchestrator } from './trends.orchestrator';
import {
  AdminProductTrendsDto,
  AttributeTrendsDto,
  ForecastQueryDto,
  InsightFeedDto,
  RecomputeDto,
  ReviewUnmetDemandDto,
  SearchTrendsDto,
  SellerPerformanceDto,
  SellerProductTrendsDto,
  TrendListDto,
  TrendWindowDto,
  UnmetDemandQueryDto,
  UpdateInsightStatusDto,
} from './dto/trends.dto';
import {
  serializeAdminProduct,
  serializeAttributeTrend,
  serializeCategoryTrend,
  serializeForecast,
  serializeInsight,
  serializeRun,
  serializeSearchTerm,
  serializeSellerProduct,
  serializeUnmetDemand,
} from './trends.serializer';

/**
 * `/trends` — the Reem Trend Engine's read surface.
 *
 * Split into two trees rather than one parameterised by role, because they are
 * genuinely different products:
 *
 *  - `/trends/seller/*` is **always scoped to the caller.** No seller id is
 *    accepted on any route, and none would be honoured; the id comes from the
 *    token. There is therefore no path by which one seller can read another's
 *    numbers, and no reviewer has to check that a guard was applied correctly
 *    on every handler.
 *  - `/trends/admin/*` is platform-wide and gated on `analytics:read`, the
 *    permission the existing analytics dashboard already uses, plus the new
 *    `trends:manage` for the two routes that write.
 *
 * Every handler returns pre-computed rows. Nothing here fits a model, scores a
 * product or aggregates a raw event stream — that all happened last night, in
 * the scheduler.
 */
@Controller('trends')
export class TrendsController {
  constructor(
    private readonly sellerTrends: SellerTrendsService,
    private readonly adminTrends: AdminTrendsService,
    private readonly insights: TrendInsightsService,
    private readonly searchIntel: SearchIntelligenceService,
    private readonly orchestrator: TrendsOrchestrator,
    private readonly runs: TrendRunRecorder,
  ) {}

  // ══════════════════════ Seller ══════════════════════

  @Roles(UserRole.SELLER)
  @Get('seller/overview')
  async sellerOverview(
    @CurrentUser('id') sellerId: string,
    @Query() query: TrendWindowDto,
  ) {
    const data = await this.sellerTrends.overview(sellerId, query.window);
    return {
      as_of: data.asOf.toISOString().slice(0, 10),
      window: data.window,
      window_days: data.windowDays,
      headline: {
        units: data.headline.units,
        previous_units: data.headline.previousUnits,
        revenue: { amount: data.headline.revenueSyp.toFixed(2), currency: 'SYP' },
        previous_revenue: {
          amount: data.headline.previousRevenueSyp.toFixed(2),
          currency: 'SYP',
        },
        views: data.headline.views,
        average_score: data.headline.averageScore,
        rising_products: data.headline.risingProducts,
        declining_products: data.headline.decliningProducts,
      },
      demand_signals: {
        window_days: data.demandSignals.windowDays,
        views: data.demandSignals.views,
        previous_views: data.demandSignals.previousViews,
        search_hits: data.demandSignals.searchHits,
        cart_adds: data.demandSignals.cartAdds,
        favorites: data.demandSignals.favorites,
        units: data.demandSignals.units,
      },
      trending_products: data.trending.map(serializeSellerProduct),
      emerging_products: data.emerging.map(serializeSellerProduct),
      low_conversion_alerts: data.lowConversion.map(serializeSellerProduct),
      stock_opportunities: data.stockOpportunities.map(serializeSellerProduct),
      forecast: serializeForecast(data.forecast),
      series: data.series.map((point) => ({
        date: point.date,
        units: point.units,
        orders: point.orders,
        revenue: { amount: point.revenueSyp.toFixed(2), currency: 'SYP' },
      })),
      recommended_actions: data.insights.map(serializeInsight),
      product_count: data.productCount,
    };
  }

  @Roles(UserRole.SELLER)
  @Get('seller/products')
  async sellerProducts(
    @CurrentUser('id') sellerId: string,
    @Query() query: SellerProductTrendsDto,
  ) {
    const { rows, total } = await this.sellerTrends.products(
      sellerId,
      query.window,
      { limit: query.limit, offset: query.offset, stage: query.stage },
    );
    return {
      data: rows.map(serializeSellerProduct),
      pagination: { total, limit: query.limit, offset: query.offset },
    };
  }

  @Roles(UserRole.SELLER)
  @Get('seller/products/:productId')
  async sellerProduct(
    @CurrentUser('id') sellerId: string,
    @Param('productId', ParseUUIDPipe) productId: string,
    @Query() query: TrendWindowDto,
  ) {
    const row = await this.sellerTrends.product(sellerId, productId, query.window);
    // Not "forbidden": a seller asking about a product she does not list should
    // not be able to learn from the status code that it exists.
    if (!row) throw new NotFoundException('No trend data for this product');

    return {
      ...serializeSellerProduct(row),
      history: row.history.map((point) => ({
        captured_on: point.capturedOn.toISOString().slice(0, 10),
        score: point.score,
        stage: point.stage,
        confidence: point.confidence,
      })),
      daily: row.facts.map((fact) => ({
        date: fact.day.toISOString().slice(0, 10),
        views: fact.views,
        search_hits: fact.searchHits,
        cart_adds: fact.cartAdds,
        favorites: fact.favorites,
        orders: fact.orders,
        units: fact.units,
        stock_units: fact.stockUnits,
      })),
      forecast_detail: row.forecast
        ? serializeForecast({
            horizonDays: row.forecast.horizonDays,
            totalUnits: row.forecast.totalUnits,
            totalRevenueSyp: Number(row.forecast.totalRevenueSyp),
            confidence: row.forecast.confidence,
            method: row.forecast.method,
            backtestMae: row.forecast.backtestMae,
            points: pointsOf(row.forecast.points),
            generatedOn: row.forecast.generatedOn,
          })
        : null,
      insights: row.insights.map(serializeInsight),
    };
  }

  @Roles(UserRole.SELLER)
  @Get('seller/forecast')
  async sellerForecast(
    @CurrentUser('id') sellerId: string,
    @Query() query: ForecastQueryDto,
  ) {
    const forecast = await this.sellerTrends.salesForecast(
      sellerId,
      query.horizon_days,
    );
    return serializeForecast(forecast);
  }

  @Roles(UserRole.SELLER)
  @Get('seller/insights')
  async sellerInsights(
    @CurrentUser('id') sellerId: string,
    @Query() query: InsightFeedDto,
  ) {
    const { rows, total } = await this.insights.feed({
      audience: TrendInsightAudience.SELLER,
      sellerId,
      statuses: query.statuses,
      kinds: query.kinds,
      limit: query.limit,
      offset: query.offset,
    });
    return {
      data: rows.map(serializeInsight),
      pagination: { total, limit: query.limit, offset: query.offset },
    };
  }

  @Roles(UserRole.SELLER)
  @Patch('seller/insights/:id')
  async updateSellerInsight(
    @CurrentUser() user: AuthUser,
    @Param('id', ParseUUIDPipe) id: string,
    @Body() body: UpdateInsightStatusDto,
  ) {
    const row = await this.insights.updateStatus(id, body.status, {
      id: user.id,
      sellerId: user.id,
    });
    return serializeInsight(row);
  }

  // ══════════════════════ Admin ══════════════════════

  @Permissions(AppPermission.analyticsRead)
  @Get('admin/overview')
  async adminOverview(@Query() query: TrendWindowDto) {
    const data = await this.adminTrends.overview(query.window);
    return {
      as_of: data.asOf.toISOString().slice(0, 10),
      window: data.window,
      window_days: data.windowDays,
      headline: {
        window_days: data.headline.windowDays,
        views: data.headline.views,
        previous_views: data.headline.previousViews,
        views_growth_pct: data.headline.viewsGrowthPct,
        searches: data.headline.searches,
        search_growth_pct: data.headline.searchGrowthPct,
        cart_adds: data.headline.cartAdds,
        cart_growth_pct: data.headline.cartGrowthPct,
        orders: data.headline.orders,
        orders_growth_pct: data.headline.ordersGrowthPct,
        units: data.headline.units,
        revenue: { amount: data.headline.revenueSyp.toFixed(2), currency: 'SYP' },
        revenue_growth_pct: data.headline.revenueGrowthPct,
        view_to_cart_rate: data.headline.viewToCartRate,
        cart_to_order_rate: data.headline.cartToOrderRate,
        stages: data.headline.stages,
      },
      series: data.series.map((point) => ({
        date: point.date,
        views: point.views,
        search_hits: point.searchHits,
        cart_adds: point.cartAdds,
        orders: point.orders,
        units: point.units,
        revenue: { amount: point.revenueSyp.toFixed(2), currency: 'SYP' },
      })),
      category_trends: data.categoryTrends.map(serializeCategoryTrend),
      colour_trends: data.colourTrends.map(serializeAttributeTrend),
      price_trends: data.priceTrends.map(serializeAttributeTrend),
      emerging_products: data.emergingProducts.map(serializeAdminProduct),
      declining_products: data.decliningProducts.map(serializeAdminProduct),
      search_trends: data.searchTrends.map(serializeSearchTerm),
      unmet_demand: data.unmetDemand.map(serializeUnmetDemand),
      unmet_demand_total: data.unmetDemandTotal,
      forecast: serializeForecast(data.forecast),
      insights: data.insights.map(serializeInsight),
    };
  }

  @Permissions(AppPermission.analyticsRead)
  @Get('admin/categories')
  async adminCategories(@Query() query: TrendListDto) {
    const rows = await this.adminTrends.categoryTrends(query.window, query.limit);
    return { data: rows.map(serializeCategoryTrend) };
  }

  @Permissions(AppPermission.analyticsRead)
  @Get('admin/attributes')
  async adminAttributes(@Query() query: AttributeTrendsDto) {
    const rows = await this.adminTrends.attributeTrends(
      query.dimension,
      query.days,
      query.scope_id ?? PLATFORM_SCOPE,
      query.limit,
    );
    return { data: rows.map(serializeAttributeTrend) };
  }

  /** Convenience aliases — the two facets the client asked for by name. */
  @Permissions(AppPermission.analyticsRead)
  @Get('admin/colors')
  async adminColours(@Query() query: AttributeTrendsDto) {
    const rows = await this.adminTrends.attributeTrends(
      TrendAttributeDimension.COLOR,
      query.days,
      query.scope_id ?? PLATFORM_SCOPE,
      query.limit,
    );
    return { data: rows.map(serializeAttributeTrend) };
  }

  @Permissions(AppPermission.analyticsRead)
  @Get('admin/prices')
  async adminPrices(@Query() query: AttributeTrendsDto) {
    const rows = await this.adminTrends.attributeTrends(
      TrendAttributeDimension.PRICE_BAND,
      query.days,
      query.scope_id ?? PLATFORM_SCOPE,
      query.limit,
    );
    return { data: rows.map(serializeAttributeTrend) };
  }

  @Permissions(AppPermission.analyticsRead)
  @Get('admin/products')
  async adminProducts(@Query() query: AdminProductTrendsDto) {
    const { rows, total } = await this.adminTrends.products(query.window, {
      stage: query.stage,
      categoryId: query.category_id,
      minConfidence: query.min_confidence,
      limit: query.limit,
      offset: query.offset,
    });
    return {
      data: rows.map(serializeAdminProduct),
      pagination: { total, limit: query.limit, offset: query.offset },
    };
  }

  @Permissions(AppPermission.analyticsRead)
  @Get('admin/products/:productId')
  async adminProduct(
    @Param('productId', ParseUUIDPipe) productId: string,
    @Query() query: TrendWindowDto,
  ) {
    const data = await this.adminTrends.product(productId, query.window);
    if (!data) throw new NotFoundException('No trend data for this product');

    return {
      product: {
        id: data.score.product.id,
        title: data.score.product.title,
        slug: data.score.product.slug,
        category: data.score.product.category
          ? {
              id: data.score.product.category.id,
              name_ar: data.score.product.category.nameAr,
            }
          : null,
      },
      trend_score: data.score.score,
      stage: data.score.stage,
      confidence: data.score.confidence,
      metrics: data.score.metrics,
      history: data.history.map((point) => ({
        captured_on: point.capturedOn.toISOString().slice(0, 10),
        score: point.score,
        stage: point.stage,
        confidence: point.confidence,
        rank: point.rank,
      })),
      daily: data.facts.map((fact) => ({
        date: fact.day.toISOString().slice(0, 10),
        views: fact.views,
        impressions: fact.impressions,
        search_hits: fact.searchHits,
        cart_adds: fact.cartAdds,
        favorites: fact.favorites,
        shares: fact.shares,
        orders: fact.orders,
        units: fact.units,
        revenue: { amount: Number(fact.revenueSyp).toFixed(2), currency: 'SYP' },
        returns: fact.returns,
        stock_units: fact.stockUnits,
        in_stock: fact.inStock,
      })),
      forecast: data.forecast
        ? serializeForecast({
            horizonDays: data.forecast.horizonDays,
            totalUnits: data.forecast.totalUnits,
            totalRevenueSyp: Number(data.forecast.totalRevenueSyp),
            confidence: data.forecast.confidence,
            method: data.forecast.method,
            backtestMae: data.forecast.backtestMae,
            points: pointsOf(data.forecast.points),
            generatedOn: data.forecast.generatedOn,
          })
        : null,
      insights: data.insights.map(serializeInsight),
    };
  }

  @Permissions(AppPermission.analyticsRead)
  @Get('admin/search')
  async adminSearch(@Query() query: SearchTrendsDto) {
    const rows = query.rising
      ? await this.searchIntel.risingTerms({
          windowDays: query.days,
          limit: query.limit,
        })
      : await this.searchIntel.topTerms({
          windowDays: query.days,
          limit: query.limit,
        });
    return { data: rows.map(serializeSearchTerm) };
  }

  @Permissions(AppPermission.analyticsRead)
  @Get('admin/unmet-demand')
  async adminUnmetDemand(@Query() query: UnmetDemandQueryDto) {
    const { rows, total } = await this.searchIntel.unmetDemand({
      status: query.status,
      limit: query.limit,
      offset: query.offset,
    });
    return {
      data: rows.map(serializeUnmetDemand),
      pagination: { total, limit: query.limit, offset: query.offset },
    };
  }

  @Permissions(AppPermission.analyticsRead)
  @Get('admin/unmet-demand/:termKey/matches')
  async adminUnmetDemandMatches(@Param('termKey') termKey: string) {
    const { signal, facets, products } = await this.searchIntel.matchesFor(termKey);
    return {
      signal: serializeUnmetDemand(signal),
      facets,
      products: products.map((product) => ({
        id: product.id,
        title: product.title,
        price:
          product.minPriceSyp === null
            ? null
            : { amount: Number(product.minPriceSyp).toFixed(2), currency: 'SYP' },
        rating: product.rating,
        offers_count: product.offersCount,
      })),
    };
  }

  @Permissions(AppPermission.trendsManage)
  @Patch('admin/unmet-demand/:id')
  async reviewUnmetDemand(
    @CurrentUser('id') actorId: string,
    @Param('id', ParseUUIDPipe) id: string,
    @Body() body: ReviewUnmetDemandDto,
  ) {
    const row = await this.searchIntel.review(
      id,
      { status: body.status, note: body.note ?? null },
      actorId,
    );
    return serializeUnmetDemand(row);
  }

  @Permissions(AppPermission.analyticsRead)
  @Get('admin/forecast')
  async adminForecast(@Query() query: ForecastQueryDto) {
    const forecast = await this.adminTrends.demandForecast(query.horizon_days);
    return serializeForecast(forecast);
  }

  @Permissions(AppPermission.analyticsRead)
  @Get('admin/sellers')
  async adminSellers(@Query() query: SellerPerformanceDto) {
    const rows = await this.adminTrends.sellerPerformance(query.days, query.limit);
    return {
      data: rows.map((row) => ({
        seller_id: row.sellerId,
        name: row.name,
        username: row.username,
        image_url: row.imageUrl,
        units: row.units,
        previous_units: row.previousUnits,
        units_growth_pct: row.unitsGrowthPct,
        orders: row.orders,
        revenue: { amount: row.revenueSyp.toFixed(2), currency: 'SYP' },
        revenue_growth_pct: row.revenueGrowthPct,
        cancel_rate: row.cancelRate,
        return_rate: row.returnRate,
        live_products: row.liveProducts,
        window_days: row.windowDays,
      })),
    };
  }

  @Permissions(AppPermission.analyticsRead)
  @Get('admin/opportunities')
  async adminOpportunities(@Query() query: TrendListDto) {
    const rows = await this.adminTrends.opportunities(query.window, query.limit);
    return {
      data: rows.map((row) => ({
        kind: row.kind,
        title_ar: row.titleAr,
        detail_ar: row.detailAr,
        score: row.score,
        subject_id: row.subjectId,
        metrics: row.metrics,
      })),
    };
  }

  @Permissions(AppPermission.analyticsRead)
  @Get('admin/insights')
  async adminInsights(@Query() query: InsightFeedDto) {
    const { rows, total } = await this.insights.feed({
      audience: TrendInsightAudience.ADMIN,
      statuses: query.statuses,
      kinds: query.kinds,
      limit: query.limit,
      offset: query.offset,
    });
    return {
      data: rows.map(serializeInsight),
      pagination: { total, limit: query.limit, offset: query.offset },
    };
  }

  @Permissions(AppPermission.trendsManage)
  @Patch('admin/insights/:id')
  async updateAdminInsight(
    @CurrentUser() user: AuthUser,
    @Param('id', ParseUUIDPipe) id: string,
    @Body() body: UpdateInsightStatusDto,
  ) {
    const row = await this.insights.updateStatus(id, body.status, { id: user.id });
    return serializeInsight(row);
  }

  // ── Ops ────────────────────────────────────────────────────────────────

  @Permissions(AppPermission.trendsManage)
  @Get('admin/runs')
  async adminRuns() {
    const runs = await this.runs.recent(20);
    return { data: runs.map(serializeRun) };
  }

  /**
   * Re-run the pipeline now.
   *
   * Refused rather than queued when one is already in flight: two collectors
   * upserting the same day would race on every row, and the honest answer to
   * "run it again" while it is running is "it is running".
   */
  @Permissions(AppPermission.trendsManage)
  @Post('admin/recompute')
  @HttpCode(HttpStatus.ACCEPTED)
  async recompute(
    @CurrentUser('id') actorId: string,
    @Body() body: RecomputeDto,
  ) {
    if (await this.orchestrator.isBusy()) {
      throw new ForbiddenException('A trend run is already in progress');
    }
    const result = await this.orchestrator.runAll({
      lookbackDays: body.lookback_days,
      rollupOnly: body.rollup_only,
      triggeredBy: actorId,
    });
    return {
      status: 'completed',
      lookback_days: body.lookback_days,
      ...result,
    };
  }
}

/** `TrendForecast.points`, validated on the way out of JSON. */
function pointsOf(
  value: unknown,
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
