import {
  Controller,
  Get,
  HttpCode,
  HttpStatus,
  Param,
  ParseUUIDPipe,
  Post,
  Query,
  NotFoundException,
} from '@nestjs/common';
import { UserRole } from '@prisma/client';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { Roles } from '../../common/decorators/roles.decorator';
import {
  HealthHistoryQueryDto,
  HealthQueryDto,
  ProductHealthQueryDto,
  RadarQueryDto,
} from './dto/intelligence.dto';
import {
  serializeAxis,
  serializeHealthHistory,
  serializePeers,
  serializeProductAdvice,
  serializeProductHealth,
  serializeRadar,
  serializeSellerHealth,
} from './intelligence.serializer';
import { DemandRadarService } from './radar/demand-radar.service';
import { ProductHealthService } from './product-health/product-health.service';
import { SellerAdvisorService } from './advisor/seller-advisor.service';
import { SellerHealthService } from './health/seller-health.service';

/**
 * Everything a seller is told about her own shop.
 *
 * One controller for all three systems because they are one product from her
 * side: the radar says what the market wants, product intelligence says which
 * of her listings can meet it, and health says whether her shop can be
 * trusted to deliver it. Splitting them across three controllers would make
 * the routes describe our modules rather than her screens.
 *
 * Every route is scoped to the caller's own id. There is deliberately no
 * `sellerId` parameter anywhere: a seller cannot ask about another seller's
 * health, and the absence of the parameter is what guarantees it rather than
 * a check that somebody could forget to write.
 */
@Roles(UserRole.SELLER)
@Controller('seller/intelligence')
export class SellerIntelligenceController {
  constructor(
    private readonly radar: DemandRadarService,
    private readonly products: ProductHealthService,
    private readonly health: SellerHealthService,
    private readonly advisor: SellerAdvisorService,
  ) {}

  // ── The advisor ────────────────────────────────────────────────────────

  /**
   * Her listings that were selling and stopped, each with one named cause.
   *
   * The difference from product health, which sits beside it: health asks how
   * good a listing is, this asks what *changed*. The remedies differ, and
   * telling a seller to improve her photographs when a competitor undercut
   * her by a third costs her a week.
   */
  @Get('declining')
  declining(@CurrentUser('id') sellerId: string) {
    return this.advisor.decliningListings(sellerId, 10);
  }

  /** Why one particular listing moved. */
  @Get('products/:productId/diagnosis')
  async diagnose(
    @CurrentUser('id') sellerId: string,
    @Param('productId', ParseUUIDPipe) productId: string,
  ) {
    const result = await this.advisor.diagnoseListing(sellerId, productId);
    if (!result) throw new NotFoundException('Listing not found');
    return {
      window_days: result.window_days,
      code: result.diagnosis.code,
      title: result.diagnosis.ar,
      action: result.diagnosis.actionAr,
      also: result.diagnosis.alsoAr,
      evidence: result.diagnosis.evidence,
    };
  }

  // ── Demand Radar ───────────────────────────────────────────────────────

  /** What the market is asking for, read for her shop. */
  @Get('radar')
  async demandRadar(
    @CurrentUser('id') sellerId: string,
    @Query() query: RadarQueryDto,
  ) {
    const data = await this.radar.overview(sellerId, { windowDays: query.days });
    return serializeRadar(data);
  }

  // ── Product Intelligence ───────────────────────────────────────────────

  /** Her listings, worst health first — a work queue, not a leaderboard. */
  @Get('products')
  async productList(
    @CurrentUser('id') sellerId: string,
    @Query() query: ProductHealthQueryDto,
  ) {
    const data = await this.products.list(sellerId, {
      windowDays: query.days,
      limit: query.limit,
    });

    return {
      window_days: data.windowDays,
      average_score: data.averageScore,
      rows: data.rows.map((row) => ({
        product_id: row.productId,
        title: row.title,
        image_url: row.imageUrl,
        score: row.score,
        confidence: row.confidence,
        axes: row.axes.map(serializeAxis),
        peers: serializePeers(row.peers),
        top_advice: row.topAdvice ? serializeProductAdvice(row.topAdvice) : null,
        advice_count: row.adviceCount,
        views: row.views,
        orders: row.orders,
        in_stock: row.inStock,
      })),
    };
  }

  /** One listing, taken apart. */
  @Get('products/:productId')
  async productDetail(
    @CurrentUser('id') sellerId: string,
    @Param('productId', ParseUUIDPipe) productId: string,
    @Query() query: ProductHealthQueryDto,
  ) {
    const data = await this.products.detail(sellerId, productId, {
      windowDays: query.days,
    });
    return {
      ...serializeProductHealth(data),
      window_days: query.days ?? null,
      // The measured inputs travel too. A seller who disagrees with a score
      // should be able to see the counts it was computed from rather than
      // being asked to take it on faith.
      facts: {
        images: data.facts.imageCount,
        attributes: data.facts.attributeCount,
        description_length: data.facts.description.trim().length,
        impressions: data.facts.impressions,
        views: data.facts.views,
        search_hits: data.facts.searchHits,
        search_clicks: data.facts.searchClicks,
        cart_adds: data.facts.cartAdds,
        favorites: data.facts.favorites,
        orders: data.facts.orders,
        units: data.facts.units,
        price_syp: data.facts.priceSyp,
        stock_units: data.facts.stockUnits,
        in_stock: data.facts.inStock,
      },
    };
  }

  // ── Seller Health ──────────────────────────────────────────────────────

  /** Her shop's health, computed now. */
  @Get('health')
  async sellerHealth(
    @CurrentUser('id') sellerId: string,
    @Query() query: HealthQueryDto,
  ) {
    const data = await this.health.current(sellerId, { windowDays: query.days });
    return {
      ...serializeSellerHealth(data),
      // Same principle as the product screen: the counts behind the score.
      facts: {
        accepted_orders: data.facts.acceptedOrders,
        delivered_orders: data.facts.deliveredOrders,
        cancelled_by_seller: data.facts.cancelledBySeller,
        cancelled_by_others: data.facts.cancelledByOthers,
        returned_orders: data.facts.returnedOrders,
        prep_hours: data.facts.prepHours,
        ship_hours: data.facts.shipHours,
        response_hours: data.facts.responseHours,
        average_rating: data.facts.averageRating,
        review_count: data.facts.reviewCount,
      },
    };
  }

  /** The line on the chart. */
  @Get('health/history')
  async healthHistory(
    @CurrentUser('id') sellerId: string,
    @Query() query: HealthHistoryQueryDto,
  ) {
    const rows = await this.health.history(sellerId, query.days ?? 90);
    return { rows: serializeHealthHistory(rows) };
  }

  /**
   * Freeze today's figures.
   *
   * Offered to her rather than only run by the scheduler because the history
   * chart is only as good as the days that were captured, and a seller who
   * opens the screen after a quiet week should be able to put a point on it.
   * Idempotent: one row per day, so pressing it twice changes nothing.
   */
  @Post('health/snapshot')
  @HttpCode(HttpStatus.CREATED)
  async snapshot(@CurrentUser('id') sellerId: string) {
    // Listings first: the seller's quality dimension averages the product
    // snapshots, so running them the other way round would score her against
    // yesterday's listings.
    const products = await this.products.snapshotSeller(sellerId);
    const health = await this.health.snapshot(sellerId);
    return {
      products_scored: products,
      score: health.score,
      band: health.band,
    };
  }
}
