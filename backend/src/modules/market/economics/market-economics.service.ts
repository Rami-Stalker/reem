import { Injectable, Logger } from '@nestjs/common';
import {
  GraphEdge,
  GraphNode,
  MarketFinding,
  MarketSubject,
  OfferStatus,
  Prisma,
  ProductStatus,
} from '@prisma/client';
import { PrismaService } from '../../../prisma/prisma.service';
import { detectSlots } from '../../ai-stylist/understanding/stylist-lexicon';
import {
  MarketFacts,
  MarketNorms,
  MarketReading,
  readMarket,
} from '../kernel/economics';

/** How far back a market reading looks. Two halves, so direction is derivable. */
export const MARKET_WINDOW_DAYS = 28;

/**
 * How much of a category has to read as one slot before the category *is* that
 * slot. Below this the shelf is mixed, and a mixed shelf answers no specific
 * need.
 */
const CATEGORY_SLOT_MAJORITY = 0.6;

/**
 * Measuring the market.
 *
 * The seam between facts that already exist and the economics kernel. It reads
 * `ProductDemandDaily` and `CategoryDemandDaily` for demand, the live
 * catalogue for supply, and `CommerceEdge` for the one signal neither of those
 * carries — how many women have an *open need* the subject would answer.
 *
 * ── Why the norms are computed, not configured ───────────────────────────
 *
 * `MarketNorms` decides what "a lot of views" means. Hard-coding it would make
 * every reading wrong the moment the platform grew: a category with 200 views
 * is remarkable today and unremarkable at ten times the traffic. So the norms
 * are the platform's own medians, recomputed on every sweep, and a market
 * reading is always relative to the market it is part of.
 */
@Injectable()
export class MarketEconomicsService {
  private readonly logger = new Logger(MarketEconomicsService.name);

  constructor(private readonly prisma: PrismaService) {}

  /**
   * Read every category and every live product.
   *
   * Categories first: a product's price index is measured against its
   * category's median, so the category has to be known before the products
   * inside it can be placed.
   */
  async sweep(options: { now?: Date } = {}): Promise<{
    categories: number;
    products: number;
    findings: number;
  }> {
    const now = options.now ?? new Date();
    const norms = await this.norms(now);

    const categories = await this.sweepCategories(norms, now);
    const products = await this.sweepProducts(norms, now, categories.medians);

    this.logger.log(
      `Market signals: ${categories.count} categories, ${products.count} products, ` +
        `${categories.findings + products.findings} findings`,
    );

    return {
      categories: categories.count,
      products: products.count,
      findings: categories.findings + products.findings,
    };
  }

  /**
   * What "a lot" means on this platform today.
   *
   * Medians rather than means throughout: one category carrying a third of the
   * traffic would drag a mean somewhere that made every other reading look
   * dead.
   */
  async norms(now = new Date()): Promise<MarketNorms> {
    const since = utcDay(
      new Date(now.getTime() - MARKET_WINDOW_DAYS * 86_400_000),
    );

    const rows = await this.prisma.$queryRaw<
      Array<{
        half_views: number | null;
        half_products: number | null;
        half_sellers: number | null;
        median_conversion: number | null;
      }>
    >`
      WITH per_category AS (
        SELECT c.id,
               coalesce(sum(d.views), 0)  AS views,
               coalesce(sum(d.orders), 0) AS orders,
               (SELECT count(*) FROM products p
                 WHERE p.category_id = c.id AND p.status = 'ACTIVE') AS products,
               (SELECT count(DISTINCT o.seller_id)
                  FROM seller_offers o
                  JOIN products p2 ON p2.id = o.product_id
                 WHERE p2.category_id = c.id AND o.status = 'ACTIVE') AS sellers
        FROM categories c
        LEFT JOIN category_demand_daily d
          ON d.category_id = c.id AND d.day >= ${since}
        GROUP BY c.id
      )
      SELECT
        percentile_cont(0.5) WITHIN GROUP (ORDER BY views)    AS half_views,
        percentile_cont(0.5) WITHIN GROUP (ORDER BY products) AS half_products,
        percentile_cont(0.5) WITHIN GROUP (ORDER BY sellers)  AS half_sellers,
        percentile_cont(0.5) WITHIN GROUP (
          ORDER BY CASE WHEN views > 0 THEN orders::float / views ELSE 0 END
        ) AS median_conversion
      FROM per_category
      WHERE products > 0
    `;

    const row = rows[0];
    // Floors, so an empty or brand-new platform does not divide by nothing and
    // declare every aisle a supply gap.
    return {
      halfViews: Math.max(20, Number(row?.half_views ?? 0)),
      halfProducts: Math.max(3, Number(row?.half_products ?? 0)),
      halfSellers: Math.max(2, Number(row?.half_sellers ?? 0)),
      medianConversion: Math.max(0.005, Number(row?.median_conversion ?? 0)),
    };
  }

  // ── Categories ─────────────────────────────────────────────────────────

  private async sweepCategories(
    norms: MarketNorms,
    now: Date,
  ): Promise<{ count: number; findings: number; medians: Map<string, number> }> {
    const since = utcDay(new Date(now.getTime() - MARKET_WINDOW_DAYS * 86_400_000));
    const midpoint = utcDay(
      new Date(now.getTime() - (MARKET_WINDOW_DAYS / 2) * 86_400_000),
    );

    const rows = await this.prisma.$queryRaw<
      Array<{
        category_id: string;
        views: number;
        searches: number;
        cart_adds: number;
        favourites: number;
        orders: number;
        units: number;
        recent_views: number;
        previous_views: number;
        live_products: number;
        live_offers: number;
        stock_units: number;
        sellers: number;
        median_price: number | null;
      }>
    >`
      SELECT
        c.id::text AS category_id,
        coalesce(sum(d.views), 0)::int      AS views,
        coalesce(sum(d.search_hits), 0)::int AS searches,
        coalesce(sum(d.cart_adds), 0)::int  AS cart_adds,
        coalesce(sum(d.favorites), 0)::int  AS favourites,
        coalesce(sum(d.orders), 0)::int     AS orders,
        coalesce(sum(d.units), 0)::int      AS units,
        coalesce(sum(d.views) FILTER (WHERE d.day >= ${midpoint}), 0)::int AS recent_views,
        coalesce(sum(d.views) FILTER (WHERE d.day <  ${midpoint}), 0)::int AS previous_views,
        (SELECT count(*) FROM products p
          WHERE p.category_id = c.id AND p.status = 'ACTIVE')::int AS live_products,
        (SELECT count(*) FROM seller_offers o
           JOIN products p2 ON p2.id = o.product_id
          WHERE p2.category_id = c.id AND o.status = 'ACTIVE')::int AS live_offers,
        (SELECT coalesce(sum(o.stock), 0) FROM seller_offers o
           JOIN products p3 ON p3.id = o.product_id
          WHERE p3.category_id = c.id AND o.status = 'ACTIVE')::int AS stock_units,
        (SELECT count(DISTINCT o.seller_id) FROM seller_offers o
           JOIN products p4 ON p4.id = o.product_id
          WHERE p4.category_id = c.id AND o.status = 'ACTIVE')::int AS sellers,
        (SELECT percentile_cont(0.5) WITHIN GROUP (ORDER BY p5.min_price_syp)
           FROM products p5
          WHERE p5.category_id = c.id AND p5.status = 'ACTIVE'
            AND p5.min_price_syp IS NOT NULL) AS median_price
      FROM categories c
      LEFT JOIN category_demand_daily d
        ON d.category_id = c.id AND d.day >= ${since}
      GROUP BY c.id
      HAVING (SELECT count(*) FROM products p6
               WHERE p6.category_id = c.id AND p6.status = 'ACTIVE') > 0
    `;

    // Open needs per category, from the graph. `NEEDS` edges name a slot, and
    // a slot is not a category — so this counts the shoppers whose open needs
    // point at products in the category, which is the closest honest join.
    const needs = await this.needsByCategory();

    // The platform's own median price, so a category's price index means
    // "dearer than Reem" rather than "dearer than itself".
    const prices = rows
      .map((r) => (r.median_price === null ? null : Number(r.median_price)))
      .filter((p): p is number => p !== null)
      .sort((a, b) => a - b);
    const platformMedian = prices.length
      ? prices[Math.floor(prices.length / 2)]
      : null;

    const medians = new Map<string, number>();
    const day = utcDay(now);
    let findings = 0;

    for (const row of rows) {
      if (row.median_price !== null) {
        medians.set(row.category_id, Number(row.median_price));
      }

      const facts: MarketFacts = {
        views: row.views,
        searches: row.searches,
        cartAdds: row.cart_adds,
        favourites: row.favourites,
        orders: row.orders,
        units: row.units,
        recentViews: row.recent_views,
        previousViews: row.previous_views,
        liveProducts: row.live_products,
        liveOffers: row.live_offers,
        stockUnits: row.stock_units,
        sellers: row.sellers,
        openNeeds: needs.get(row.category_id) ?? 0,
        medianPriceSyp:
          row.median_price === null ? null : Number(row.median_price),
        parentMedianPriceSyp: platformMedian,
      };

      const reading = readMarket(facts, norms);
      findings += reading.findings.length;
      await this.persist(MarketSubject.CATEGORY, row.category_id, day, reading, now);
    }

    return { count: rows.length, findings, medians };
  }

  // ── Products ───────────────────────────────────────────────────────────

  private async sweepProducts(
    norms: MarketNorms,
    now: Date,
    categoryMedians: Map<string, number>,
  ): Promise<{ count: number; findings: number }> {
    const since = utcDay(new Date(now.getTime() - MARKET_WINDOW_DAYS * 86_400_000));
    const midpoint = utcDay(
      new Date(now.getTime() - (MARKET_WINDOW_DAYS / 2) * 86_400_000),
    );

    const rows = await this.prisma.$queryRaw<
      Array<{
        product_id: string;
        category_id: string;
        views: number;
        searches: number;
        cart_adds: number;
        favourites: number;
        orders: number;
        units: number;
        recent_views: number;
        previous_views: number;
        live_offers: number;
        stock_units: number;
        sellers: number;
        price: number | null;
      }>
    >`
      SELECT
        p.id::text          AS product_id,
        p.category_id::text AS category_id,
        coalesce(sum(d.views), 0)::int       AS views,
        coalesce(sum(d.search_hits), 0)::int AS searches,
        coalesce(sum(d.cart_adds), 0)::int   AS cart_adds,
        coalesce(sum(d.favorites), 0)::int   AS favourites,
        coalesce(sum(d.orders), 0)::int      AS orders,
        coalesce(sum(d.units), 0)::int       AS units,
        coalesce(sum(d.views) FILTER (WHERE d.day >= ${midpoint}), 0)::int AS recent_views,
        coalesce(sum(d.views) FILTER (WHERE d.day <  ${midpoint}), 0)::int AS previous_views,
        (SELECT count(*) FROM seller_offers o
          WHERE o.product_id = p.id AND o.status = 'ACTIVE')::int AS live_offers,
        (SELECT coalesce(sum(o.stock), 0) FROM seller_offers o
          WHERE o.product_id = p.id AND o.status = 'ACTIVE')::int AS stock_units,
        (SELECT count(DISTINCT o.seller_id) FROM seller_offers o
          WHERE o.product_id = p.id AND o.status = 'ACTIVE')::int AS sellers,
        p.min_price_syp AS price
      FROM products p
      LEFT JOIN product_demand_daily d
        ON d.product_id = p.id AND d.day >= ${since}
      WHERE p.status = 'ACTIVE'
        AND EXISTS (SELECT 1 FROM seller_offers o2
                     WHERE o2.product_id = p.id AND o2.status = 'ACTIVE')
      GROUP BY p.id, p.category_id, p.min_price_syp
    `;

    const needs = await this.needsByProduct(rows.map((r) => r.product_id));
    const day = utcDay(now);
    let findings = 0;

    for (const row of rows) {
      const facts: MarketFacts = {
        views: row.views,
        searches: row.searches,
        cartAdds: row.cart_adds,
        favourites: row.favourites,
        orders: row.orders,
        units: row.units,
        recentViews: row.recent_views,
        previousViews: row.previous_views,
        // A product is its own supply: one listing, however many offers.
        liveProducts: row.live_offers > 0 ? 1 : 0,
        liveOffers: row.live_offers,
        stockUnits: row.stock_units,
        sellers: row.sellers,
        openNeeds: needs.get(row.product_id) ?? 0,
        medianPriceSyp: row.price === null ? null : Number(row.price),
        parentMedianPriceSyp: categoryMedians.get(row.category_id) ?? null,
      };

      // A single product's supply scale is not the category's — one listing is
      // the whole of it — so the norm is overridden here rather than shared.
      const reading = readMarket(facts, { ...norms, halfProducts: 1 });
      findings += reading.findings.length;
      await this.persist(MarketSubject.PRODUCT, row.product_id, day, reading, now);
    }

    return { count: rows.length, findings };
  }

  // ── Open needs, from the commerce graph ────────────────────────────────

  /**
   * How many shoppers have an unmet need a category could answer.
   *
   * `NEEDS` edges name an `OutfitSlot`; a category is a shelf. Bridging the two
   * is the whole difficulty, and the first attempt did it in SQL by matching
   * the slot's enum name against the product title — which on real data
   * returned zero for every category on the platform, because no Arabic
   * listing contains the word `DRESS`. The number was not wrong, it was
   * absent, and it was quietly absent, which is worse.
   *
   * So the bridge is built where the vocabulary actually lives: each category
   * is given the slot most of its live products read as, using the same
   * `detectSlots` the stylist and the closet use. A category is then credited
   * with the shoppers whose open need names that slot. Imperfect — a category
   * mixing dresses and abayas gets one label — and honest about it, which is
   * why the modal slot has to be a real majority before it counts.
   */
  private async needsByCategory(): Promise<Map<string, number>> {
    const [slotsByCategory, shoppersBySlot] = await Promise.all([
      this.categorySlots(),
      this.needsBySlot(),
    ]);

    const out = new Map<string, number>();
    for (const [categoryId, slot] of slotsByCategory) {
      const shoppers = shoppersBySlot.get(slot);
      if (shoppers) out.set(categoryId, shoppers);
    }
    return out;
  }

  /** Shoppers with an open need, by the slot the need names. */
  private async needsBySlot(): Promise<Map<string, number>> {
    const rows = await this.prisma.$queryRaw<
      Array<{ slot: string | null; shoppers: bigint }>
    >`
      SELECT e.evidence->>'slot' AS slot,
             count(DISTINCT e.subject_id)::bigint AS shoppers
      FROM commerce_edges e
      WHERE e.subject_type = 'USER'
        AND e.kind = 'NEEDS'
        AND e.evidence->>'slot' IS NOT NULL
      GROUP BY 1
    `;
    return new Map(
      rows
        .filter((r): r is { slot: string; shoppers: bigint } => r.slot !== null)
        .map((r) => [r.slot, Number(r.shoppers)]),
    );
  }

  /**
   * The slot each category mostly is.
   *
   * A plurality is not enough: a category whose products split evenly between
   * two shapes has no slot, and crediting it with either would put a woman's
   * missing shoes against a shelf of handbags.
   */
  private async categorySlots(): Promise<Map<string, string>> {
    const products = await this.prisma.product.findMany({
      where: { status: ProductStatus.ACTIVE },
      select: { categoryId: true, title: true, description: true },
      take: 5000,
    });

    const tally = new Map<string, Map<string, number>>();
    for (const product of products) {
      const slots = detectSlots(`${product.title} ${product.description}`);
      if (!slots.length) continue;
      const counts = tally.get(product.categoryId) ?? new Map<string, number>();
      // The first detected slot is the strongest reading of the garment.
      counts.set(slots[0], (counts.get(slots[0]) ?? 0) + 1);
      tally.set(product.categoryId, counts);
    }

    const out = new Map<string, string>();
    for (const [categoryId, counts] of tally) {
      const total = [...counts.values()].reduce((t, n) => t + n, 0);
      const [slot, top] = [...counts.entries()].sort((a, b) => b[1] - a[1])[0];
      if (top / total >= CATEGORY_SLOT_MAJORITY) out.set(categoryId, slot);
    }
    return out;
  }

  /** Shoppers who saved or considered a specific product but have not bought it. */
  private async needsByProduct(
    productIds: string[],
  ): Promise<Map<string, number>> {
    if (!productIds.length) return new Map();
    const rows = await this.prisma.commerceEdge.groupBy({
      by: ['objectId'],
      where: {
        subjectType: GraphNode.USER,
        objectType: GraphNode.PRODUCT,
        objectId: { in: productIds },
        kind: { in: [GraphEdge.SAVED, GraphEdge.CONSIDERED] },
      },
      _count: { _all: true },
    });
    return new Map(rows.map((r) => [r.objectId, r._count._all]));
  }

  // ── Persistence ────────────────────────────────────────────────────────

  private async persist(
    subjectType: MarketSubject,
    subjectId: string,
    day: Date,
    reading: MarketReading,
    now: Date,
  ): Promise<void> {
    const data = {
      demandScore: reading.demandScore,
      supplyScore: reading.supplyScore,
      conversionScore: reading.conversionScore,
      competition: reading.competition,
      tension: reading.tension,
      priceIndexBps: reading.priceIndexBps,
      components: reading.components as unknown as Prisma.InputJsonValue,
      findings: reading.findings as unknown as Prisma.InputJsonValue,
      confidence: reading.confidence,
      computedAt: now,
    };

    await this.prisma.marketSignal.upsert({
      where: { subjectType_subjectId_day: { subjectType, subjectId, day } },
      create: { subjectType, subjectId, day, ...data },
      update: data,
    });
  }

  // ── Reading it back ────────────────────────────────────────────────────

  /** The most recent signal for one subject. */
  async signalFor(
    subjectType: MarketSubject,
    subjectId: string,
  ) {
    return this.prisma.marketSignal.findFirst({
      where: { subjectType, subjectId },
      orderBy: { day: 'desc' },
    });
  }

  /**
   * Subjects carrying a given finding, strongest first.
   *
   * The one query every consumer of this layer makes: supply gaps for the
   * admin, rising products for a drop, weak conversion for a seller.
   */
  async withFinding(
    subjectType: MarketSubject,
    finding: MarketFinding,
    limit = 20,
  ) {
    const day = await this.latestDay(subjectType);
    if (!day) return [];

    const rows = await this.prisma.marketSignal.findMany({
      where: { subjectType, day },
      orderBy: { tension: 'desc' },
      take: 400,
    });

    return rows
      .map((row) => {
        const findings = (row.findings ?? []) as Array<{
          code: string;
          strength: number;
          evidence: Record<string, number | null>;
        }>;
        const hit = findings.find((f) => f.code === finding);
        return hit ? { signal: row, finding: hit } : null;
      })
      .filter((x): x is NonNullable<typeof x> => x !== null)
      .sort((a, b) => b.finding.strength - a.finding.strength)
      .slice(0, limit);
  }

  private async latestDay(subjectType: MarketSubject): Promise<Date | null> {
    const row = await this.prisma.marketSignal.findFirst({
      where: { subjectType },
      orderBy: { day: 'desc' },
      select: { day: true },
    });
    return row?.day ?? null;
  }

  /** Live products with the strongest launch potential — what Drops reads. */
  async launchCandidates(limit = 40) {
    const day = await this.latestDay(MarketSubject.PRODUCT);
    if (!day) return [];

    const signals = await this.prisma.marketSignal.findMany({
      where: { subjectType: MarketSubject.PRODUCT, day },
      orderBy: { demandScore: 'desc' },
      take: 300,
    });

    const ids = signals.map((s) => s.subjectId);
    if (!ids.length) return [];

    const products = await this.prisma.product.findMany({
      where: {
        id: { in: ids },
        status: ProductStatus.ACTIVE,
        offers: { some: { status: OfferStatus.ACTIVE } },
      },
      select: {
        id: true,
        title: true,
        createdAt: true,
        categoryId: true,
        offers: {
          where: { status: OfferStatus.ACTIVE },
          select: { sellerId: true, stock: true },
        },
      },
    });

    return products
      .map((product) => {
        const signal = signals.find((s) => s.subjectId === product.id);
        if (!signal) return null;
        return { product, signal };
      })
      .filter((x): x is NonNullable<typeof x> => x !== null)
      .slice(0, limit);
  }
}

function utcDay(date: Date): Date {
  return new Date(
    Date.UTC(date.getUTCFullYear(), date.getUTCMonth(), date.getUTCDate()),
  );
}
