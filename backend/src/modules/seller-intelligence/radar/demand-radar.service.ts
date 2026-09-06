import { Injectable } from '@nestjs/common';
import { OfferStatus, Prisma, UnmetDemandStatus } from '@prisma/client';
import { PrismaService } from '../../../prisma/prisma.service';
import { RADAR_WINDOW_DAYS } from '../intelligence.constants';
import {
  CategoryDemand,
  PriceTrendInput,
  StockWatchInput,
  UnmetTerm,
  opportunities,
  priceTrends,
  risingCategories,
  sellerUnmetDemand,
  stockAlerts,
} from '../kernel/demand-radar';

/**
 * The radar: a read model, not a pipeline.
 *
 * Every number on this screen already existed before this file did.
 * `CategoryDemandDaily` and `ProductDemandDaily` are filled in nightly by the
 * trend engine's collector; `UnmetDemandSignal` is written by its search
 * intelligence. What was missing was not the data — it was that all of it
 * was either platform-wide or admin-only, and a seller had no way to ask
 * "what does this mean for *my* shop".
 *
 * So there is no table here and no collector. This service asks the existing
 * facts a seller's question: it finds her categories, splits each window in
 * half to get a direction, and hands plain numbers to the kernel.
 *
 * ── Why the window is split rather than regressed ────────────────────────
 *
 * Growth here is the recent half against the previous half. The trend engine
 * does something more careful for its own scores — shape, acceleration,
 * confidence — and this deliberately does not repeat it. The radar's job is
 * to point, and a half-over-half comparison is honest, explicable to a seller
 * in one sentence, and cannot drift away from the engine's own numbers
 * because it never pretends to be one.
 */
@Injectable()
export class DemandRadarService {
  constructor(private readonly prisma: PrismaService) {}

  async overview(
    sellerId: string,
    options: { windowDays?: number; now?: Date } = {},
  ) {
    const windowDays = options.windowDays ?? RADAR_WINDOW_DAYS;
    const now = options.now ?? new Date();
    const half = Math.floor(windowDays / 2);
    const since = utcDay(new Date(now.getTime() - windowDays * 86_400_000));
    const midpoint = utcDay(new Date(now.getTime() - half * 86_400_000));

    const herCategories = await this.categoriesOf(sellerId);

    const [categories, unmet, stock, prices] = await Promise.all([
      this.categoryDemand(sellerId, herCategories, since, midpoint),
      this.unmetTerms(),
      this.stockWatch(sellerId, since, midpoint),
      this.priceInputs(sellerId, herCategories, since, midpoint),
    ]);

    const rising = risingCategories(categories);
    const herUnmet = sellerUnmetDemand(unmet, new Set(herCategories));
    const alerts = stockAlerts(stock);

    return {
      windowDays,
      asOf: utcDay(now),
      // The one ordered list the screen leads with.
      opportunities: opportunities({ rising, unmet: herUnmet, stock: alerts }),
      rising,
      unmet: herUnmet,
      stockAlerts: alerts,
      priceTrends: priceTrends(prices),
      categoryCount: herCategories.length,
    };
  }

  /** The categories she actually has live offers in. */
  private async categoriesOf(sellerId: string): Promise<string[]> {
    const rows = await this.prisma.product.findMany({
      where: { offers: { some: { sellerId, status: OfferStatus.ACTIVE } } },
      select: { categoryId: true },
      distinct: ['categoryId'],
    });
    return rows.map((r) => r.categoryId);
  }

  /**
   * Demand per category, split into the two halves of the window.
   *
   * Her own categories plus their siblings: a rising category she is *not* in
   * is the most valuable thing the radar can tell her, but only if it is
   * adjacent enough to be a real option. Siblings under the same parent is
   * the honest definition of adjacent that the catalogue already carries.
   */
  private async categoryDemand(
    sellerId: string,
    herCategories: readonly string[],
    since: Date,
    midpoint: Date,
  ): Promise<CategoryDemand[]> {
    if (!herCategories.length) return [];

    const parents = await this.prisma.category.findMany({
      where: { id: { in: [...herCategories] } },
      select: { parentId: true },
    });
    const parentIds = parents
      .map((p) => p.parentId)
      .filter((id): id is string => !!id);

    const scope = await this.prisma.category.findMany({
      where: {
        OR: [
          { id: { in: [...herCategories] } },
          ...(parentIds.length ? [{ parentId: { in: parentIds } }] : []),
        ],
      },
      select: { id: true, nameAr: true, nameEn: true },
    });
    if (!scope.length) return [];

    const ids = scope.map((c) => c.id);

    const [hers, scores] = await Promise.all([
      // Her footprint, so the kernel can tell a category she is in from one
      // she is not.
      this.prisma.sellerDemandDaily.groupBy({
        by: ['categoryId'],
        where: { sellerId, categoryId: { in: ids }, day: { gte: since } },
        _sum: { units: true },
      }),
      // The most recent capture per category. Ordered by the day it was
      // captured, which is the column the table is actually keyed on.
      this.prisma.categoryTrendScore.findMany({
        where: { categoryId: { in: ids } },
        orderBy: { capturedOn: 'desc' },
        select: { categoryId: true, score: true },
      }),
    ]);

    // The halves, in one grouped query each rather than per category.
    const [recentRows, previousRows] = await Promise.all([
      this.prisma.categoryDemandDaily.groupBy({
        by: ['categoryId'],
        where: { categoryId: { in: ids }, day: { gte: midpoint } },
        _sum: { views: true },
      }),
      this.prisma.categoryDemandDaily.groupBy({
        by: ['categoryId'],
        where: {
          categoryId: { in: ids },
          day: { gte: since, lt: midpoint },
        },
        _sum: { views: true },
      }),
    ]);

    const recent = new Map(
      recentRows.map((r) => [r.categoryId, r._sum.views ?? 0]),
    );
    const previous = new Map(
      previousRows.map((r) => [r.categoryId, r._sum.views ?? 0]),
    );
    const units = new Map(hers.map((r) => [r.categoryId, r._sum.units ?? 0]));
    const score = new Map(scores.map((r) => [r.categoryId, r.score]));
    const listed = new Set(herCategories);

    return scope.map((category) => ({
      categoryId: category.id,
      name: category.nameAr || category.nameEn,
      recent: recent.get(category.id) ?? 0,
      previous: previous.get(category.id) ?? 0,
      trendScore: score.get(category.id) ?? null,
      sellerListings: listed.has(category.id) ? 1 : 0,
      sellerUnits: units.get(category.id) ?? 0,
    }));
  }

  /**
   * The searches that came back empty.
   *
   * Read straight from `UnmetDemandSignal`, which the trend engine's search
   * intelligence already maintains — this is the read that was previously
   * only reachable from the admin console. Resolved and dismissed terms are
   * excluded: somebody has already dealt with those.
   */
  private async unmetTerms(): Promise<UnmetTerm[]> {
    const rows = await this.prisma.unmetDemandSignal.findMany({
      where: { status: UnmetDemandStatus.OPEN },
      orderBy: { demandScore: 'desc' },
      take: 40,
    });

    return rows.map((r) => ({
      termKey: r.termKey,
      display: r.display,
      searches: r.searches,
      zeroResults: r.zeroResults,
      missRate: r.missRate,
      growth: r.growth,
      demandScore: r.demandScore,
      suggestedCategoryId: r.suggestedCategoryId,
      suggestionAr: r.suggestionAr,
    }));
  }

  /** Her listings, with stock against the demand still arriving at them. */
  private async stockWatch(
    sellerId: string,
    since: Date,
    midpoint: Date,
  ): Promise<StockWatchInput[]> {
    const offers = await this.prisma.sellerOffer.findMany({
      where: { sellerId, status: OfferStatus.ACTIVE },
      select: {
        productId: true,
        stock: true,
        isActive: true,
        product: { select: { title: true } },
      },
      take: 200,
    });
    if (!offers.length) return [];

    const productIds = offers.map((o) => o.productId);
    const days = Math.max(
      1,
      Math.round((midpoint.getTime() - since.getTime()) / 86_400_000) * 2,
    );

    const [units, recent, previous] = await Promise.all([
      this.prisma.sellerDemandDaily.groupBy({
        by: ['productId'],
        where: { sellerId, productId: { in: productIds }, day: { gte: since } },
        _sum: { units: true },
      }),
      this.prisma.productDemandDaily.groupBy({
        by: ['productId'],
        where: { productId: { in: productIds }, day: { gte: midpoint } },
        _sum: { views: true },
      }),
      this.prisma.productDemandDaily.groupBy({
        by: ['productId'],
        where: {
          productId: { in: productIds },
          day: { gte: since, lt: midpoint },
        },
        _sum: { views: true },
      }),
    ]);

    const sold = new Map(units.map((r) => [r.productId, r._sum.units ?? 0]));
    const recentViews = new Map(
      recent.map((r) => [r.productId, r._sum.views ?? 0]),
    );
    const previousViews = new Map(
      previous.map((r) => [r.productId, r._sum.views ?? 0]),
    );

    return offers.map((offer) => ({
      productId: offer.productId,
      title: offer.product.title,
      stockUnits: offer.stock,
      dailyUnits: (sold.get(offer.productId) ?? 0) / days,
      recentViews: recentViews.get(offer.productId) ?? 0,
      previousViews: previousViews.get(offer.productId) ?? 0,
      inStock: offer.isActive && offer.stock > 0,
    }));
  }

  /**
   * Where prices are moving in her categories, and where she sits.
   *
   * Medians of the live minimum price per product, halved the same way
   * everything else here is. `minPriceSyp` is already normalised to SYP by
   * the catalogue, so a category carrying dollar-priced offers compares
   * without a rate lookup per row.
   */
  private async priceInputs(
    sellerId: string,
    herCategories: readonly string[],
    since: Date,
    midpoint: Date,
  ): Promise<PriceTrendInput[]> {
    if (!herCategories.length) return [];

    const rows = await this.prisma.$queryRaw<
      Array<{
        category_id: string;
        name: string;
        recent_median: number | null;
        previous_median: number | null;
        seller_median: number | null;
      }>
    >`
      SELECT
        c.id AS category_id,
        coalesce(nullif(c.name_ar, ''), c.name_en) AS name,
        percentile_cont(0.5) WITHIN GROUP (ORDER BY d.min_price_syp)
          FILTER (WHERE d.day >= ${midpoint} AND d.min_price_syp IS NOT NULL)
          AS recent_median,
        percentile_cont(0.5) WITHIN GROUP (ORDER BY d.min_price_syp)
          FILTER (WHERE d.day < ${midpoint} AND d.min_price_syp IS NOT NULL)
          AS previous_median,
        percentile_cont(0.5) WITHIN GROUP (ORDER BY s.price_syp)
          FILTER (WHERE s.price_syp IS NOT NULL)
          AS seller_median
      FROM categories c
      JOIN product_demand_daily d
        ON d.category_id = c.id AND d.day >= ${since}
      LEFT JOIN seller_demand_daily s
        ON s.product_id = d.product_id
       AND s.day = d.day
       AND s.seller_id = ${sellerId}::uuid
      WHERE c.id IN (${Prisma.join([...herCategories].map((id) => Prisma.sql`${id}::uuid`))})
      GROUP BY c.id, c.name_ar, c.name_en
    `;

    return rows.map((r) => ({
      categoryId: r.category_id,
      name: r.name,
      recentMedian: r.recent_median === null ? null : Number(r.recent_median),
      previousMedian:
        r.previous_median === null ? null : Number(r.previous_median),
      sellerMedian: r.seller_median === null ? null : Number(r.seller_median),
    }));
  }
}

function utcDay(date: Date): Date {
  return new Date(
    Date.UTC(date.getUTCFullYear(), date.getUTCMonth(), date.getUTCDate()),
  );
}
