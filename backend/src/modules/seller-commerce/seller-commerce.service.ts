import { Injectable, NotFoundException } from '@nestjs/common';
import {
  AnalyticsEventType,
  CommerceContentStatus,
  CommissionStatus,
  Currency,
  OfferStatus,
  Prisma,
  ReviewStatus,
  SellerOrderStatus,
} from '@prisma/client';
import { AuthUser } from '../../common/decorators/current-user.decorator';
import { PrismaService } from '../../prisma/prisma.service';
import { Money, REVENUE_STATUSES } from '../../common/money';

/**
 * Seller revenue is read off SELLER_ORDERS now. The previous implementation
 * joined `order_items -> products.seller_id`, which stopped being meaningful
 * the moment a product became a shared catalog entry — and already
 * double-counted any basket containing two sellers.
 */
const revenueStatuses = [...REVENUE_STATUSES];

const lowStockThreshold = 10;

type CountRow<TStatus extends string> = {
  status: TStatus;
  _count: { _all: number };
};

interface RevenueRow {
  revenue: number | string | bigint | null;
  orders: number | string | bigint | null;
}

interface DailySeriesRow extends RevenueRow {
  bucket: number | string | bigint;
}

interface PeriodSeriesRow extends RevenueRow {
  bucket: Date;
}

interface TopProductRow {
  id: string;
  title: string;
  image_url: string | null;
  revenue: number | string | bigint | null;
  units_sold: number | string | bigint | null;
  rating: number | string | bigint | null;
  reviews_count: number | string | bigint | null;
  stock: number | string | bigint | null;
}

interface StatusCountRow {
  status: string;
  count: number | string | bigint | null;
}

interface DateRange {
  start: Date;
  end: Date;
}

@Injectable()
export class SellerCommerceService {
  constructor(private readonly prisma: PrismaService) {}

  async overview(user: AuthUser) {
    const sellerId = user.id;
    const now = new Date();
    const ranges = this.ranges(now);

    const [
      seller,
      productStatusRows,
      contentStatusRows,
      orderStatusRows,
      revenue,
      previousRevenue,
      lifetimeRevenue,
      topProducts,
      lowStock,
      conversion,
      recentReviews,
      campaigns,
      withdrawableBalance,
      netEarnings,
      charts,
    ] = await Promise.all([
      this.prisma.user.findUnique({
        where: { id: sellerId },
        select: {
          id: true,
          name: true,
          username: true,
          bio: true,
          imageUrl: true,
          isVerified: true,
          followersCount: true,
          createdAt: true,
          sellerLevel: true,
          sellerVerifiedAt: true,
          sellerReputation: {
            select: {
              averageRating: true,
              reviewsCount: true,
              performanceScore: true,
              fulfillmentScore: true,
              responseScore: true,
              customerSatisfactionScore: true,
            },
          },
        },
      }),
      this.prisma.sellerOffer.groupBy({
        by: ['status'],
        where: { sellerId },
        _count: { _all: true },
      }),
      this.prisma.commerceContent.groupBy({
        by: ['status'],
        where: { sellerId },
        _count: { _all: true },
      }),
      this.orderStatusCounts(sellerId),
      this.revenueWindows(sellerId, ranges),
      this.previousRevenueWindows(sellerId, ranges),
      this.revenueBetween(sellerId),
      this.topProducts(sellerId, ranges.month),
      this.lowStockProducts(sellerId),
      this.conversionMetrics(sellerId, ranges.month, ranges.previousMonth),
      this.recentReviews(sellerId),
      this.activeCampaigns(sellerId),
      this.withdrawableBalance(sellerId),
      this.netEarnings(sellerId),
      this.charts(sellerId, now),
    ]);

    if (!seller) throw new NotFoundException('Seller not found');

    const productCounts = this.countsByStatus(productStatusRows);
    const contentCounts = this.countsByStatus(contentStatusRows);
    const totalProducts = this.sumValues(productCounts);
    const activeProducts = productCounts[OfferStatus.ACTIVE] ?? 0;
    const draftProducts = productCounts[OfferStatus.DRAFT] ?? 0;
    const publishedContent =
      contentCounts[CommerceContentStatus.PUBLISHED] ?? 0;

    const totalOrders = lifetimeRevenue.orders;
    const storeScore = this.storeScore(seller.sellerReputation);
    const orders = this.ordersSummary(orderStatusRows);
    const aiInsights = this.aiInsights({
      revenue,
      previousRevenue,
      topProducts,
      lowStockCount: lowStock.length,
      draftProducts,
      conversionRate: conversion.conversion_rate,
    });
    const pendingTasks = this.pendingTasks({
      orders,
      lowStockCount: lowStock.length,
      draftProducts,
      publishedContent,
      sellerVerifiedAt: seller.sellerVerifiedAt,
    });

    return {
      generated_at: now.toISOString(),
      store_info: {
        id: seller.id,
        name: seller.name,
        tagline: seller.username ? `@${seller.username}` : 'Seller workspace',
        description: seller.bio ?? '',
        logo_url: seller.imageUrl ?? '',
        cover_url: '',
        is_verified: seller.isVerified || seller.sellerVerifiedAt !== null,
        rating: this.round(seller.sellerReputation?.averageRating ?? 0),
        reviews_count: seller.sellerReputation?.reviewsCount ?? 0,
        total_revenue: lifetimeRevenue.revenue,
        total_orders: totalOrders,
        products_count: totalProducts,
        followers_count: seller.followersCount,
        store_score: storeScore.overall,
        member_since: seller.createdAt.toISOString(),
        subscription_plan: this.titleCase(seller.sellerLevel.toLowerCase()),
        withdrawable_balance: withdrawableBalance,
      },
      revenue: {
        today: revenue.today.revenue,
        this_week: revenue.week.revenue,
        this_month: revenue.month.revenue,
        this_year: revenue.year.revenue,
        today_trend: this.trend(revenue.today.revenue, previousRevenue.today.revenue),
        week_trend: this.trend(revenue.week.revenue, previousRevenue.week.revenue),
        month_trend: this.trend(
          revenue.month.revenue,
          previousRevenue.month.revenue,
        ),
        year_trend: this.trend(revenue.year.revenue, previousRevenue.year.revenue),
        // Was `revenue * 0.32` with a hardcoded 32% margin and no
        // cost-of-goods field anywhere — a fabricated figure shown to sellers.
        // This is the real amount left after platform commission.
        total_profit: netEarnings,
        profit_margin:
          lifetimeRevenue.revenue > 0
            ? this.round((netEarnings / lifetimeRevenue.revenue) * 100)
            : 0,
        total_orders: totalOrders,
      },
      orders,
      charts,
      top_products: topProducts,
      low_stock: lowStock,
      store_score: storeScore,
      conversion_metrics: conversion,
      ai_insights: aiInsights,
      pending_tasks: pendingTasks,
      goals: this.goals({
        monthRevenue: revenue.month.revenue,
        monthOrders: revenue.month.orders,
        activeProducts,
        rating: seller.sellerReputation?.averageRating ?? 0,
      }),
      recent_reviews: recentReviews,
      campaigns,
      module_health: {
        products: {
          total: totalProducts,
          active: activeProducts,
          drafts: draftProducts,
          archived: productCounts[OfferStatus.ARCHIVED] ?? 0,
          out_of_stock: productCounts[OfferStatus.OUT_OF_STOCK] ?? 0,
        },
        content: {
          published: publishedContent,
          drafts: contentCounts[CommerceContentStatus.DRAFT] ?? 0,
          scheduled: contentCounts[CommerceContentStatus.SCHEDULED] ?? 0,
          in_review: contentCounts[CommerceContentStatus.IN_REVIEW] ?? 0,
        },
      },
    };
  }

  private async revenueWindows(sellerId: string, ranges: ReturnType<typeof this.ranges>) {
    const [today, week, month, year] = await Promise.all([
      this.revenueBetween(sellerId, ranges.today.start, ranges.today.end),
      this.revenueBetween(sellerId, ranges.week.start, ranges.week.end),
      this.revenueBetween(sellerId, ranges.month.start, ranges.month.end),
      this.revenueBetween(sellerId, ranges.year.start, ranges.year.end),
    ]);
    return { today, week, month, year };
  }

  private async previousRevenueWindows(
    sellerId: string,
    ranges: ReturnType<typeof this.ranges>,
  ) {
    const [today, week, month, year] = await Promise.all([
      this.revenueBetween(
        sellerId,
        ranges.previousDay.start,
        ranges.previousDay.end,
      ),
      this.revenueBetween(
        sellerId,
        ranges.previousWeek.start,
        ranges.previousWeek.end,
      ),
      this.revenueBetween(
        sellerId,
        ranges.previousMonth.start,
        ranges.previousMonth.end,
      ),
      this.revenueBetween(
        sellerId,
        ranges.previousYear.start,
        ranges.previousYear.end,
      ),
    ]);
    return { today, week, month, year };
  }

  private async revenueBetween(
    sellerId: string,
    start?: Date,
    end?: Date,
  ): Promise<{ revenue: number; orders: number; currency: Currency }> {
    const rows = await this.prisma.sellerOrder.groupBy({
      by: ['currency'],
      where: {
        sellerId,
        status: { in: revenueStatuses },
        ...(start || end
          ? {
              createdAt: {
                ...(start ? { gte: start } : {}),
                ...(end ? { lt: end } : {}),
              },
            }
          : {}),
      },
      _sum: { itemsSubtotal: true },
      _count: { _all: true },
    });

    if (rows.length === 0) {
      return { revenue: 0, orders: 0, currency: Currency.SYP };
    }

    // A seller may have sold in more than one currency. Rather than adding
    // them together — which would be meaningless — the headline figure is the
    // currency they sold most in, and the rest is available per currency.
    const dominant = rows.reduce((best, row) =>
      Money.of(row._sum.itemsSubtotal ?? 0, row.currency).greaterThan(
        Money.of(best._sum.itemsSubtotal ?? 0, best.currency),
      )
        ? row
        : best,
    );

    return {
      revenue: Money.of(
        dominant._sum.itemsSubtotal ?? 0,
        dominant.currency,
      ).toUnsafeNumber(),
      orders: rows.reduce((total, row) => total + row._count._all, 0),
      currency: dominant.currency,
    };
  }

  private async orderStatusCounts(sellerId: string) {
    const rows = await this.prisma.sellerOrder.groupBy({
      by: ['status'],
      where: { sellerId },
      _count: { _all: true },
    });
    return rows.map((row) => ({
      status: row.status as string,
      count: row._count._all,
    }));
  }

  private async topProducts(sellerId: string, range: DateRange) {
    const rows = await this.prisma.$queryRaw<TopProductRow[]>(Prisma.sql`
      SELECT
        p.id::text AS id,
        p.title,
        media.url AS image_url,
        COALESCE(SUM(oi.line_total), 0)::float AS revenue,
        COALESCE(SUM(oi.quantity), 0)::int AS units_sold,
        p.rating::float AS rating,
        p.reviews_count::int AS reviews_count,
        COALESCE((
          SELECT SUM(stock) FROM seller_offers
          WHERE product_id = p.id AND seller_id = ${sellerId}::uuid
        ), 0)::int AS stock
      FROM products p
      JOIN order_items oi ON oi.product_id = p.id
      JOIN seller_orders so ON so.id = oi.seller_order_id
      LEFT JOIN LATERAL (
        SELECT url
        FROM product_media
        WHERE product_id = p.id
        ORDER BY sort_order ASC
        LIMIT 1
      ) media ON true
      WHERE so.seller_id = ${sellerId}::uuid
        AND so.status::text IN (${Prisma.join(revenueStatuses)})
        AND so.created_at >= ${range.start}
        AND so.created_at < ${range.end}
      GROUP BY p.id, media.url
      ORDER BY revenue DESC
      LIMIT 5
    `);

    return rows.map((row) => ({
      id: row.id,
      title: row.title,
      image_url: row.image_url ?? '',
      revenue: this.round(this.toNumber(row.revenue)),
      units_sold: Math.round(this.toNumber(row.units_sold)),
      rating: this.round(this.toNumber(row.rating)),
      reviews_count: Math.round(this.toNumber(row.reviews_count)),
      stock: Math.round(this.toNumber(row.stock)),
      revenue_change: null,
    }));
  }

  private async lowStockProducts(sellerId: string) {
    const offers = await this.prisma.sellerOffer.findMany({
      where: {
        sellerId,
        OR: [
          { stock: { lte: lowStockThreshold } },
          { status: OfferStatus.OUT_OF_STOCK },
        ],
      },
      select: {
        id: true,
        stock: true,
        price: true,
        currency: true,
        product: {
          select: {
            id: true,
            title: true,
            media: {
              orderBy: { sortOrder: 'asc' },
              take: 1,
              select: { url: true },
            },
          },
        },
      },
      orderBy: [{ stock: 'asc' }, { updatedAt: 'desc' }],
      take: 6,
    });

    return offers.map((offer) => ({
      id: offer.id,
      product_id: offer.product.id,
      title: offer.product.title,
      image_url: offer.product.media[0]?.url ?? '',
      stock: offer.stock,
      threshold: lowStockThreshold,
      price: Money.of(offer.price, offer.currency).toJSON(),
    }));
  }

  private async conversionMetrics(
    sellerId: string,
    currentRange: DateRange,
    previousRange: DateRange,
  ) {
    const [currentEvents, previousEvents, wishlistAdds, purchases] =
      await Promise.all([
        this.eventCounts(sellerId, currentRange),
        this.eventCounts(sellerId, previousRange),
        this.prisma.favorite.count({
          where: {
            product: { offers: { some: { sellerId } } },
            createdAt: { gte: currentRange.start, lt: currentRange.end },
          },
        }),
        this.revenueBetween(sellerId, currentRange.start, currentRange.end),
      ]);

    const productViews = currentEvents[AnalyticsEventType.PRODUCT_VIEW] ?? 0;
    const previousViews = previousEvents[AnalyticsEventType.PRODUCT_VIEW] ?? 0;
    const cartAdds = currentEvents[AnalyticsEventType.CART_ADD] ?? 0;
    const previousCartAdds = previousEvents[AnalyticsEventType.CART_ADD] ?? 0;

    return {
      product_views: productViews,
      wishlist_adds: wishlistAdds,
      cart_adds: cartAdds,
      purchases: purchases.orders,
      views_trend: this.trend(productViews, previousViews),
      wishlist_trend: 0,
      cart_trend: this.trend(cartAdds, previousCartAdds),
      conversion_rate: this.rate(purchases.orders, productViews),
      cart_abandon_rate:
        cartAdds === 0
          ? 0
          : this.round(Math.max(0, 1 - purchases.orders / cartAdds) * 100),
    };
  }

  private async eventCounts(sellerId: string, range: DateRange) {
    const rows = await this.prisma.analyticsEvent.groupBy({
      by: ['type'],
      where: {
        sellerId,
        occurredAt: { gte: range.start, lt: range.end },
      },
      _count: { _all: true },
    });
    return rows.reduce<Partial<Record<AnalyticsEventType, number>>>(
      (acc, row) => {
        acc[row.type] = row._count._all;
        return acc;
      },
      {},
    );
  }

  private async recentReviews(sellerId: string) {
    const reviews = await this.prisma.sellerReview.findMany({
      where: { sellerId, status: ReviewStatus.APPROVED },
      select: {
        id: true,
        rating: true,
        body: true,
        title: true,
        createdAt: true,
        user: { select: { name: true, imageUrl: true } },
      },
      orderBy: { createdAt: 'desc' },
      take: 3,
    });

    return reviews.map((review) => ({
      id: review.id,
      customer_name: review.user.name,
      customer_avatar_url: review.user.imageUrl ?? '',
      product_title: review.title ?? 'Seller review',
      rating: review.rating,
      body: review.body ?? '',
      time_ago: this.timeAgo(review.createdAt),
    }));
  }

  private async activeCampaigns(sellerId: string) {
    const now = new Date();
    const contents = await this.prisma.commerceContent.findMany({
      where: {
        sellerId,
        status: {
          in: [
            CommerceContentStatus.PUBLISHED,
            CommerceContentStatus.SCHEDULED,
          ],
        },
        OR: [{ expiresAt: null }, { expiresAt: { gt: now } }],
      },
      select: {
        id: true,
        title: true,
        contentType: true,
        productClicksCount: true,
        engagementCount: true,
        revenueGenerated: true,
        revenueCurrency: true,
        expiresAt: true,
        status: true,
      },
      orderBy: [{ revenueGenerated: 'desc' }, { updatedAt: 'desc' }],
      take: 3,
    });

    return contents.map((content) => ({
      id: content.id,
      name: content.title ?? this.titleCase(content.contentType),
      kind: this.titleCase(content.contentType.replace(/_/g, ' ')),
      uses: Number(content.productClicksCount + content.engagementCount),
      revenue: Money.of(
        content.revenueGenerated,
        content.revenueCurrency,
      ).toJSON(),
      ends_at: content.expiresAt?.toISOString() ?? null,
      is_active: content.status === CommerceContentStatus.PUBLISHED,
    }));
  }

  private async withdrawableBalance(sellerId: string) {
    const aggregate = await this.prisma.commissionLedger.aggregate({
      where: {
        sellerId,
        status: CommissionStatus.EARNED,
        // Q24 P1 — only released escrow is actually withdrawable.
        sellerOrder: { escrowReleased: true },
      },
      _sum: { net: true },
    });
    return Money.of(aggregate._sum.net ?? 0, Currency.SYP).toUnsafeNumber();
  }

  /** Lifetime net after commission — the seller's real earnings. */
  private async netEarnings(sellerId: string) {
    const aggregate = await this.prisma.commissionLedger.aggregate({
      where: { sellerId, status: { not: CommissionStatus.REVERSED } },
      _sum: { net: true },
    });
    return Money.of(aggregate._sum.net ?? 0, Currency.SYP).toUnsafeNumber();
  }

  private async charts(sellerId: string, now: Date) {
    const daily = await this.dailySeries(sellerId, this.startOfDay(now), now);
    const weeklyStart = this.addDays(this.startOfDay(now), -6);
    const weekly = await this.periodSeries(
      sellerId,
      weeklyStart,
      this.addDays(this.startOfDay(now), 1),
      'day',
      Array.from({ length: 7 }, (_, index) =>
        this.addDays(weeklyStart, index),
      ),
    );

    const monthStart = this.startOfMonth(now);
    const monthlyBuckets = Array.from({ length: 6 }, (_, index) =>
      this.addMonths(monthStart, index - 5),
    );
    const monthly = await this.periodSeries(
      sellerId,
      monthlyBuckets[0],
      this.addMonths(monthStart, 1),
      'month',
      monthlyBuckets,
    );

    const yearStart = this.startOfYear(now);
    const yearlyBuckets = Array.from({ length: 4 }, (_, index) =>
      new Date(yearStart.getFullYear() - 3 + index, 0, 1),
    );
    const yearly = await this.periodSeries(
      sellerId,
      yearlyBuckets[0],
      new Date(yearStart.getFullYear() + 1, 0, 1),
      'year',
      yearlyBuckets,
    );

    return {
      daily,
      weekly,
      monthly,
      yearly,
    };
  }

  private async dailySeries(sellerId: string, start: Date, end: Date) {
    const rows = await this.prisma.$queryRaw<DailySeriesRow[]>(Prisma.sql`
      SELECT
        FLOOR(EXTRACT(HOUR FROM so.created_at) / 3)::int AS bucket,
        COALESCE(SUM(oi.line_total), 0)::float AS revenue,
        COUNT(DISTINCT so.order_id)::int AS orders
      FROM order_items oi
      JOIN seller_orders so ON so.id = oi.seller_order_id
      WHERE so.seller_id = ${sellerId}::uuid
        AND so.status::text IN (${Prisma.join(revenueStatuses)})
        AND so.created_at >= ${start}
        AND so.created_at < ${end}
      GROUP BY bucket
      ORDER BY bucket
    `);
    const byBucket = new Map(
      rows.map((row) => [Math.round(this.toNumber(row.bucket)), row]),
    );
    const buckets = Array.from({ length: 8 }, (_, index) => index);
    return this.seriesPayload(
      buckets.map((bucket) => {
        const row = byBucket.get(bucket);
        return {
          label: `${bucket * 3}:00`,
          revenue: this.round(this.toNumber(row?.revenue)),
          orders: Math.round(this.toNumber(row?.orders)),
        };
      }),
    );
  }

  private async periodSeries(
    sellerId: string,
    start: Date,
    end: Date,
    granularity: 'day' | 'month' | 'year',
    buckets: Date[],
  ) {
    const rows = await this.prisma.$queryRaw<PeriodSeriesRow[]>(Prisma.sql`
      SELECT
        date_trunc(${granularity}, so.created_at)::timestamp AS bucket,
        COALESCE(SUM(oi.line_total), 0)::float AS revenue,
        COUNT(DISTINCT so.order_id)::int AS orders
      FROM order_items oi
      JOIN seller_orders so ON so.id = oi.seller_order_id
      WHERE so.seller_id = ${sellerId}::uuid
        AND so.status::text IN (${Prisma.join(revenueStatuses)})
        AND so.created_at >= ${start}
        AND so.created_at < ${end}
      GROUP BY bucket
      ORDER BY bucket
    `);
    const byBucket = new Map(
      rows.map((row) => [this.bucketKey(row.bucket, granularity), row]),
    );

    return this.seriesPayload(
      buckets.map((bucket) => {
        const row = byBucket.get(this.bucketKey(bucket, granularity));
        return {
          label: this.bucketLabel(bucket, granularity),
          revenue: this.round(this.toNumber(row?.revenue)),
          orders: Math.round(this.toNumber(row?.orders)),
        };
      }),
    );
  }

  private seriesPayload(
    rows: { label: string; revenue: number; orders: number }[],
  ) {
    return {
      revenue_points: rows.map((row) => ({
        label: row.label,
        value: row.revenue,
      })),
      orders_points: rows.map((row) => ({
        label: row.label,
        value: row.orders,
      })),
    };
  }

  private storeScore(
    reputation:
      | {
          averageRating: number;
          performanceScore: number;
          fulfillmentScore: number;
          responseScore: number;
          customerSatisfactionScore: number;
        }
      | null
      | undefined,
  ) {
    const overall = Math.round(reputation?.performanceScore ?? 0);
    return {
      overall,
      fulfillment: Math.round(reputation?.fulfillmentScore ?? overall),
      responsiveness: Math.round(reputation?.responseScore ?? overall),
      product_quality: Math.round(
        reputation?.customerSatisfactionScore ?? overall,
      ),
      rating: this.round(reputation?.averageRating ?? 0),
    };
  }

  private ordersSummary(rows: StatusCountRow[]) {
    const counts = rows.reduce<Record<string, number>>((acc, row) => {
      acc[row.status] = Math.round(this.toNumber(row.count));
      return acc;
    }, {});
    const sum = (...statuses: SellerOrderStatus[]) =>
      statuses.reduce((total, status) => total + (counts[status] ?? 0), 0);

    return {
      new_orders: sum(
        SellerOrderStatus.NEW,
        SellerOrderStatus.AWAITING_SELLER_CONFIRMATION,
      ),
      processing: sum(SellerOrderStatus.PREPARING),
      ready_for_shipment: sum(SellerOrderStatus.READY_TO_SHIP),
      in_transit: sum(
        SellerOrderStatus.HANDED_TO_COURIER,
        SellerOrderStatus.IN_TRANSIT,
      ),
      delivered: sum(SellerOrderStatus.DELIVERED),
      failed: sum(
        SellerOrderStatus.DELIVERY_FAILED,
        SellerOrderStatus.REJECTED_ON_DELIVERY,
      ),
      cancelled: sum(
        SellerOrderStatus.CANCELLED_BY_CUSTOMER,
        SellerOrderStatus.CANCELLED_BY_SELLER,
      ),
      returned: sum(
        SellerOrderStatus.RETURN_REQUESTED,
        SellerOrderStatus.RETURN_IN_TRANSIT,
        SellerOrderStatus.RETURNED,
        SellerOrderStatus.REFUNDED,
      ),
      disputed: sum(SellerOrderStatus.DISPUTED),
    };
  }

  private aiInsights(input: {
    revenue: Awaited<ReturnType<SellerCommerceService['revenueWindows']>>;
    previousRevenue: Awaited<
      ReturnType<SellerCommerceService['previousRevenueWindows']>
    >;
    topProducts: { title: string; revenue: number }[];
    lowStockCount: number;
    draftProducts: number;
    conversionRate: number;
  }) {
    const insights: {
      id: string;
      kind: string;
      title: string;
      body: string;
      action: string;
    }[] = [];

    const bestProduct = input.topProducts[0];
    if (bestProduct) {
      insights.push({
        id: 'top-product-momentum',
        kind: 'revenue',
        title: 'Top product momentum',
        body: `${bestProduct.title} leads this month with ${bestProduct.revenue} in seller revenue.`,
        action: 'Review product',
      });
    }

    if (input.lowStockCount > 0) {
      insights.push({
        id: 'low-stock-risk',
        kind: 'inventory',
        title: 'Inventory risk detected',
        body: `${input.lowStockCount} products are at or below the low-stock threshold.`,
        action: 'Review stock',
      });
    }

    if (input.draftProducts > 0) {
      insights.push({
        id: 'draft-products',
        kind: 'product',
        title: 'Publish-ready catalog work',
        body: `${input.draftProducts} product drafts can be completed or scheduled.`,
        action: 'Open drafts',
      });
    }

    const monthTrend = this.trend(
      input.revenue.month.revenue,
      input.previousRevenue.month.revenue,
    );
    insights.push({
      id: 'monthly-performance',
      kind: monthTrend >= 0 ? 'revenue' : 'warning',
      title: monthTrend >= 0 ? 'Revenue is growing' : 'Revenue needs attention',
      body: `Month-to-date revenue is ${Math.abs(monthTrend)}% ${
        monthTrend >= 0 ? 'above' : 'below'
      } the previous period.`,
      action: 'Open analytics',
    });

    if (input.conversionRate < 2 && input.revenue.month.revenue > 0) {
      insights.push({
        id: 'conversion-opportunity',
        kind: 'customer',
        title: 'Conversion opportunity',
        body: `Current conversion is ${input.conversionRate}%. Improve titles, media, pricing, or bundles for high-traffic products.`,
        action: 'Improve listings',
      });
    }

    return insights.slice(0, 4);
  }

  private pendingTasks(input: {
    orders: {
      new_orders: number;
      processing: number;
      ready_for_shipment: number;
    };
    lowStockCount: number;
    draftProducts: number;
    publishedContent: number;
    sellerVerifiedAt: Date | null;
  }) {
    const tasks = [];
    if (!input.sellerVerifiedAt) {
      tasks.push({
        id: 'seller-verification',
        kind: 'verification',
        title: 'Complete seller verification',
        subtitle: 'Unlock publishing and advanced commerce operations',
        priority: 'high',
      });
    }
    if (input.orders.ready_for_shipment > 0) {
      tasks.push({
        id: 'ship-ready-orders',
        kind: 'fulfillment',
        title: `Ship ${input.orders.ready_for_shipment} ready orders`,
        subtitle: 'Keep fulfillment performance healthy',
        priority: 'high',
        count: input.orders.ready_for_shipment,
      });
    }
    if (input.lowStockCount > 0) {
      tasks.push({
        id: 'review-low-stock',
        kind: 'inventory',
        title: `Restock ${input.lowStockCount} products`,
        subtitle: 'Avoid missed sales on active listings',
        priority: input.lowStockCount >= 3 ? 'high' : 'medium',
        count: input.lowStockCount,
      });
    }
    if (input.draftProducts > 0) {
      tasks.push({
        id: 'complete-product-drafts',
        kind: 'products',
        title: `Complete ${input.draftProducts} product drafts`,
        subtitle: 'Draft products are not visible to customers',
        priority: 'medium',
        count: input.draftProducts,
      });
    }
    if (input.publishedContent === 0) {
      tasks.push({
        id: 'publish-commerce-content',
        kind: 'content',
        title: 'Publish shoppable content',
        subtitle: 'Connect catalog products to posts, stories, and campaigns',
        priority: 'low',
      });
    }
    return tasks.slice(0, 6);
  }

  private goals(input: {
    monthRevenue: number;
    monthOrders: number;
    activeProducts: number;
    rating: number;
  }) {
    return [
      {
        id: 'monthly-revenue',
        kind: 'revenue',
        label: 'Monthly revenue',
        current: input.monthRevenue,
        target: this.goalTarget(input.monthRevenue, 1000),
        unit: '$',
      },
      {
        id: 'monthly-orders',
        kind: 'orders',
        label: 'Orders this month',
        current: input.monthOrders,
        target: this.goalTarget(input.monthOrders, 25),
        unit: '',
      },
      {
        id: 'active-products',
        kind: 'products',
        label: 'Active products',
        current: input.activeProducts,
        target: this.goalTarget(input.activeProducts, 20),
        unit: '',
      },
      {
        id: 'store-rating',
        kind: 'rating',
        label: 'Store rating',
        current: input.rating,
        target: 5,
        unit: 'stars',
      },
    ];
  }

  private countsByStatus<TStatus extends string>(rows: CountRow<TStatus>[]) {
    return rows.reduce<Record<TStatus, number>>(
      (acc, row) => {
        acc[row.status] = row._count._all;
        return acc;
      },
      {} as Record<TStatus, number>,
    );
  }

  private ranges(now: Date) {
    const todayStart = this.startOfDay(now);
    const tomorrowStart = this.addDays(todayStart, 1);
    const weekStart = this.startOfWeek(now);
    const previousWeekStart = this.addDays(weekStart, -7);
    const monthStart = this.startOfMonth(now);
    const previousMonthStart = this.addMonths(monthStart, -1);
    const yearStart = this.startOfYear(now);
    const previousYearStart = new Date(yearStart.getFullYear() - 1, 0, 1);

    return {
      today: { start: todayStart, end: tomorrowStart },
      previousDay: { start: this.addDays(todayStart, -1), end: todayStart },
      week: { start: weekStart, end: now },
      previousWeek: { start: previousWeekStart, end: weekStart },
      month: { start: monthStart, end: now },
      previousMonth: { start: previousMonthStart, end: monthStart },
      year: { start: yearStart, end: now },
      previousYear: { start: previousYearStart, end: yearStart },
    };
  }

  private startOfDay(date: Date) {
    return new Date(date.getFullYear(), date.getMonth(), date.getDate());
  }

  private startOfWeek(date: Date) {
    const start = this.startOfDay(date);
    const day = (start.getDay() + 6) % 7;
    return this.addDays(start, -day);
  }

  private startOfMonth(date: Date) {
    return new Date(date.getFullYear(), date.getMonth(), 1);
  }

  private startOfYear(date: Date) {
    return new Date(date.getFullYear(), 0, 1);
  }

  private addDays(date: Date, days: number) {
    const next = new Date(date);
    next.setDate(next.getDate() + days);
    return next;
  }

  private addMonths(date: Date, months: number) {
    return new Date(date.getFullYear(), date.getMonth() + months, 1);
  }

  private bucketKey(date: Date, granularity: 'day' | 'month' | 'year') {
    if (granularity === 'year') return String(date.getFullYear());
    if (granularity === 'month') {
      return `${date.getFullYear()}-${String(date.getMonth() + 1).padStart(2, '0')}`;
    }
    return date.toISOString().slice(0, 10);
  }

  private bucketLabel(date: Date, granularity: 'day' | 'month' | 'year') {
    if (granularity === 'year') return String(date.getFullYear());
    if (granularity === 'month') {
      return date.toLocaleString('en', { month: 'short' });
    }
    return date.toLocaleString('en', { weekday: 'short' });
  }

  private trend(current: number, previous: number) {
    if (previous === 0) return current === 0 ? 0 : 100;
    return this.round(((current - previous) / previous) * 100);
  }

  private rate(numerator: number, denominator: number) {
    return denominator === 0
      ? 0
      : this.round((numerator / denominator) * 100);
  }

  private goalTarget(current: number, floor: number) {
    if (current <= 0) return floor;
    return this.round(Math.max(floor, current * 1.2));
  }

  private sumValues(values: Record<string, number>) {
    return Object.values(values).reduce((total, value) => total + value, 0);
  }

  private timeAgo(date: Date) {
    const seconds = Math.max(0, Math.floor((Date.now() - date.getTime()) / 1000));
    if (seconds < 60) return 'now';
    const minutes = Math.floor(seconds / 60);
    if (minutes < 60) return `${minutes}m`;
    const hours = Math.floor(minutes / 60);
    if (hours < 24) return `${hours}h`;
    return `${Math.floor(hours / 24)}d`;
  }

  private titleCase(value: string) {
    return value
      .split(/\s+/)
      .filter(Boolean)
      .map((part) => part.charAt(0).toUpperCase() + part.slice(1).toLowerCase())
      .join(' ');
  }

  private round(value: number) {
    return Math.round(value * 100) / 100;
  }

  private toNumber(value: number | string | bigint | null | undefined) {
    if (value === null || value === undefined) return 0;
    if (typeof value === 'bigint') return Number(value);
    if (typeof value === 'string') return Number(value) || 0;
    return value;
  }
}
