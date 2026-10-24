import { Injectable } from '@nestjs/common';
import {
  AnalyticsEventType,
  ReturnStatus,
  SellerOrderStatus,
} from '@prisma/client';
import { PrismaService } from '../../prisma/prisma.service';
import { REVENUE_STATUSES } from '../../common/money';
import { utcCast, utcParam } from '../../common/sql/utc-timestamp';
import { CustomerFacts } from './kernel/customer-facts';

const dayMs = 24 * 60 * 60 * 1000;

/** The engagement window. Long enough to smooth a quiet fortnight. */
export const ENGAGEMENT_WINDOW_DAYS = 45;

/** The rhythm window. Longer, because an hour-of-day histogram needs volume. */
export const RHYTHM_WINDOW_DAYS = 120;

/** Events that say something about *her*, rather than about the feed. */
const INTENT_EVENTS = [
  AnalyticsEventType.APP_OPEN,
  AnalyticsEventType.PRODUCT_VIEW,
  AnalyticsEventType.PRODUCT_SEARCH,
  AnalyticsEventType.CART_ADD,
  AnalyticsEventType.PRODUCT_FAVORITE,
  AnalyticsEventType.CHECKOUT_START,
  AnalyticsEventType.SEARCH_RESULT_CLICK,
];

/**
 * Gathers what the customer scorers are allowed to know.
 *
 * Deliberately excludes `PRODUCT_IMPRESSION`. A card entering the viewport is
 * a fact about how the feed was laid out, not about what she wanted, and it is
 * the highest-volume event there is — letting it into an intent score would
 * mean the score mostly measures how much scrolling the app does.
 */
@Injectable()
export class CustomerFactsService {
  constructor(private readonly prisma: PrismaService) {}

  async forCustomer(userId: string): Promise<CustomerFacts> {
    const now = Date.now();
    const engagementSince = new Date(now - ENGAGEMENT_WINDOW_DAYS * dayMs);
    const rhythmSince = new Date(now - RHYTHM_WINDOW_DAYS * dayMs);

    const [purchases, engagement, rhythm] = await Promise.all([
      this.purchases(userId, now),
      this.engagement(userId, engagementSince, now),
      this.rhythm(userId, rhythmSince),
    ]);

    return { purchases, engagement, rhythm };
  }

  /**
   * Her trading history.
   *
   * Spend is merchandise net of discount on revenue-bearing parcels — the same
   * definition the economics report uses for GMV, so a customer's realised
   * value and the marketplace's GMV cannot disagree about the same order.
   */
  private async purchases(userId: string, now: number) {
    const [agg, refunds, refundedValue] = await Promise.all([
      this.prisma.$queryRawUnsafe<
        {
          orders: number;
          spend: string;
          first_at: Date | null;
          last_at: Date | null;
        }[]
      >(
        `
        SELECT count(DISTINCT o.id)::int AS orders,
               coalesce(sum(so.items_subtotal - so.discount_total), 0)::text AS spend,
               min(o.created_at) AS first_at,
               max(o.created_at) AS last_at
        FROM orders o
        JOIN seller_orders so ON so.order_id = o.id
        WHERE o.user_id = $1::uuid
          AND so.status = ANY($2::"SellerOrderStatus"[])
        `,
        userId,
        REVENUE_STATUSES as SellerOrderStatus[],
      ),
      this.prisma.returnRequest.count({
        where: {
          status: ReturnStatus.REFUNDED,
          sellerOrder: { order: { userId } },
        },
      }),
      this.prisma.$queryRawUnsafe<{ refunded: string }[]>(
        `
        SELECT coalesce(sum(so.items_subtotal - so.discount_total), 0)::text AS refunded
        FROM return_requests r
        JOIN seller_orders so ON so.id = r.seller_order_id
        JOIN orders o ON o.id = so.order_id
        WHERE o.user_id = $1::uuid AND r.status = $2::"ReturnStatus"
        `,
        userId,
        ReturnStatus.REFUNDED,
      ),
    ]);

    const row = agg[0];
    const days = (at: Date | null) =>
      at ? Math.max(0, Math.floor((now - at.getTime()) / dayMs)) : null;

    return {
      orders: row?.orders ?? 0,
      lifetimeSpend: Number(row?.spend ?? 0),
      daysSinceFirstOrder: days(row?.first_at ?? null),
      daysSinceLastOrder: days(row?.last_at ?? null),
      refundedOrders: refunds,
      refundedSpend: Number(refundedValue[0]?.refunded ?? 0),
    };
  }

  /** What she has been doing when not buying. */
  private async engagement(userId: string, since: Date, now: number) {
    const [counts, lastSeen, cart, user] = await Promise.all([
      this.prisma.analyticsEvent.groupBy({
        by: ['type'],
        where: {
          userId,
          type: { in: INTENT_EVENTS },
          occurredAt: { gte: since },
        },
        _count: { _all: true },
      }),
      this.prisma.analyticsEvent.findFirst({
        where: { userId },
        orderBy: { occurredAt: 'desc' },
        select: { occurredAt: true },
      }),
      this.prisma.cartItem.count({ where: { userId } }),
      this.prisma.user.findUnique({
        where: { id: userId },
        select: { createdAt: true, lastLoginAt: true },
      }),
    ]);

    const of = (type: AnalyticsEventType) =>
      counts.find((row) => row.type === type)?._count._all ?? 0;

    // Her last sign of life is the later of an event and a login: a woman who
    // opened the app without the client reporting an event is not dormant.
    const lastEvent = lastSeen?.occurredAt ?? null;
    const lastLogin = user?.lastLoginAt ?? null;
    const seenAt =
      lastEvent && lastLogin
        ? lastEvent > lastLogin
          ? lastEvent
          : lastLogin
        : (lastEvent ?? lastLogin);

    return {
      daysSinceLastSeen: seenAt
        ? Math.max(0, Math.floor((now - seenAt.getTime()) / dayMs))
        : null,
      appOpens: of(AnalyticsEventType.APP_OPEN),
      productViews: of(AnalyticsEventType.PRODUCT_VIEW),
      searches:
        of(AnalyticsEventType.PRODUCT_SEARCH) +
        of(AnalyticsEventType.SEARCH_RESULT_CLICK),
      cartAdds: of(AnalyticsEventType.CART_ADD),
      favourites: of(AnalyticsEventType.PRODUCT_FAVORITE),
      windowDays: ENGAGEMENT_WINDOW_DAYS,
      hasOpenCart: cart > 0,
      accountAgeDays: user?.createdAt
        ? Math.max(0, Math.floor((now - user.createdAt.getTime()) / dayMs))
        : null,
    };
  }

  /**
   * When she is awake, as a 24-bucket histogram.
   *
   * Counted in the platform's own timezone rather than UTC, because the answer
   * is used to schedule a message a woman in Damascus will read — an hour
   * computed in UTC would send the evening notification at lunchtime.
   */
  private async rhythm(userId: string, since: Date) {
    const rows = await this.prisma.$queryRawUnsafe<
      { hour: number; n: number }[]
    >(
      `
      SELECT extract(hour FROM (e.occurred_at AT TIME ZONE 'UTC' AT TIME ZONE $3))::int AS hour,
             count(*)::int AS n
      FROM analytics_events e
      WHERE e.user_id = $1::uuid
        AND e.occurred_at >= ${utcCast('$2')}
        AND e.type <> 'PRODUCT_IMPRESSION'
      GROUP BY 1
      `,
      userId,
      utcParam(since),
      PLATFORM_TIMEZONE,
    );

    const activityByHour = new Array(24).fill(0) as number[];
    let observations = 0;
    for (const row of rows) {
      if (row.hour >= 0 && row.hour < 24) {
        activityByHour[row.hour] = row.n;
        observations += row.n;
      }
    }

    return { activityByHour, observations };
  }
}

/**
 * Where Ohara's customers are.
 *
 * A constant rather than a per-customer field: the platform serves one country,
 * and inventing a timezone column nobody populates would make every contact
 * hour silently UTC anyway. When Ohara sells outside Syria this becomes a
 * property of the customer, and this is the one place that changes.
 */
export const PLATFORM_TIMEZONE = 'Asia/Damascus';
