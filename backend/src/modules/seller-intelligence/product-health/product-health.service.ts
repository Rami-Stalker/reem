import { Injectable, Logger, NotFoundException } from '@nestjs/common';
import { OfferStatus, Prisma, ProductStatus } from '@prisma/client';
import { PrismaService } from '../../../prisma/prisma.service';
import { PRODUCT_WINDOW_DAYS } from '../intelligence.constants';
import {
  PeerCohort,
  ProductAdvice,
  ProductFacts,
  ProductHealthResult,
  adviseProduct,
  scoreProductHealth,
} from '../kernel/product-health';

/**
 * Measuring a listing.
 *
 * Two sources, joined: the product row itself — which says how well the
 * listing is *built* — and `ProductDemandDaily`, which the trend engine
 * already fills in every night and says how the listing is *doing*. Nothing
 * here recomputes demand; it reads the same table the seller's trend screen
 * reads, so the two cannot disagree.
 *
 * ── The cohort ───────────────────────────────────────────────────────────
 *
 * Half the axes only mean something against the category's other listings, so
 * this service also builds a `PeerCohort` — medians over the live products in
 * the same category over the same window. Medians, in SQL, over the same
 * table: the comparison a seller is shown has to be the same arithmetic that
 * produced her own number, or the two are not comparable.
 *
 * The cohort deliberately includes her own listings. Excluding them would
 * make a seller who dominates a small category look like she is failing
 * against a market that is mostly her.
 */
@Injectable()
export class ProductHealthService {
  private readonly logger = new Logger(ProductHealthService.name);

  constructor(private readonly prisma: PrismaService) {}

  /**
   * One listing, scored and advised.
   *
   * Computed live rather than read from the snapshot, so a seller who has
   * just uploaded three photographs sees the effect immediately. That
   * responsiveness is most of what makes the advice feel worth following.
   */
  async detail(
    sellerId: string,
    productId: string,
    options: { windowDays?: number; now?: Date } = {},
  ): Promise<{
    product: { id: string; title: string; imageUrl: string | null };
    result: ProductHealthResult;
    advice: ProductAdvice[];
    facts: ProductFacts;
  }> {
    const windowDays = options.windowDays ?? PRODUCT_WINDOW_DAYS;
    const now = options.now ?? new Date();

    const product = await this.prisma.product.findFirst({
      // Scoped to her own offers: a seller may only inspect a listing she
      // actually sells, even though the catalogue entry is shared.
      where: { id: productId, offers: { some: { sellerId } } },
      include: {
        media: { orderBy: { sortOrder: 'asc' } },
        offers: { where: { sellerId } },
      },
    });
    if (!product) throw new NotFoundException('Product not found');

    const facts = await this.factsFor(sellerId, product, windowDays, now);
    const cohort = await this.cohortFor(product.categoryId, windowDays, now);
    const result = scoreProductHealth(facts, cohort);

    return {
      product: {
        id: product.id,
        title: product.title,
        imageUrl: product.media[0]?.url ?? null,
      },
      result,
      advice: adviseProduct(facts, result),
      facts,
    };
  }

  /**
   * Every listing she sells, scored, worst first.
   *
   * Worst first because this is a work queue, not a leaderboard. A seller
   * opening this screen wants the shortest path to more sales, and that is
   * always the listing with the most recoverable points.
   */
  async list(
    sellerId: string,
    options: { windowDays?: number; now?: Date; limit?: number } = {},
  ) {
    const windowDays = options.windowDays ?? PRODUCT_WINDOW_DAYS;
    const now = options.now ?? new Date();

    const products = await this.prisma.product.findMany({
      where: {
        offers: { some: { sellerId, status: OfferStatus.ACTIVE } },
        status: ProductStatus.ACTIVE,
      },
      include: {
        media: { orderBy: { sortOrder: 'asc' } },
        offers: { where: { sellerId } },
      },
      take: options.limit ?? 100,
    });

    // One cohort per category rather than one per product: a seller with
    // forty dresses would otherwise run the same median forty times.
    const cohorts = new Map<string, PeerCohort | null>();
    const rows = [];

    for (const product of products) {
      if (!cohorts.has(product.categoryId)) {
        cohorts.set(
          product.categoryId,
          await this.cohortFor(product.categoryId, windowDays, now),
        );
      }
      const facts = await this.factsFor(sellerId, product, windowDays, now);
      const result = scoreProductHealth(
        facts,
        cohorts.get(product.categoryId) ?? null,
      );
      const advice = adviseProduct(facts, result);

      rows.push({
        productId: product.id,
        title: product.title,
        imageUrl: product.media[0]?.url ?? null,
        score: result.score,
        confidence: result.confidence,
        axes: result.axes,
        peers: result.peers,
        topAdvice: advice[0] ?? null,
        adviceCount: advice.length,
        views: facts.views,
        orders: facts.orders,
        inStock: facts.inStock,
      });
    }

    return {
      windowDays,
      rows: rows.sort((a, b) => a.score - b.score),
      averageScore: rows.length
        ? round(rows.reduce((t, r) => t + r.score, 0) / rows.length)
        : null,
    };
  }

  // ── Facts ──────────────────────────────────────────────────────────────

  private async factsFor(
    sellerId: string,
    product: Prisma.ProductGetPayload<{
      include: { media: true; offers: true };
    }>,
    windowDays: number,
    now: Date,
  ): Promise<ProductFacts> {
    const since = utcDay(new Date(now.getTime() - windowDays * 86_400_000));

    // Attention comes from the shared product-level table — impressions and
    // searches are facts about the catalogue entry, not about one seller's
    // offer on it. Outcomes come from her own row, so two sellers on the same
    // product each see their own orders.
    const [demand, mine] = await Promise.all([
      this.prisma.productDemandDaily.aggregate({
        where: { productId: product.id, day: { gte: since } },
        _sum: {
          impressions: true,
          views: true,
          searchHits: true,
          searchClicks: true,
          cartAdds: true,
          favorites: true,
        },
      }),
      this.prisma.sellerDemandDaily.aggregate({
        where: { sellerId, productId: product.id, day: { gte: since } },
        _sum: { orders: true, units: true },
      }),
    ]);

    const offer = product.offers[0] ?? null;
    const attributes = (product.attributes ?? {}) as Record<string, unknown>;

    return {
      productId: product.id,
      title: product.title,
      description: product.description,
      imageCount: product.media.length,
      imagesWithBlurHash: product.media.filter((m) => m.blurHash).length,
      attributeCount: Object.entries(attributes).filter(
        ([, v]) => v !== null && v !== undefined && v !== '',
      ).length,
      hasBrand: !!product.brandId,
      hasGtin: !!product.gtin,

      impressions: demand._sum.impressions ?? 0,
      views: demand._sum.views ?? 0,
      searchHits: demand._sum.searchHits ?? 0,
      searchClicks: demand._sum.searchClicks ?? 0,
      cartAdds: demand._sum.cartAdds ?? 0,
      favorites: demand._sum.favorites ?? 0,
      orders: mine._sum.orders ?? 0,
      units: mine._sum.units ?? 0,

      priceSyp: offer?.priceSyp ? Number(offer.priceSyp) : null,
      inStock: !!offer && offer.status === OfferStatus.ACTIVE && offer.stock > 0,
      stockUnits: offer?.stock ?? 0,

      reviewCount: product.reviewsCount,
      averageRating: product.rating > 0 ? product.rating : null,
    };
  }

  /**
   * The category's medians, over the same window.
   *
   * One query. `percentile_cont` needs the distribution, and the alternative
   * — fetching every listing in the category into Node — is the query that
   * works on a seed and dies on a real catalogue.
   */
  private async cohortFor(
    categoryId: string,
    windowDays: number,
    now: Date,
  ): Promise<PeerCohort | null> {
    const since = utcDay(new Date(now.getTime() - windowDays * 86_400_000));

    const rows = await this.prisma.$queryRaw<
      Array<{
        size: bigint;
        median_conversion: number | null;
        median_views: number | null;
        median_attributes: number | null;
        median_price: number | null;
        median_images: number | null;
      }>
    >`
      WITH per_product AS (
        SELECT
          p.id,
          coalesce(sum(d.views), 0) AS views,
          coalesce(sum(d.orders), 0) AS orders,
          p.min_price_syp AS price,
          (SELECT count(*) FROM product_media m WHERE m.product_id = p.id) AS images,
          coalesce(
            (SELECT count(*) FROM jsonb_each(p.attributes)
             WHERE p.attributes IS NOT NULL),
            0
          ) AS attributes
        FROM products p
        LEFT JOIN product_demand_daily d
          ON d.product_id = p.id AND d.day >= ${since}
        WHERE p.category_id = ${categoryId}::uuid
          AND p.status = 'ACTIVE'
        GROUP BY p.id, p.min_price_syp, p.attributes
      )
      SELECT
        count(*) AS size,
        percentile_cont(0.5) WITHIN GROUP (
          ORDER BY CASE WHEN views > 0 THEN orders::float / views ELSE 0 END
        ) AS median_conversion,
        percentile_cont(0.5) WITHIN GROUP (ORDER BY views) AS median_views,
        percentile_cont(0.5) WITHIN GROUP (ORDER BY attributes) AS median_attributes,
        percentile_cont(0.5) WITHIN GROUP (ORDER BY price) AS median_price,
        percentile_cont(0.5) WITHIN GROUP (ORDER BY images) AS median_images
      FROM per_product
    `;

    const row = rows[0];
    if (!row || Number(row.size) === 0) return null;

    return {
      size: Number(row.size),
      medianConversion: Number(row.median_conversion ?? 0),
      medianViews: Number(row.median_views ?? 0),
      medianAttributes: Number(row.median_attributes ?? 0),
      medianPriceSyp:
        row.median_price === null ? null : Number(row.median_price),
      medianImages: Number(row.median_images ?? 0),
    };
  }

  // ── Persistence ────────────────────────────────────────────────────────

  /**
   * Write today's row for every listing she sells.
   *
   * The snapshot is what makes "this advice worked" provable later, and it is
   * also what `SellerHealthService` averages into her quality dimension — so
   * this must run before the seller sweep, which is why the scheduler orders
   * them.
   */
  async snapshotSeller(
    sellerId: string,
    options: { now?: Date } = {},
  ): Promise<number> {
    const now = options.now ?? new Date();
    const day = utcDay(now);
    const { rows } = await this.list(sellerId, { now });

    for (const row of rows) {
      const data = {
        score: row.score,
        components: row.axes as unknown as Prisma.InputJsonValue,
        confidence: row.confidence,
        advice: (row.topAdvice
          ? [row.topAdvice]
          : []) as unknown as Prisma.InputJsonValue,
        peers: (row.peers ?? undefined) as unknown as Prisma.InputJsonValue,
        computedAt: now,
      };

      await this.prisma.productHealthSnapshot.upsert({
        where: {
          sellerId_productId_day: { sellerId, productId: row.productId, day },
        },
        create: { sellerId, productId: row.productId, day, ...data },
        update: data,
      });
    }

    return rows.length;
  }
}

function round(n: number): number {
  return Math.round(n * 100) / 100;
}

function utcDay(date: Date): Date {
  return new Date(
    Date.UTC(date.getUTCFullYear(), date.getUTCMonth(), date.getUTCDate()),
  );
}
