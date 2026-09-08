import { Injectable } from '@nestjs/common';
import { OfferStatus, ProductStatus, UserRole } from '@prisma/client';
import { PrismaService } from '../../prisma/prisma.service';
import { utcCast, utcParam } from '../../common/sql/utc-timestamp';
import {
  Audience,
  LIFECYCLE_STAGES,
  LifecycleStage,
  SEGMENT_RULES,
  STAGE_LABELS,
} from './customer-segments';

const dayMs = 24 * 60 * 60 * 1000;
const hourMs = 60 * 60 * 1000;

/** One customer, and what she is worth reaching about. */
export interface SegmentedCustomer {
  userId: string;
  stage: LifecycleStage;
  orders: number;
  lastOrderAt: Date | null;
}

/** A basket somebody walked away from. */
export interface AbandonedBasket {
  userId: string;
  /** Changes whenever she touches the basket, so a nudge is sent once per basket. */
  fingerprint: string;
  items: number;
  lastTouchedAt: Date;
  /** The last thing she put in it, so a reminder can name something real. */
  leadTitle: string | null;
}

/**
 * Which customers are in which stage, and who has left something behind.
 *
 * Computed on demand rather than stored on the user row. A stored stage is a
 * stage that is wrong between nightly runs — a woman who bought this morning
 * would still read as `lapsed` to a campaign that went out at noon, and the
 * win-back discount she was sent would be an insult as well as a loss.
 */
@Injectable()
export class CustomerSegmentsService {
  constructor(private readonly prisma: PrismaService) {}

  /**
   * Everyone in one stage.
   *
   * Guests are excluded throughout: no account to segment, no inbox to reach,
   * no history to place them in a stage.
   */
  async stage(
    stage: LifecycleStage,
    limit: number,
  ): Promise<SegmentedCustomer[]> {
    const rows = await this.query(
      `SELECT h.user_id, h.orders, h.last_order_at
       FROM history h
       LEFT JOIN looked l ON l.user_id = h.user_id
       CROSS JOIN bounds b
       WHERE ${this.stagePredicate(stage)}
       ORDER BY h.last_order_at DESC NULLS LAST
       LIMIT $5`,
      limit,
    );

    return rows.map((row) => ({
      userId: row.user_id,
      stage,
      orders: row.orders,
      lastOrderAt: row.last_order_at,
    }));
  }

  /**
   * How many customers sit in each stage.
   *
   * The one screen that says whether the marketplace is growing or churning: a
   * shop can add customers every month and still be shrinking if every one of
   * them stops at `first_time`.
   *
   * Counted in a single pass rather than seven, because the stages are
   * mutually exclusive and a `CASE` can therefore assign each customer once.
   */
  async distribution(): Promise<
    { stage: LifecycleStage; ar: string; why: string; customers: number }[]
  > {
    const cases = LIFECYCLE_STAGES.map(
      (stage) => `WHEN ${this.stagePredicate(stage)} THEN '${stage}'`,
    ).join('\n             ');

    const rows = await this.prisma.$queryRawUnsafe<
      { stage: string; customers: number }[]
    >(
      `
      ${this.preamble()}
      SELECT CASE ${cases} ELSE 'prospect' END AS stage,
             count(*)::int AS customers
      FROM history h
      LEFT JOIN looked l ON l.user_id = h.user_id
      CROSS JOIN bounds b
      GROUP BY 1
      `,
      ...this.preambleParams(),
    );

    const found = new Map(rows.map((row) => [row.stage, row.customers]));
    return LIFECYCLE_STAGES.map((stage) => ({
      stage,
      ...STAGE_LABELS[stage],
      customers: found.get(stage) ?? 0,
    }));
  }

  /** Which stage one customer is in — for a profile screen, or a rule. */
  async stageOf(userId: string): Promise<LifecycleStage> {
    const cases = LIFECYCLE_STAGES.map(
      (stage) => `WHEN ${this.stagePredicate(stage)} THEN '${stage}'`,
    ).join('\n             ');

    const rows = await this.prisma.$queryRawUnsafe<{ stage: string }[]>(
      `
      ${this.preamble()}
      SELECT CASE ${cases} ELSE 'prospect' END AS stage
      FROM history h
      LEFT JOIN looked l ON l.user_id = h.user_id
      CROSS JOIN bounds b
      WHERE h.user_id = $5::uuid
      `,
      ...this.preambleParams(),
      userId,
    );

    const stage = rows[0]?.stage as LifecycleStage | undefined;
    return stage && LIFECYCLE_STAGES.includes(stage) ? stage : 'prospect';
  }

  /**
   * Baskets somebody filled and walked away from.
   *
   * "Abandoned" is a basket untouched for a few hours with no order placed
   * since. That order check is what stops the commonest false positive: a
   * woman who checked out is not somebody to remind, and without it every
   * successful customer is "abandoned" for four hours after buying.
   *
   * Only live, in-stock offers count. A reminder about a dress that sold out
   * is worse than no reminder at all.
   */
  async abandonedBaskets(limit: number): Promise<AbandonedBasket[]> {
    const staleBefore = new Date(
      Date.now() - SEGMENT_RULES.abandonedAfterHours * hourMs,
    );
    const freshAfter = new Date(
      Date.now() - SEGMENT_RULES.abandonedUntilDays * dayMs,
    );

    const rows = await this.prisma.$queryRawUnsafe<
      {
        user_id: string;
        items: number;
        last_touched_at: Date;
        lead_title: string | null;
      }[]
    >(
      `
      WITH basket AS (
        SELECT ci.user_id,
               count(*)::int AS items,
               max(ci.updated_at) AS last_touched_at
        FROM cart_items ci
        JOIN seller_offers so ON so.id = ci.offer_id
        JOIN products p ON p.id = so.product_id
        WHERE so.status = $1::"OfferStatus"
          AND so.is_active
          AND so.stock > 0
          AND p.status = $2::"ProductStatus"
        GROUP BY ci.user_id
        HAVING max(ci.updated_at) < ${utcCast('$3')}
           AND max(ci.updated_at) > ${utcCast('$4')}
      )
      SELECT b.user_id, b.items, b.last_touched_at,
             (
               SELECT p2.title
               FROM cart_items ci2
               JOIN seller_offers so2 ON so2.id = ci2.offer_id
               JOIN products p2 ON p2.id = so2.product_id
               WHERE ci2.user_id = b.user_id
               ORDER BY ci2.updated_at DESC
               LIMIT 1
             ) AS lead_title
      FROM basket b
      JOIN users u ON u.id = b.user_id
      WHERE u.disabled_at IS NULL
        AND NOT EXISTS (
          SELECT 1 FROM orders o
          WHERE o.user_id = b.user_id
            AND o.created_at >= b.last_touched_at
        )
      ORDER BY b.last_touched_at DESC
      LIMIT $5
      `,
      OfferStatus.ACTIVE,
      ProductStatus.ACTIVE,
      utcParam(staleBefore),
      utcParam(freshAfter),
      limit,
    );

    return rows.map((row) => ({
      userId: row.user_id,
      // Changes when she adds, removes or re-touches anything, which is what
      // makes "one nudge per basket" mean this basket rather than ever.
      fingerprint: `${row.items}:${row.last_touched_at.toISOString()}`,
      items: row.items,
      lastTouchedAt: row.last_touched_at,
      leadTitle: row.lead_title,
    }));
  }

  /** The customers a cross-cutting audience holds. */
  async audience(audience: Audience, limit: number): Promise<string[]> {
    if (audience === 'abandoned_cart') {
      return (await this.abandonedBaskets(limit)).map((basket) => basket.userId);
    }
    const rows = await this.prisma.membershipAccount.findMany({
      where: { vip: true, user: { disabledAt: null } },
      select: { userId: true },
      take: limit,
    });
    return rows.map((row) => row.userId);
  }

  // ── internals ────────────────────────────────────────────────────────────

  private async query(tail: string, limit: number) {
    return this.prisma.$queryRawUnsafe<
      { user_id: string; orders: number; last_order_at: Date | null }[]
    >(`${this.preamble()}\n${tail}`, ...this.preambleParams(), limit);
  }

  /**
   * The shared CTEs.
   *
   * `bounds` exists so every date parameter is referenced and typed exactly
   * once. Interpolating them into each branch instead left `$3` and `$4`
   * unmentioned for the two stages that do not need dates, and PostgreSQL
   * refuses a statement whose parameters it cannot infer a type for — a
   * failure that only shows up on the two stages nobody tests first.
   */
  private preamble(): string {
    return `
      WITH bounds AS (
        SELECT ${utcCast('$2')} AS loyal_since,
               ${utcCast('$3')} AS at_risk_before,
               ${utcCast('$4')} AS lapsed_before
      ),
      history AS (
        SELECT u.id AS user_id,
               count(o.id)::int AS orders,
               max(o.created_at) AS last_order_at,
               count(o.id) FILTER (
                 WHERE o.created_at >= (SELECT loyal_since FROM bounds)
               )::int AS recent_orders
        FROM users u
        LEFT JOIN orders o ON o.user_id = u.id
        WHERE u.role = $1::"UserRole"
          AND u.disabled_at IS NULL
        GROUP BY u.id
      ),
      looked AS (
        SELECT DISTINCT f.user_id FROM favorites f
      )`;
  }

  private preambleParams(): [string, string, string, string] {
    const now = Date.now();
    return [
      UserRole.CUSTOMER,
      utcParam(new Date(now - SEGMENT_RULES.loyalWindowDays * dayMs)),
      utcParam(new Date(now - SEGMENT_RULES.atRiskAfterDays * dayMs)),
      utcParam(new Date(now - SEGMENT_RULES.lapsedAfterDays * dayMs)),
    ];
  }

  /**
   * The SQL for one stage.
   *
   * Every branch reads the same `history` CTE, so the definitions cannot drift
   * apart, and the stages are mutually exclusive by construction — each one
   * excludes the warmer conditions above it, which is what lets `distribution`
   * assign each customer exactly once with a `CASE`.
   */
  private stagePredicate(stage: LifecycleStage): string {
    const active = 'h.last_order_at >= b.at_risk_before';
    switch (stage) {
      case 'prospect':
        return 'h.orders = 0 AND l.user_id IS NULL';
      case 'window_shopper':
        return 'h.orders = 0 AND l.user_id IS NOT NULL';
      case 'first_time':
        return `h.orders = 1 AND ${active}`;
      case 'repeat':
        return `h.orders >= ${SEGMENT_RULES.repeatOrders} AND h.recent_orders < ${SEGMENT_RULES.loyalOrders} AND ${active}`;
      case 'loyal':
        return `h.recent_orders >= ${SEGMENT_RULES.loyalOrders} AND ${active}`;
      case 'at_risk':
        // Quiet for two months, but not yet five.
        return `h.orders > 0 AND h.last_order_at < b.at_risk_before AND h.last_order_at >= b.lapsed_before`;
      case 'lapsed':
        return `h.orders > 0 AND h.last_order_at < b.lapsed_before`;
      default:
        return 'FALSE';
    }
  }
}
