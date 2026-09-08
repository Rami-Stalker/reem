import { Injectable } from '@nestjs/common';
import { SellerOrderStatus, UserRole } from '@prisma/client';
import { PrismaService } from '../../prisma/prisma.service';
import { Money } from '../../common/money';
import { utcCast, utcParam } from '../../common/sql/utc-timestamp';
import { REVENUE_STATUSES } from '../../common/money';

const dayMs = 24 * 60 * 60 * 1000;

/** How far back a boutique's customer book reaches by default. */
const CRM_WINDOW_DAYS = 365;

/**
 * Silence after her last order from *this boutique* that reads as gone.
 *
 * Shorter than the platform's own lapsed threshold, deliberately. A customer
 * who has not bought from Reem in five months is lapsed from Reem; a customer
 * who has not bought from this boutique in three months while buying happily
 * elsewhere is a customer this boutique lost, and that is the thing the seller
 * can actually do something about.
 */
const SELLER_LAPSED_DAYS = 90;

export interface SellerCustomer {
  userId: string;
  name: string | null;
  username: string | null;
  orders: number;
  units: number;
  spend: Money;
  firstOrderAt: Date;
  lastOrderAt: Date;
  /** True once she has bought from this boutique more than once. */
  isRepeat: boolean;
  /** Quiet long enough that the boutique has probably lost her. */
  isLapsed: boolean;
}

/**
 * A boutique's own customer book.
 *
 * The seller dashboard could tell her what sold and how her shop was rated. It
 * could not tell her *who* — how many of her buyers came back, which ones
 * spent the most, which ones have stopped. Every one of those is a question a
 * shopkeeper asks about her own shop, and none of them could be answered.
 *
 * What this deliberately does not do is hand a seller a marketing list. She
 * sees who bought from her, what they spent and when they stopped, because
 * those are facts about her own trade. She does not get phone numbers, and
 * there is no bulk-message endpoint here: reaching customers goes through the
 * platform's own notification rules, where a woman's preferences are honoured.
 */
@Injectable()
export class SellerCrmService {
  constructor(private readonly prisma: PrismaService) {}

  /** Who has bought from this boutique, biggest spenders first. */
  async customers(
    sellerId: string,
    options: { limit: number; skip: number; windowDays?: number },
  ): Promise<{ data: SellerCustomer[]; total: number }> {
    const since = new Date(
      Date.now() - (options.windowDays ?? CRM_WINDOW_DAYS) * dayMs,
    );

    const rows = await this.prisma.$queryRawUnsafe<
      {
        user_id: string;
        name: string | null;
        username: string | null;
        orders: number;
        units: number;
        spend: string;
        currency: string;
        first_order_at: Date;
        last_order_at: Date;
      }[]
    >(
      `
      SELECT o.user_id,
             u.name, u.username,
             count(DISTINCT so.id)::int AS orders,
             coalesce(sum(oi.quantity), 0)::int AS units,
             coalesce(sum(so.items_subtotal - so.discount_total), 0)::text AS spend,
             min(so.currency::text) AS currency,
             min(so.created_at) AS first_order_at,
             max(so.created_at) AS last_order_at
      FROM seller_orders so
      JOIN orders o ON o.id = so.order_id
      JOIN users u ON u.id = o.user_id
      LEFT JOIN order_items oi ON oi.seller_order_id = so.id
      WHERE so.seller_id = $1::uuid
        AND so.status = ANY($2::"SellerOrderStatus"[])
        AND so.created_at >= ${utcCast('$3')}
        AND o.user_id IS NOT NULL
      GROUP BY o.user_id, u.name, u.username
      ORDER BY sum(so.items_subtotal - so.discount_total) DESC
      LIMIT $4 OFFSET $5
      `,
      sellerId,
      REVENUE_STATUSES as SellerOrderStatus[],
      utcParam(since),
      options.limit,
      options.skip,
    );

    const totalRows = await this.prisma.$queryRawUnsafe<{ n: number }[]>(
      `
      SELECT count(DISTINCT o.user_id)::int AS n
      FROM seller_orders so
      JOIN orders o ON o.id = so.order_id
      WHERE so.seller_id = $1::uuid
        AND so.status = ANY($2::"SellerOrderStatus"[])
        AND so.created_at >= ${utcCast('$3')}
        AND o.user_id IS NOT NULL
      `,
      sellerId,
      REVENUE_STATUSES as SellerOrderStatus[],
      utcParam(since),
    );

    const lapsedBefore = Date.now() - SELLER_LAPSED_DAYS * dayMs;

    return {
      data: rows.map((row) => ({
        userId: row.user_id,
        name: row.name,
        username: row.username,
        orders: row.orders,
        units: row.units,
        spend: Money.of(row.spend, row.currency as never),
        firstOrderAt: row.first_order_at,
        lastOrderAt: row.last_order_at,
        isRepeat: row.orders > 1,
        isLapsed: row.last_order_at.getTime() < lapsedBefore,
      })),
      total: totalRows[0]?.n ?? 0,
    };
  }

  /**
   * The shape of her customer base, in the four numbers that matter.
   *
   * Repeat rate is the one to read first. A boutique whose repeat rate is
   * falling is a boutique buying every sale twice — once in acquisition and
   * once again next month — and it is the earliest warning she gets.
   */
  async overview(sellerId: string, windowDays = CRM_WINDOW_DAYS) {
    const since = new Date(Date.now() - windowDays * dayMs);
    const lapsedSince = new Date(Date.now() - SELLER_LAPSED_DAYS * dayMs);

    const rows = await this.prisma.$queryRawUnsafe<
      {
        customers: number;
        repeat_customers: number;
        lapsed_customers: number;
        orders: number;
        revenue: string;
        currency: string | null;
      }[]
    >(
      `
      WITH per_customer AS (
        SELECT o.user_id,
               count(DISTINCT so.id)::int AS orders,
               max(so.created_at) AS last_order_at,
               sum(so.items_subtotal - so.discount_total) AS spend,
               min(so.currency::text) AS currency
        FROM seller_orders so
        JOIN orders o ON o.id = so.order_id
        WHERE so.seller_id = $1::uuid
          AND so.status = ANY($2::"SellerOrderStatus"[])
          AND so.created_at >= ${utcCast('$3')}
          AND o.user_id IS NOT NULL
        GROUP BY o.user_id
      )
      SELECT count(*)::int AS customers,
             count(*) FILTER (WHERE orders > 1)::int AS repeat_customers,
             count(*) FILTER (WHERE last_order_at < ${utcCast('$4')})::int AS lapsed_customers,
             coalesce(sum(orders), 0)::int AS orders,
             coalesce(sum(spend), 0)::text AS revenue,
             min(currency) AS currency
      FROM per_customer
      `,
      sellerId,
      REVENUE_STATUSES as SellerOrderStatus[],
      utcParam(since),
      utcParam(lapsedSince),
    );

    const row = rows[0];
    const customers = row?.customers ?? 0;
    const currency = (row?.currency ?? 'SYP') as never;
    const revenue = Money.of(row?.revenue ?? 0, currency);

    return {
      window_days: windowDays,
      customers,
      repeat_customers: row?.repeat_customers ?? 0,
      // Null rather than 0 when nobody has bought: "no repeat rate" and "a
      // repeat rate of nothing" say different things about a new shop.
      repeat_rate:
        customers > 0
          ? Number(((row?.repeat_customers ?? 0) / customers).toFixed(4))
          : null,
      lapsed_customers: row?.lapsed_customers ?? 0,
      lapsed_after_days: SELLER_LAPSED_DAYS,
      orders: row?.orders ?? 0,
      revenue: revenue.toJSON(),
      revenue_per_customer:
        customers > 0
          ? revenue.dividedBy(customers).toJSON()
          : Money.zero(currency).toJSON(),
    };
  }

  /**
   * Boutiques going quiet, for the platform rather than for the seller.
   *
   * Seller retention is the mirror of customer retention and was equally
   * unbuilt. A marketplace loses sellers the same way it loses customers —
   * gradually, and invisibly, because nothing was counting. A shop that listed
   * nothing new and sold nothing for weeks has usually already decided; the
   * window here is short enough that somebody can still call her.
   */
  async quietSellers(options: { quietDays: number; limit: number }) {
    const quietBefore = new Date(Date.now() - options.quietDays * dayMs);

    return this.prisma.$queryRawUnsafe<
      {
        seller_id: string;
        name: string | null;
        username: string | null;
        live_listings: number;
        last_order_at: Date | null;
        last_listed_at: Date | null;
        lifetime_orders: number;
      }[]
    >(
      `
      SELECT u.id AS seller_id, u.name, u.username,
             count(DISTINCT so2.id) FILTER (
               WHERE so2.status = 'ACTIVE' AND so2.is_active
             )::int AS live_listings,
             max(ord.created_at) AS last_order_at,
             max(so2.created_at) AS last_listed_at,
             count(DISTINCT ord.id)::int AS lifetime_orders
      FROM users u
      LEFT JOIN seller_offers so2 ON so2.seller_id = u.id
      LEFT JOIN seller_orders ord ON ord.seller_id = u.id
      WHERE u.role = $1::"UserRole"
        AND u.disabled_at IS NULL
      GROUP BY u.id, u.name, u.username
      -- She sold before, and has sold nothing since. A shop that never sold
      -- anything is an onboarding problem, not a retention one, and belongs
      -- on a different screen.
      HAVING count(DISTINCT ord.id) > 0
         AND max(ord.created_at) < ${utcCast('$2')}
      ORDER BY count(DISTINCT ord.id) DESC
      LIMIT $3
      `,
      UserRole.SELLER,
      utcParam(quietBefore),
      options.limit,
    );
  }
}
