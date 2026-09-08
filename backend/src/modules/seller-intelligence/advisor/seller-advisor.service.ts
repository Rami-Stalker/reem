import { Injectable } from '@nestjs/common';
import { OfferStatus, SellerOrderStatus } from '@prisma/client';
import { PrismaService } from '../../../prisma/prisma.service';
import { utcCast, utcParam } from '../../../common/sql/utc-timestamp';
import { Diagnosis, DiagnosisFacts, Period, diagnose } from '../kernel/diagnosis';

const dayMs = 24 * 60 * 60 * 1000;

/** The window each half of the comparison covers. */
export const DIAGNOSIS_WINDOW_DAYS = 30;

interface PeriodRow {
  views: number;
  orders: number;
  price: number;
  live_offers: number;
  stock: number;
  best_market_price: number;
  reviews: number;
  rating: number;
}

/**
 * "It was selling and now it is not — what changed?"
 *
 * Compares two equal windows of a listing's own trade and names one cause.
 * The queries are per-listing rather than bulk because this runs when a seller
 * asks about one dress, not on a sweep — and the honest answer needs the
 * competing prices at the time, which is not a number worth denormalising.
 */
@Injectable()
export class SellerAdvisorService {
  constructor(private readonly prisma: PrismaService) {}

  /**
   * Why one of her listings moved.
   *
   * Scoped to the seller: she can only ask about her own. The comparison is
   * over the *product*, not her offer, wherever the question is about the
   * market — being undercut is a fact about the product page she shares with
   * other boutiques, not about her own listing in isolation.
   */
  async diagnoseListing(
    sellerId: string,
    productId: string,
    windowDays = DIAGNOSIS_WINDOW_DAYS,
  ): Promise<{ diagnosis: Diagnosis; window_days: number } | null> {
    const owns = await this.prisma.sellerOffer.findFirst({
      where: { sellerId, productId },
      select: { id: true },
    });
    if (!owns) return null;

    const now = new Date();
    const recentFrom = new Date(now.getTime() - windowDays * dayMs);
    const previousFrom = new Date(now.getTime() - windowDays * 2 * dayMs);

    const [recent, previous, outOfStock, categoryChange] = await Promise.all([
      this.period(sellerId, productId, recentFrom, now, windowDays),
      this.period(sellerId, productId, previousFrom, recentFrom, windowDays),
      this.outOfStockNow(sellerId, productId),
      this.categoryChange(productId, recentFrom, previousFrom, now),
    ]);

    const facts: DiagnosisFacts = {
      recent,
      previous,
      outOfStockNow: outOfStock,
      categoryOrdersChangePercent: categoryChange,
    };

    return { diagnosis: diagnose(facts), window_days: windowDays };
  }

  /**
   * Every listing of hers that fell, worst first.
   *
   * What turns the diagnostic from a thing she has to think to ask about into
   * a thing the dashboard tells her. Bounded, because a boutique with three
   * hundred listings should not wait on three hundred diagnoses.
   */
  async decliningListings(sellerId: string, limit = 10) {
    const candidates = await this.prisma.$queryRawUnsafe<
      { product_id: string; title: string; recent: number; previous: number }[]
    >(
      `
      WITH sold AS (
        SELECT oi.product_id,
               count(*) FILTER (WHERE so.created_at >= ${utcCast('$2')})::int AS recent,
               count(*) FILTER (
                 WHERE so.created_at >= ${utcCast('$3')} AND so.created_at < ${utcCast('$2')}
               )::int AS previous
        FROM order_items oi
        JOIN seller_orders so ON so.id = oi.seller_order_id
        WHERE so.seller_id = $1::uuid
          AND so.created_at >= ${utcCast('$3')}
          AND so.status = ANY($4::"SellerOrderStatus"[])
        GROUP BY oi.product_id
      )
      SELECT sold.product_id, p.title, sold.recent, sold.previous
      FROM sold
      JOIN products p ON p.id = sold.product_id
      -- Only listings that were selling and stopped. A listing that never
      -- sold has nothing to diagnose; it has something to fix, which is what
      -- product health is for.
      WHERE sold.previous >= 3 AND sold.recent < sold.previous * 0.75
      ORDER BY (sold.previous - sold.recent) DESC
      LIMIT $5
      `,
      sellerId,
      utcParam(new Date(Date.now() - DIAGNOSIS_WINDOW_DAYS * dayMs)),
      utcParam(new Date(Date.now() - DIAGNOSIS_WINDOW_DAYS * 2 * dayMs)),
      [
        SellerOrderStatus.DELIVERED,
        SellerOrderStatus.EXCHANGED,
        SellerOrderStatus.IN_TRANSIT,
        SellerOrderStatus.HANDED_TO_COURIER,
        SellerOrderStatus.PREPARING,
      ],
      limit,
    );

    const out = [];
    for (const candidate of candidates) {
      const result = await this.diagnoseListing(sellerId, candidate.product_id);
      if (!result) continue;
      out.push({
        product_id: candidate.product_id,
        title: candidate.title,
        orders_now: candidate.recent,
        orders_before: candidate.previous,
        diagnosis: {
          code: result.diagnosis.code,
          title: result.diagnosis.ar,
          action: result.diagnosis.actionAr,
          also: result.diagnosis.alsoAr,
          evidence: result.diagnosis.evidence,
        },
      });
    }
    return out;
  }

  // ── internals ────────────────────────────────────────────────────────────

  private async period(
    sellerId: string,
    productId: string,
    from: Date,
    to: Date,
    days: number,
  ): Promise<Period> {
    const rows = await this.prisma.$queryRawUnsafe<PeriodRow[]>(
      `
      SELECT
        (SELECT count(*)::int FROM analytics_events e
          WHERE e.product_id = $1::uuid
            AND e.type = 'PRODUCT_VIEW'
            AND e.occurred_at >= ${utcCast('$3')} AND e.occurred_at < ${utcCast('$4')}
        ) AS views,
        (SELECT count(*)::int FROM order_items oi
          JOIN seller_orders so ON so.id = oi.seller_order_id
          WHERE oi.product_id = $1::uuid
            AND so.seller_id = $2::uuid
            AND so.created_at >= ${utcCast('$3')} AND so.created_at < ${utcCast('$4')}
            AND so.status = ANY($5::"SellerOrderStatus"[])
        ) AS orders,
        coalesce((SELECT o.price_syp FROM seller_offers o
          WHERE o.product_id = $1::uuid AND o.seller_id = $2::uuid LIMIT 1
        ), 0)::float8 AS price,
        (SELECT count(*)::int FROM seller_offers o2
          WHERE o2.product_id = $1::uuid AND o2.status = $6::"OfferStatus"
            AND o2.is_active AND o2.stock > 0
        ) AS live_offers,
        coalesce((SELECT o3.stock FROM seller_offers o3
          WHERE o3.product_id = $1::uuid AND o3.seller_id = $2::uuid LIMIT 1
        ), 0)::int AS stock,
        coalesce((SELECT min(o4.price_syp) FROM seller_offers o4
          WHERE o4.product_id = $1::uuid AND o4.status = $6::"OfferStatus"
            AND o4.is_active AND o4.stock > 0
        ), 0)::float8 AS best_market_price,
        (SELECT count(*)::int FROM product_reviews r
          WHERE r.product_id = $1::uuid AND r.created_at < ${utcCast('$4')}
        ) AS reviews,
        coalesce((SELECT avg(r2.rating) FROM product_reviews r2
          WHERE r2.product_id = $1::uuid AND r2.created_at < ${utcCast('$4')}
        ), 0)::float8 AS rating
      `,
      productId,
      sellerId,
      utcParam(from),
      utcParam(to),
      [
        SellerOrderStatus.DELIVERED,
        SellerOrderStatus.EXCHANGED,
        SellerOrderStatus.IN_TRANSIT,
        SellerOrderStatus.HANDED_TO_COURIER,
        SellerOrderStatus.PREPARING,
      ],
      OfferStatus.ACTIVE,
    );

    const row = rows[0];
    return {
      views: row?.views ?? 0,
      orders: row?.orders ?? 0,
      price: row?.price ?? 0,
      liveOffers: row?.live_offers ?? 0,
      stock: row?.stock ?? 0,
      bestMarketPrice: row?.best_market_price ?? 0,
      reviews: row?.reviews ?? 0,
      rating: row?.rating ?? 0,
      days,
    };
  }

  /**
   * Whether her shelf is empty right now.
   *
   * A flag rather than a duration: Reem does not journal stock changes, so a
   * day count would be invented, and an invented number reads as precise on a
   * screen somebody acts on. See the note on `DiagnosisFacts.outOfStockNow`.
   */
  private async outOfStockNow(
    sellerId: string,
    productId: string,
  ): Promise<boolean> {
    const offer = await this.prisma.sellerOffer.findFirst({
      where: { sellerId, productId },
      select: { stock: true },
    });
    return !offer || offer.stock <= 0;
  }

  /** How the whole category moved over the same two windows. */
  private async categoryChange(
    productId: string,
    recentFrom: Date,
    previousFrom: Date,
    now: Date,
  ): Promise<number | null> {
    const rows = await this.prisma.$queryRawUnsafe<
      { recent: number; previous: number }[]
    >(
      `
      SELECT
        count(*) FILTER (WHERE so.created_at >= ${utcCast('$2')})::int AS recent,
        count(*) FILTER (
          WHERE so.created_at >= ${utcCast('$3')} AND so.created_at < ${utcCast('$2')}
        )::int AS previous
      FROM order_items oi
      JOIN seller_orders so ON so.id = oi.seller_order_id
      JOIN products p ON p.id = oi.product_id
      WHERE p.category_id = (SELECT category_id FROM products WHERE id = $1::uuid)
        AND so.created_at >= ${utcCast('$3')}
        AND so.created_at < ${utcCast('$4')}
      `,
      productId,
      utcParam(recentFrom),
      utcParam(previousFrom),
      utcParam(now),
    );

    const row = rows[0];
    if (!row || row.previous < 10) {
      // Too few orders in the category for a change to mean anything. Null
      // rather than zero: "the category did not move" and "nobody knows what
      // the category did" are different claims.
      return null;
    }
    return (row.recent - row.previous) / row.previous;
  }
}
