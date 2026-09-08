import { Injectable, Logger } from '@nestjs/common';
import {
  OfferStatus,
  Prisma,
  ProductStatus,
  ReturnStatus,
  SellerOrderStatus,
  UserRole,
} from '@prisma/client';
import { PrismaService } from '../../prisma/prisma.service';
import { utcCast, utcParam } from '../../common/sql/utc-timestamp';
import {
  ListingFacts,
  RankResult,
  SellerRankFacts,
  scoreListing,
  scoreSeller,
} from './kernel/rank';

const dayMs = 24 * 60 * 60 * 1000;

/** The window a boutique is judged over. A season. */
const SELLER_WINDOW_DAYS = 120;

interface ListingRow {
  id: string;
  views: number;
  orders: number;
  favourites: number;
  reviews: number;
  rating: number;
  live_offers: number;
  stock: number;
  age_days: number;
  days_since_last_order: number | null;
  recent_orders: number;
  refunds: number;
}

interface SellerRow {
  id: string;
  delivered: number;
  cancelled: number;
  refunded: number;
  rating: number;
  reviews: number;
  live_listings: number;
  response_hours: number | null;
  days_since_last_sale: number | null;
}

/**
 * Keeps every listing's and boutique's position current.
 *
 * The scoring itself is in the kernel and knows nothing about a database. This
 * gathers the facts in bulk — one query for a whole page of listings rather
 * than one per listing — because the sweep has to be able to run over the
 * whole catalogue inside a nightly window, and a per-row round trip is the
 * usual reason that stops being true.
 */
@Injectable()
export class RankingService {
  private readonly logger = new Logger(RankingService.name);

  constructor(private readonly prisma: PrismaService) {}

  // ── Listings ─────────────────────────────────────────────────────────────

  /**
   * Recomputes listing positions.
   *
   * Bounded and ordered oldest-scored-first, so repeated bounded runs cover
   * the catalogue rather than rescoring the same first page every night.
   */
  async sweepListings(limit = 2000) {
    const rows = await this.listingFacts(limit);
    let updated = 0;

    for (const row of rows) {
      const result = scoreListing(this.toListingFacts(row));
      try {
        await this.prisma.product.update({
          where: { id: row.id },
          data: {
            rankScore: result.score,
            rankScoredAt: new Date(),
            rankBreakdown: {
              components: result.components,
              confident: result.confident,
            } as unknown as Prisma.InputJsonValue,
            // The card's own facts, written by the same pass that scored the
            // listing — so a scarcity badge and the ranking can never
            // disagree about the same shelf.
            liveOffersCount: row.live_offers,
            liveStock: row.stock,
            recentOrders30: row.recent_orders,
          },
        });
        updated += 1;
      } catch (error) {
        this.logger.warn(`Listing ${row.id} not scored: ${String(error)}`);
      }
    }

    return { scanned: rows.length, updated };
  }

  /** One listing's position and the reasons for it. */
  async explainListing(productId: string): Promise<RankResult | null> {
    const rows = await this.listingFacts(1, productId);
    if (rows.length === 0) return null;
    return scoreListing(this.toListingFacts(rows[0]));
  }

  // ── Boutiques ────────────────────────────────────────────────────────────

  async sweepSellers(limit = 1000) {
    const rows = await this.sellerFacts(limit);
    let updated = 0;

    for (const row of rows) {
      const result = scoreSeller(this.toSellerFacts(row));
      try {
        await this.prisma.user.update({
          where: { id: row.id },
          data: {
            sellerRankScore: result.score,
            sellerRankScoredAt: new Date(),
            sellerRankBreakdown: {
              components: result.components,
              confident: result.confident,
            } as unknown as Prisma.InputJsonValue,
          },
        });
        updated += 1;
      } catch (error) {
        this.logger.warn(`Seller ${row.id} not scored: ${String(error)}`);
      }
    }

    return { scanned: rows.length, updated };
  }

  async explainSeller(sellerId: string): Promise<RankResult | null> {
    const rows = await this.sellerFacts(1, sellerId);
    if (rows.length === 0) return null;
    return scoreSeller(this.toSellerFacts(rows[0]));
  }

  /** Boutiques in order, for a "top shops" surface. */
  async topSellers(limit: number) {
    const rows = await this.prisma.user.findMany({
      where: { role: UserRole.SELLER, disabledAt: null },
      orderBy: { sellerRankScore: 'desc' },
      take: limit,
      select: {
        id: true,
        name: true,
        username: true,
        imageUrl: true,
        sellerRankScore: true,
        sellerRankScoredAt: true,
        sellerRankBreakdown: true,
      },
    });

    return rows.map((row) => ({
      id: row.id,
      name: row.name,
      username: row.username,
      image_url: row.imageUrl,
      score: row.sellerRankScore,
      // Said rather than implied: a position computed last night is not live.
      scored_at: row.sellerRankScoredAt?.toISOString() ?? null,
      breakdown: row.sellerRankBreakdown,
    }));
  }

  // ── Fact gathering ───────────────────────────────────────────────────────

  private async listingFacts(
    limit: number,
    productId?: string,
  ): Promise<ListingRow[]> {
    return this.prisma.$queryRawUnsafe<ListingRow[]>(
      `
      SELECT p.id,
             p.views_count::int      AS views,
             p.orders_count::int     AS orders,
             p.favorites_count::int  AS favourites,
             p.reviews_count::int    AS reviews,
             p.rating::float8        AS rating,
             coalesce(o.live_offers, 0)::int AS live_offers,
             coalesce(o.stock, 0)::int       AS stock,
             greatest(0, extract(day FROM (now() - p.created_at)))::int AS age_days,
             s.days_since_last_order,
             coalesce(s.recent_orders, 0)::int AS recent_orders,
             coalesce(r.refunds, 0)::int AS refunds
      FROM products p
      LEFT JOIN LATERAL (
        SELECT count(*) FILTER (
                 WHERE so.status = $1::"OfferStatus" AND so.is_active AND so.stock > 0
               ) AS live_offers,
               coalesce(sum(so.stock) FILTER (
                 WHERE so.status = $1::"OfferStatus" AND so.is_active
               ), 0) AS stock
        FROM seller_offers so WHERE so.product_id = p.id
      ) o ON true
      LEFT JOIN LATERAL (
        SELECT extract(day FROM (now() - max(ord.created_at)))::int AS days_since_last_order,
               count(*) FILTER (
                 WHERE ord.created_at >= now() - interval '30 days'
               ) AS recent_orders
        FROM order_items oi
        JOIN seller_orders ord ON ord.id = oi.seller_order_id
        WHERE oi.product_id = p.id
          AND ord.status = ANY($2::"SellerOrderStatus"[])
      ) s ON true
      LEFT JOIN LATERAL (
        SELECT count(*) AS refunds
        FROM order_items oi2
        JOIN return_requests rr ON rr.seller_order_id = oi2.seller_order_id
        WHERE oi2.product_id = p.id AND rr.status = $3::"ReturnStatus"
      ) r ON true
      WHERE p.status = $4::"ProductStatus"
        AND ($5::uuid IS NULL OR p.id = $5::uuid)
      ORDER BY p.rank_scored_at ASC NULLS FIRST
      LIMIT $6
      `,
      OfferStatus.ACTIVE,
      [
        SellerOrderStatus.DELIVERED,
        SellerOrderStatus.EXCHANGED,
        SellerOrderStatus.IN_TRANSIT,
        SellerOrderStatus.HANDED_TO_COURIER,
      ],
      ReturnStatus.REFUNDED,
      ProductStatus.ACTIVE,
      productId ?? null,
      limit,
    );
  }

  private toListingFacts(row: ListingRow): ListingFacts {
    return {
      views: row.views,
      orders: row.orders,
      favourites: row.favourites,
      reviews: row.reviews,
      rating: row.rating,
      liveOffers: row.live_offers,
      stock: row.stock,
      ageDays: row.age_days,
      daysSinceLastOrder: row.days_since_last_order,
      refunds: row.refunds,
    };
  }

  private async sellerFacts(
    limit: number,
    sellerId?: string,
  ): Promise<SellerRow[]> {
    const since = new Date(Date.now() - SELLER_WINDOW_DAYS * dayMs);

    return this.prisma.$queryRawUnsafe<SellerRow[]>(
      `
      SELECT u.id,
             coalesce(t.delivered, 0)::int  AS delivered,
             coalesce(t.cancelled, 0)::int  AS cancelled,
             coalesce(t.refunded, 0)::int   AS refunded,
             coalesce(v.rating, 0)::float8  AS rating,
             coalesce(v.reviews, 0)::int    AS reviews,
             coalesce(l.live_listings, 0)::int AS live_listings,
             NULL::float8                   AS response_hours,
             t.days_since_last_sale
      FROM users u
      LEFT JOIN LATERAL (
        SELECT count(*) FILTER (WHERE so.status = ANY($2::"SellerOrderStatus"[])) AS delivered,
               count(*) FILTER (WHERE so.status = $3::"SellerOrderStatus")        AS cancelled,
               count(*) FILTER (
                 WHERE EXISTS (
                   SELECT 1 FROM return_requests rr
                   WHERE rr.seller_order_id = so.id AND rr.status = $4::"ReturnStatus"
                 )
               ) AS refunded,
               extract(day FROM (now() - max(so.created_at)))::int AS days_since_last_sale
        FROM seller_orders so
        WHERE so.seller_id = u.id AND so.created_at >= ${utcCast('$5')}
      ) t ON true
      LEFT JOIN LATERAL (
        SELECT avg(sr.rating)::float8 AS rating, count(*)::int AS reviews
        FROM seller_reviews sr WHERE sr.seller_id = u.id
      ) v ON true
      LEFT JOIN LATERAL (
        SELECT count(*) AS live_listings
        FROM seller_offers so2
        WHERE so2.seller_id = u.id AND so2.status = $6::"OfferStatus" AND so2.is_active
      ) l ON true
      WHERE u.role = $1::"UserRole"
        AND u.disabled_at IS NULL
        AND ($7::uuid IS NULL OR u.id = $7::uuid)
      ORDER BY u.seller_rank_scored_at ASC NULLS FIRST
      LIMIT $8
      `,
      UserRole.SELLER,
      [SellerOrderStatus.DELIVERED, SellerOrderStatus.EXCHANGED],
      SellerOrderStatus.CANCELLED_BY_SELLER,
      ReturnStatus.REFUNDED,
      utcParam(since),
      OfferStatus.ACTIVE,
      sellerId ?? null,
      limit,
    );
  }

  private toSellerFacts(row: SellerRow): SellerRankFacts {
    return {
      delivered: row.delivered,
      cancelled: row.cancelled,
      refunded: row.refunded,
      rating: row.rating,
      reviews: row.reviews,
      liveListings: row.live_listings,
      // Response time is owned by `SellerHealthService`, which measures it
      // properly from first-reply gaps. Left null here rather than
      // re-implemented badly: two answers to the same question that disagree
      // is worse than one answer and a gap.
      responseHours: row.response_hours,
      daysSinceLastSale: row.days_since_last_sale,
    };
  }
}
