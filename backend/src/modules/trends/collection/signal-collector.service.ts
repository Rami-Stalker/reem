import { Injectable, Logger } from '@nestjs/common';
import {
  AnalyticsEventType,
  Currency,
  Prisma,
  ProductStatus,
  ReviewStatus,
  TrendAttributeDimension,
  TrendRunKind,
} from '@prisma/client';
import { PrismaService } from '../../../prisma/prisma.service';
import {
  CANCELLED_STATUSES,
  Money,
  REVENUE_STATUSES,
} from '../../../common/money';
import { ExchangeRateService } from '../../pricing/exchange-rate.service';
import {
  colourLabel,
  detectColours,
} from '../../ai-stylist/understanding/stylist-lexicon';
import { median } from '../kernel/trend-math';
import { normaliseQuery, priceBandFor, priceBandLabel } from '../kernel/query-normalizer';
import { K_ANONYMITY, PLATFORM_SCOPE, PRICE_BANDS } from '../trend.constants';
import { TrendRunRecorder } from './trend-run.recorder';
import { dayKey, eachDay, endOfDay, startOfDay, utcToday } from './day';

/** The counters a product accumulates in a day, before they are written. */
interface ProductBucket {
  categoryId: string;
  brandId: string | null;
  impressions: number;
  views: number;
  viewerIds: Set<string>;
  searchHits: number;
  searchClicks: number;
  cartAdds: number;
  cartRemovals: number;
  cartAbandons: number;
  favorites: number;
  wishlistAdds: number;
  shares: number;
  contentEngagements: number;
  checkouts: number;
  orders: number;
  units: number;
  revenueSyp: number;
  cancels: number;
  returns: number;
  reviews: number;
  ratingSum: number;
  stockUnits: number;
  liveOffers: number;
  minPriceSyp: number | null;
  inStock: boolean;
}

interface SellerBucket {
  categoryId: string;
  orders: number;
  units: number;
  revenueSyp: number;
  cancels: number;
  returns: number;
  cartAdds: number;
  checkouts: number;
  stockUnits: number;
  priceSyp: number | null;
  isLive: boolean;
}

interface AttributeBucket {
  dimension: TrendAttributeDimension;
  value: string;
  labelAr: string;
  scopeKey: string;
  views: number;
  searchHits: number;
  cartAdds: number;
  favorites: number;
  orders: number;
  units: number;
  revenueSyp: number;
  products: number;
}

/**
 * Layer 1 of the Trend Engine: raw activity in, daily facts out.
 *
 * Two rules shape everything here.
 *
 * **Read the source of truth wherever there is one.** A favourite has a
 * `created_at`; a purchase has an order row; a review has a timestamp and a
 * star count. Those are read from their own tables, not from the analytics
 * stream, so the engine is correct even when a client is three versions old,
 * an event was dropped, or the tracking call was never wired up in the first
 * place. Only the signals that genuinely have no other home — a view, an
 * impression, a search, a share — come from `analytics_events`.
 *
 * **Be idempotent per day.** Every write is an upsert keyed on the day, and the
 * scheduler deliberately re-rolls the last few days on every run. Facts settle
 * late: an order placed on Monday is cancelled on Wednesday, a return is filed
 * on Friday. Re-rolling means Monday's row tells the truth about Monday once
 * Monday is actually over, and it means a crashed run costs nothing but a
 * repeat.
 *
 * Privacy is enforced at this boundary and nowhere else, because this is the
 * last point at which the engine can see a person at all. `viewerIds` is a Set
 * that lives for the length of one day's roll-up and is written out as a count
 * — and as a zero when that count is below `K_ANONYMITY`.
 */
@Injectable()
export class SignalCollectorService {
  private readonly logger = new Logger(SignalCollectorService.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly rates: ExchangeRateService,
    private readonly runs: TrendRunRecorder,
  ) {}

  /**
   * Roll up the last `lookbackDays` days, most recent last.
   *
   * The default of three is the settling window: nearly every cancellation and
   * return that will change a day's numbers has landed within seventy-two
   * hours, and re-reading three days a night is cheap.
   */
  async rollup(
    options: { lookbackDays?: number; triggeredBy?: string | null } = {},
  ): Promise<{ days: number; rows: number }> {
    const lookback = Math.max(1, options.lookbackDays ?? 3);
    const today = utcToday();
    const from = new Date(today.getTime());
    from.setUTCDate(from.getUTCDate() - (lookback - 1));

    const run = await this.runs.start(TrendRunKind.DAILY_ROLLUP, {
      fromDay: from,
      toDay: today,
      triggeredBy: options.triggeredBy ?? null,
    });

    try {
      let rows = 0;
      const perDay: Record<string, number> = {};
      for (const day of eachDay(from, today)) {
        const written = await this.rollupDay(day);
        perDay[dayKey(day)] = written;
        rows += written;
      }
      await this.runs.succeed(run, rows, { days: perDay });
      return { days: lookback, rows };
    } catch (error) {
      await this.runs.fail(run, error);
      throw error;
    }
  }

  /** One day, end to end. Safe to call twice. */
  async rollupDay(day: Date): Promise<number> {
    const start = startOfDay(day);
    const end = endOfDay(day);
    const isToday = dayKey(day) === dayKey(utcToday());

    const products = new Map<string, ProductBucket>();
    const sellers = new Map<string, SellerBucket>();

    // Every product touched today, with the catalogue facts the buckets need.
    const catalogue = new Map<
      string,
      { categoryId: string; brandId: string | null; title: string }
    >();
    const ensure = async (productId: string): Promise<ProductBucket | null> => {
      const existing = products.get(productId);
      if (existing) return existing;
      const meta = catalogue.get(productId);
      if (!meta) return null;
      const bucket = emptyProductBucket(meta.categoryId, meta.brandId);
      products.set(productId, bucket);
      return bucket;
    };

    // ── Gather the ids that saw activity, then load their metadata once ──
    const touched = await this.touchedProductIds(start, end);
    if (touched.size > 0) {
      const rows = await this.prisma.product.findMany({
        where: { id: { in: [...touched] } },
        select: { id: true, categoryId: true, brandId: true, title: true },
      });
      for (const row of rows) {
        catalogue.set(row.id, {
          categoryId: row.categoryId,
          brandId: row.brandId,
          title: row.title,
        });
      }
    }

    await this.collectAnalytics(start, end, ensure);
    await this.collectFavourites(start, end, ensure);
    await this.collectWishlist(start, end, ensure);
    await this.collectCartFloor(start, end, ensure);
    await this.collectReviews(start, end, ensure);
    await this.collectCommerce(start, end, ensure, sellers, catalogue);
    await this.collectReturns(start, end, ensure, sellers, catalogue);
    await this.collectSupply(products, sellers, catalogue, isToday);

    const written = await this.writeProductDays(day, products);
    const sellerRows = await this.writeSellerDays(day, sellers);
    const categoryRows = await this.writeCategoryDay(day, products);
    const attributeRows = await this.writeAttributeDay(day, products, catalogue);
    const searchRows = await this.collectSearchTerms(day, start, end);

    return written + sellerRows + categoryRows + attributeRows + searchRows;
  }

  // ── Which products moved at all today ──────────────────────────────────

  private async touchedProductIds(start: Date, end: Date): Promise<Set<string>> {
    const ids = new Set<string>();
    const add = (rows: Array<{ productId: string | null }>): void => {
      for (const row of rows) if (row.productId) ids.add(row.productId);
    };

    const [events, favourites, wishlist, cart, reviews, items] =
      await Promise.all([
        this.prisma.analyticsEvent.findMany({
          where: { occurredAt: { gte: start, lt: end }, productId: { not: null } },
          select: { productId: true },
          distinct: ['productId'],
        }),
        this.prisma.favorite.findMany({
          where: { createdAt: { gte: start, lt: end } },
          select: { productId: true },
          distinct: ['productId'],
        }),
        this.prisma.wishlistCollectionItem.findMany({
          where: { createdAt: { gte: start, lt: end }, productId: { not: null } },
          select: { productId: true },
          distinct: ['productId'],
        }),
        this.prisma.cartItem.findMany({
          where: { createdAt: { gte: start, lt: end } },
          select: { offer: { select: { productId: true } } },
        }),
        this.prisma.productReview.findMany({
          where: { createdAt: { gte: start, lt: end } },
          select: { productId: true },
          distinct: ['productId'],
        }),
        this.prisma.orderItem.findMany({
          where: { sellerOrder: { createdAt: { gte: start, lt: end } } },
          select: { productId: true },
          distinct: ['productId'],
        }),
      ]);

    add(events);
    add(favourites);
    add(wishlist);
    add(reviews);
    add(items);
    for (const row of cart) ids.add(row.offer.productId);

    // A search event names its results in `metadata.product_ids`; those
    // products were exposed even if nobody touched them afterwards.
    const searches = await this.prisma.analyticsEvent.findMany({
      where: {
        occurredAt: { gte: start, lt: end },
        type: AnalyticsEventType.PRODUCT_SEARCH,
      },
      select: { metadata: true },
    });
    for (const row of searches) {
      for (const id of productIdsFromMetadata(row.metadata)) ids.add(id);
    }

    return ids;
  }

  // ── Attention, from the analytics stream ───────────────────────────────

  private async collectAnalytics(
    start: Date,
    end: Date,
    ensure: (productId: string) => Promise<ProductBucket | null>,
  ): Promise<void> {
    const events = await this.prisma.analyticsEvent.findMany({
      where: { occurredAt: { gte: start, lt: end } },
      select: { type: true, productId: true, userId: true, metadata: true },
    });

    for (const event of events) {
      if (event.type === AnalyticsEventType.PRODUCT_SEARCH) {
        // One event per search, listing the products it surfaced.
        for (const id of productIdsFromMetadata(event.metadata)) {
          const bucket = await ensure(id);
          if (bucket) bucket.searchHits += 1;
        }
        continue;
      }

      if (!event.productId) continue;
      const bucket = await ensure(event.productId);
      if (!bucket) continue;

      switch (event.type) {
        case AnalyticsEventType.PRODUCT_VIEW:
          bucket.views += 1;
          // The only place an identity is read, and it never leaves this Set.
          if (event.userId) bucket.viewerIds.add(event.userId);
          break;
        case AnalyticsEventType.PRODUCT_IMPRESSION:
          bucket.impressions += 1;
          break;
        case AnalyticsEventType.SEARCH_RESULT_CLICK:
          bucket.searchClicks += 1;
          break;
        case AnalyticsEventType.CART_ADD:
          bucket.cartAdds += 1;
          break;
        case AnalyticsEventType.CART_REMOVE:
          bucket.cartRemovals += 1;
          break;
        case AnalyticsEventType.CART_ABANDONED:
          bucket.cartAbandons += 1;
          break;
        case AnalyticsEventType.CHECKOUT_START:
          bucket.checkouts += 1;
          break;
        case AnalyticsEventType.PRODUCT_SHARE:
          bucket.shares += 1;
          break;
        case AnalyticsEventType.PRODUCT_FAVORITE:
          // Counted from the `favorites` table instead — see below. Recorded
          // here only so an un-favourite can be netted off it.
          break;
        case AnalyticsEventType.STORY_VIEW:
        case AnalyticsEventType.POST_ENGAGEMENT:
          bucket.contentEngagements += 1;
          break;
        default:
          break;
      }
    }
  }

  // ── Intent, from the tables that own it ────────────────────────────────

  private async collectFavourites(
    start: Date,
    end: Date,
    ensure: (productId: string) => Promise<ProductBucket | null>,
  ): Promise<void> {
    const rows = await this.prisma.favorite.groupBy({
      by: ['productId'],
      where: { createdAt: { gte: start, lt: end } },
      _count: { _all: true },
    });
    for (const row of rows) {
      const bucket = await ensure(row.productId);
      if (bucket) bucket.favorites += row._count._all;
    }
  }

  private async collectWishlist(
    start: Date,
    end: Date,
    ensure: (productId: string) => Promise<ProductBucket | null>,
  ): Promise<void> {
    const rows = await this.prisma.wishlistCollectionItem.groupBy({
      by: ['productId'],
      where: { createdAt: { gte: start, lt: end }, productId: { not: null } },
      _count: { _all: true },
    });
    for (const row of rows) {
      if (!row.productId) continue;
      const bucket = await ensure(row.productId);
      if (bucket) bucket.wishlistAdds += row._count._all;
    }
  }

  /**
   * A floor under the add-to-cart count, from carts that still exist.
   *
   * `CartItem` rows are deleted at checkout, so this under-counts by exactly
   * the adds that converted — which is why the analytics event is the primary
   * source. Taking the maximum of the two rather than the sum means the number
   * is right when both are present, right when only the events are, and a
   * useful lower bound when a client was never instrumented. Adding them would
   * double-count every abandoned cart, which is the majority of them.
   */
  private async collectCartFloor(
    start: Date,
    end: Date,
    ensure: (productId: string) => Promise<ProductBucket | null>,
  ): Promise<void> {
    const rows = await this.prisma.cartItem.findMany({
      where: { createdAt: { gte: start, lt: end } },
      select: { offer: { select: { productId: true, sellerId: true } } },
    });
    const floor = new Map<string, number>();
    for (const row of rows) {
      const id = row.offer.productId;
      floor.set(id, (floor.get(id) ?? 0) + 1);
    }
    for (const [productId, count] of floor) {
      const bucket = await ensure(productId);
      if (bucket) bucket.cartAdds = Math.max(bucket.cartAdds, count);
    }
  }

  private async collectReviews(
    start: Date,
    end: Date,
    ensure: (productId: string) => Promise<ProductBucket | null>,
  ): Promise<void> {
    const rows = await this.prisma.productReview.groupBy({
      by: ['productId'],
      where: {
        createdAt: { gte: start, lt: end },
        // A rejected review is not evidence about the product.
        status: { in: [ReviewStatus.APPROVED, ReviewStatus.PENDING] },
      },
      _count: { _all: true },
      _sum: { rating: true },
    });
    for (const row of rows) {
      const bucket = await ensure(row.productId);
      if (!bucket) continue;
      bucket.reviews += row._count._all;
      bucket.ratingSum += row._sum.rating ?? 0;
    }
  }

  // ── Outcome, from the order tables ─────────────────────────────────────

  /**
   * Sales, attributed to the day the sub-order was placed.
   *
   * Placement day rather than delivery day because this is a *demand* signal:
   * the question the score is answering is "when did she decide", and a parcel
   * that takes four days to arrive should not move the trend four days later.
   * Cancellations are netted against the same day for the same reason, which
   * is what the three-day settling window in `rollup()` exists to catch.
   */
  private async collectCommerce(
    start: Date,
    end: Date,
    ensure: (productId: string) => Promise<ProductBucket | null>,
    sellers: Map<string, SellerBucket>,
    catalogue: Map<string, { categoryId: string; brandId: string | null }>,
  ): Promise<void> {
    const items = await this.prisma.orderItem.findMany({
      where: { sellerOrder: { createdAt: { gte: start, lt: end } } },
      select: {
        productId: true,
        quantity: true,
        lineTotal: true,
        currency: true,
        sellerOrder: {
          select: { id: true, sellerId: true, status: true },
        },
      },
    });
    if (!items.length) return;

    // Convert once per currency, not once per line: a nightly job that hits
    // the rate table a thousand times is a nightly job that gets switched off.
    const revenueByCurrency = new Map<Currency, number>();
    for (const item of items) {
      revenueByCurrency.set(item.currency, 0);
    }
    const rateFor = new Map<Currency, number>();
    for (const currency of revenueByCurrency.keys()) {
      rateFor.set(currency, await this.sypRate(currency));
    }

    const seenOrders = new Map<string, Set<string>>();
    for (const item of items) {
      if (!item.productId) continue;
      const bucket = await ensure(item.productId);
      if (!bucket) continue;

      const status = item.sellerOrder.status;
      const cancelled = CANCELLED_STATUSES.includes(status);
      const revenue = REVENUE_STATUSES.includes(status);
      const rate = rateFor.get(item.currency) ?? 1;
      const lineSyp = Number(item.lineTotal) * rate;

      // An order counts once per product however many lines it has.
      const seen = seenOrders.get(item.productId) ?? new Set<string>();
      const firstLine = !seen.has(item.sellerOrder.id);
      seen.add(item.sellerOrder.id);
      seenOrders.set(item.productId, seen);

      if (cancelled) {
        bucket.cancels += item.quantity;
      } else {
        if (firstLine) bucket.orders += 1;
        bucket.units += item.quantity;
        if (revenue) bucket.revenueSyp += lineSyp;
      }

      const meta = catalogue.get(item.productId);
      const key = `${item.sellerOrder.sellerId}:${item.productId}`;
      const sellerBucket =
        sellers.get(key) ??
        emptySellerBucket(meta?.categoryId ?? bucket.categoryId);
      if (cancelled) {
        sellerBucket.cancels += item.quantity;
      } else {
        if (firstLine) sellerBucket.orders += 1;
        sellerBucket.units += item.quantity;
        if (revenue) sellerBucket.revenueSyp += lineSyp;
      }
      sellers.set(key, sellerBucket);
    }
  }

  private async collectReturns(
    start: Date,
    end: Date,
    ensure: (productId: string) => Promise<ProductBucket | null>,
    sellers: Map<string, SellerBucket>,
    catalogue: Map<string, { categoryId: string }>,
  ): Promise<void> {
    const rows = await this.prisma.returnItem.findMany({
      where: { request: { createdAt: { gte: start, lt: end } } },
      select: {
        quantity: true,
        orderItem: {
          select: {
            productId: true,
            sellerOrder: { select: { sellerId: true } },
          },
        },
      },
    });
    for (const row of rows) {
      const productId = row.orderItem.productId;
      if (!productId) continue;
      const bucket = await ensure(productId);
      if (bucket) bucket.returns += row.quantity;

      const key = `${row.orderItem.sellerOrder.sellerId}:${productId}`;
      const meta = catalogue.get(productId);
      const sellerBucket =
        sellers.get(key) ??
        emptySellerBucket(meta?.categoryId ?? bucket?.categoryId ?? '');
      sellerBucket.returns += row.quantity;
      sellers.set(key, sellerBucket);
    }
  }

  // ── Supply, snapshotted ────────────────────────────────────────────────

  /**
   * Stock, live offers and price, read from the offers as they stand now.
   *
   * Honest about its own limitation: on a backfill this stamps *today's* stock
   * onto a past day, because nothing in the schema records what stock was on a
   * Tuesday in March. Only the current day's snapshot is a measurement; the
   * rest is the best available approximation, and the availability component
   * it feeds carries the lowest weight in the score for exactly that reason.
   */
  private async collectSupply(
    products: Map<string, ProductBucket>,
    sellers: Map<string, SellerBucket>,
    catalogue: Map<string, { categoryId: string }>,
    isToday: boolean,
  ): Promise<void> {
    const ids = new Set([...products.keys()]);
    for (const key of sellers.keys()) {
      const productId = key.split(':')[1];
      if (productId) ids.add(productId);
    }
    if (!ids.size) return;

    const offers = await this.prisma.sellerOffer.findMany({
      where: { productId: { in: [...ids] } },
      select: {
        productId: true,
        sellerId: true,
        stock: true,
        price: true,
        currency: true,
        status: true,
        isActive: true,
      },
    });

    const currencies = new Set(offers.map((offer) => offer.currency));
    const rateFor = new Map<Currency, number>();
    for (const currency of currencies) {
      rateFor.set(currency, await this.sypRate(currency));
    }

    for (const offer of offers) {
      const live = offer.isActive && offer.status === 'ACTIVE';
      const priceSyp = Number(offer.price) * (rateFor.get(offer.currency) ?? 1);

      const product = products.get(offer.productId);
      if (product) {
        if (live) {
          product.liveOffers += 1;
          product.stockUnits += offer.stock;
          if (offer.stock > 0) product.inStock = true;
          product.minPriceSyp =
            product.minPriceSyp === null
              ? priceSyp
              : Math.min(product.minPriceSyp, priceSyp);
        }
      }

      const key = `${offer.sellerId}:${offer.productId}`;
      const sellerBucket = sellers.get(key);
      if (sellerBucket) {
        sellerBucket.stockUnits += offer.stock;
        sellerBucket.priceSyp = priceSyp;
        sellerBucket.isLive = sellerBucket.isLive || live;
      } else if (isToday && live && offer.stock > 0) {
        // A live offer that sold nothing today is still a fact worth keeping:
        // without it the forecaster sees a gap instead of a zero, and a quiet
        // week reads as missing data rather than as a quiet week.
        const meta = catalogue.get(offer.productId);
        if (!meta) continue;
        const fresh = emptySellerBucket(meta.categoryId);
        fresh.stockUnits = offer.stock;
        fresh.priceSyp = priceSyp;
        fresh.isLive = true;
        sellers.set(key, fresh);
      }
    }
  }

  // ── Writers ────────────────────────────────────────────────────────────

  private async writeProductDays(
    day: Date,
    products: Map<string, ProductBucket>,
  ): Promise<number> {
    let written = 0;
    for (const [productId, bucket] of products) {
      // k-anonymity: a count below the floor is written as zero, because a
      // "1 viewer" beside a date on a seller's dashboard is a person.
      const viewers =
        bucket.viewerIds.size >= K_ANONYMITY ? bucket.viewerIds.size : 0;

      const data = {
        categoryId: bucket.categoryId,
        brandId: bucket.brandId,
        impressions: bucket.impressions,
        views: bucket.views,
        viewers,
        searchHits: bucket.searchHits,
        searchClicks: bucket.searchClicks,
        cartAdds: bucket.cartAdds,
        cartRemovals: bucket.cartRemovals,
        cartAbandons: bucket.cartAbandons,
        favorites: bucket.favorites,
        wishlistAdds: bucket.wishlistAdds,
        shares: bucket.shares,
        contentEngagements: bucket.contentEngagements,
        checkouts: bucket.checkouts,
        orders: bucket.orders,
        units: bucket.units,
        revenueSyp: new Prisma.Decimal(bucket.revenueSyp.toFixed(4)),
        cancels: bucket.cancels,
        returns: bucket.returns,
        reviews: bucket.reviews,
        ratingSum: bucket.ratingSum,
        stockUnits: bucket.stockUnits,
        liveOffers: bucket.liveOffers,
        minPriceSyp:
          bucket.minPriceSyp === null
            ? null
            : new Prisma.Decimal(bucket.minPriceSyp.toFixed(4)),
        inStock: bucket.inStock,
      };

      await this.prisma.productDemandDaily.upsert({
        where: { productId_day: { productId, day } },
        create: { productId, day, ...data },
        update: data,
      });
      written += 1;
    }
    return written;
  }

  private async writeSellerDays(
    day: Date,
    sellers: Map<string, SellerBucket>,
  ): Promise<number> {
    let written = 0;
    for (const [key, bucket] of sellers) {
      const [sellerId, productId] = key.split(':');
      if (!sellerId || !productId || !bucket.categoryId) continue;

      const data = {
        categoryId: bucket.categoryId,
        orders: bucket.orders,
        units: bucket.units,
        revenueSyp: new Prisma.Decimal(bucket.revenueSyp.toFixed(4)),
        cancels: bucket.cancels,
        returns: bucket.returns,
        cartAdds: bucket.cartAdds,
        checkouts: bucket.checkouts,
        stockUnits: bucket.stockUnits,
        priceSyp:
          bucket.priceSyp === null
            ? null
            : new Prisma.Decimal(bucket.priceSyp.toFixed(4)),
        isLive: bucket.isLive,
      };

      await this.prisma.sellerDemandDaily.upsert({
        where: { sellerId_productId_day: { sellerId, productId, day } },
        create: { sellerId, productId, day, ...data },
        update: data,
      });
      written += 1;
    }
    return written;
  }

  /**
   * Category facts, rolled up the tree.
   *
   * A product's numbers land on its own category *and on every ancestor*, so
   * «حقائب» answers for its subtree rather than only for the leaf a product
   * happens to sit in. Without the ancestor pass, every parent category on the
   * platform would read as empty, which is precisely the level a merchandiser
   * looks at first.
   */
  private async writeCategoryDay(
    day: Date,
    products: Map<string, ProductBucket>,
  ): Promise<number> {
    if (!products.size) return 0;

    const parents = await this.categoryParents();
    const totals = new Map<
      string,
      {
        views: number;
        searchHits: number;
        cartAdds: number;
        favorites: number;
        orders: number;
        units: number;
        revenueSyp: number;
        returns: number;
        reviews: number;
        ratingSum: number;
        liveProducts: number;
        inStockProducts: number;
        prices: number[];
      }
    >();

    for (const bucket of products.values()) {
      for (const categoryId of lineage(bucket.categoryId, parents)) {
        const row =
          totals.get(categoryId) ??
          {
            views: 0,
            searchHits: 0,
            cartAdds: 0,
            favorites: 0,
            orders: 0,
            units: 0,
            revenueSyp: 0,
            returns: 0,
            reviews: 0,
            ratingSum: 0,
            liveProducts: 0,
            inStockProducts: 0,
            prices: [] as number[],
          };
        row.views += bucket.views;
        row.searchHits += bucket.searchHits;
        row.cartAdds += bucket.cartAdds;
        row.favorites += bucket.favorites;
        row.orders += bucket.orders;
        row.units += bucket.units;
        row.revenueSyp += bucket.revenueSyp;
        row.returns += bucket.returns;
        row.reviews += bucket.reviews;
        row.ratingSum += bucket.ratingSum;
        if (bucket.liveOffers > 0) row.liveProducts += 1;
        if (bucket.inStock) row.inStockProducts += 1;
        if (bucket.minPriceSyp !== null) row.prices.push(bucket.minPriceSyp);
        totals.set(categoryId, row);
      }
    }

    let written = 0;
    for (const [categoryId, row] of totals) {
      const data = {
        views: row.views,
        searchHits: row.searchHits,
        cartAdds: row.cartAdds,
        favorites: row.favorites,
        orders: row.orders,
        units: row.units,
        revenueSyp: new Prisma.Decimal(row.revenueSyp.toFixed(4)),
        returns: row.returns,
        reviews: row.reviews,
        ratingSum: row.ratingSum,
        liveProducts: row.liveProducts,
        inStockProducts: row.inStockProducts,
        medianPriceSyp: row.prices.length
          ? new Prisma.Decimal(median(row.prices).toFixed(4))
          : null,
      };
      await this.prisma.categoryDemandDaily.upsert({
        where: { categoryId_day: { categoryId, day } },
        create: { categoryId, day, ...data },
        update: data,
      });
      written += 1;
    }
    return written;
  }

  /**
   * Facet demand: colour, price band and brand.
   *
   * Colour is read from the variants a product actually offers and from its
   * title, through the stylist's colour vocabulary, so «أسود» and «black» and
   * «اسود» are one colour. Each product contributes its whole day to every
   * colour it comes in — a bag sold in three colours is demand for the bag, and
   * attributing a third of it to each would be a guess dressed up as a number.
   */
  private async writeAttributeDay(
    day: Date,
    products: Map<string, ProductBucket>,
    catalogue: Map<string, { categoryId: string; title: string }>,
  ): Promise<number> {
    if (!products.size) return 0;

    const variants = await this.prisma.productVariant.findMany({
      where: { productId: { in: [...products.keys()] } },
      select: { productId: true, name: true, attributes: true },
    });
    const variantText = new Map<string, string[]>();
    for (const variant of variants) {
      const list = variantText.get(variant.productId) ?? [];
      list.push(variant.name, ...attributeStrings(variant.attributes));
      variantText.set(variant.productId, list);
    }

    const parents = await this.categoryParents();
    const buckets = new Map<string, AttributeBucket>();
    const add = (
      dimension: TrendAttributeDimension,
      value: string,
      labelAr: string,
      scopeKey: string,
      bucket: ProductBucket,
    ): void => {
      const key = `${dimension}:${value}:${scopeKey}`;
      const row =
        buckets.get(key) ??
        ({
          dimension,
          value,
          labelAr,
          scopeKey,
          views: 0,
          searchHits: 0,
          cartAdds: 0,
          favorites: 0,
          orders: 0,
          units: 0,
          revenueSyp: 0,
          products: 0,
        } satisfies AttributeBucket);
      row.views += bucket.views;
      row.searchHits += bucket.searchHits;
      row.cartAdds += bucket.cartAdds;
      row.favorites += bucket.favorites;
      row.orders += bucket.orders;
      row.units += bucket.units;
      row.revenueSyp += bucket.revenueSyp;
      row.products += 1;
      buckets.set(key, row);
    };

    for (const [productId, bucket] of products) {
      const meta = catalogue.get(productId);
      const text = [meta?.title ?? '', ...(variantText.get(productId) ?? [])]
        .filter(Boolean)
        .join(' ');
      // The root of the product's branch — the level a colour trend is read at.
      const scope = lineage(bucket.categoryId, parents).at(-1) ?? bucket.categoryId;

      for (const colour of new Set(detectColours(text))) {
        add(TrendAttributeDimension.COLOR, colour, colourLabel(colour), PLATFORM_SCOPE, bucket);
        add(TrendAttributeDimension.COLOR, colour, colourLabel(colour), scope, bucket);
      }

      if (bucket.minPriceSyp !== null) {
        const band = priceBandFor(bucket.minPriceSyp);
        if (band) {
          add(TrendAttributeDimension.PRICE_BAND, band, priceBandLabel(band), PLATFORM_SCOPE, bucket);
          add(TrendAttributeDimension.PRICE_BAND, band, priceBandLabel(band), scope, bucket);
        }
      }

      if (bucket.brandId) {
        add(TrendAttributeDimension.BRAND, bucket.brandId, bucket.brandId, PLATFORM_SCOPE, bucket);
      }
    }

    // Brand labels, resolved in one query rather than one per bucket.
    const brandIds = [...buckets.values()]
      .filter((row) => row.dimension === TrendAttributeDimension.BRAND)
      .map((row) => row.value);
    if (brandIds.length) {
      const brands = await this.prisma.brand.findMany({
        where: { id: { in: brandIds } },
        select: { id: true, nameAr: true },
      });
      const names = new Map(brands.map((brand) => [brand.id, brand.nameAr]));
      for (const row of buckets.values()) {
        if (row.dimension === TrendAttributeDimension.BRAND) {
          row.labelAr = names.get(row.value) ?? row.value;
        }
      }
    }

    let written = 0;
    for (const row of buckets.values()) {
      const data = {
        labelAr: row.labelAr,
        views: row.views,
        searchHits: row.searchHits,
        cartAdds: row.cartAdds,
        favorites: row.favorites,
        orders: row.orders,
        units: row.units,
        revenueSyp: new Prisma.Decimal(row.revenueSyp.toFixed(4)),
        products: row.products,
      };
      await this.prisma.trendAttributeDaily.upsert({
        where: {
          dimension_value_scopeKey_day: {
            dimension: row.dimension,
            value: row.value,
            scopeKey: row.scopeKey,
            day,
          },
        },
        create: {
          dimension: row.dimension,
          value: row.value,
          scopeKey: row.scopeKey,
          day,
          ...data,
        },
        update: data,
      });
      written += 1;
    }
    return written;
  }

  /**
   * Search terms, normalised and counted.
   *
   * The raw query text is read here and thrown away: what is stored is the
   * facet key, a display spelling, and counts. Nothing links a term to the
   * woman who typed it, which is what makes it safe to keep this table
   * forever while the raw events are pruned.
   */
  private async collectSearchTerms(
    day: Date,
    start: Date,
    end: Date,
  ): Promise<number> {
    const events = await this.prisma.analyticsEvent.findMany({
      where: {
        occurredAt: { gte: start, lt: end },
        type: {
          in: [
            AnalyticsEventType.PRODUCT_SEARCH,
            AnalyticsEventType.SEARCH_ZERO_RESULT,
            AnalyticsEventType.SEARCH_RESULT_CLICK,
          ],
        },
      },
      select: { type: true, metadata: true },
    });
    if (!events.length) return 0;

    interface TermBucket {
      display: Map<string, number>;
      searches: number;
      zeroResults: number;
      resultsSum: number;
      clicks: number;
    }
    const terms = new Map<string, TermBucket>();

    for (const event of events) {
      const raw = stringFromMetadata(event.metadata, 'q');
      if (!raw) continue;
      const { termKey, display } = normaliseQuery(raw);
      if (!termKey) continue;

      const bucket =
        terms.get(termKey) ??
        ({ display: new Map(), searches: 0, zeroResults: 0, resultsSum: 0, clicks: 0 } satisfies TermBucket);
      bucket.display.set(display, (bucket.display.get(display) ?? 0) + 1);

      if (event.type === AnalyticsEventType.SEARCH_RESULT_CLICK) {
        bucket.clicks += 1;
      } else {
        bucket.searches += 1;
        const results = numberFromMetadata(event.metadata, 'results');
        bucket.resultsSum += results ?? 0;
        if (event.type === AnalyticsEventType.SEARCH_ZERO_RESULT || results === 0) {
          bucket.zeroResults += 1;
        }
      }
      terms.set(termKey, bucket);
    }

    let written = 0;
    for (const [termKey, bucket] of terms) {
      // The spelling most women used, not the first one seen.
      const display =
        [...bucket.display.entries()].sort((a, b) => b[1] - a[1])[0]?.[0] ?? termKey;
      const data = {
        display,
        searches: bucket.searches,
        zeroResults: bucket.zeroResults,
        resultsSum: bucket.resultsSum,
        clicks: bucket.clicks,
      };
      await this.prisma.searchTermDaily.upsert({
        where: { termKey_day: { termKey, day } },
        create: { termKey, day, ...data },
        update: data,
      });
      written += 1;
    }
    return written;
  }

  // ── Helpers ────────────────────────────────────────────────────────────

  private categoryParentCache: Map<string, string | null> | null = null;

  /** The whole (small) category tree, loaded once per process. */
  private async categoryParents(): Promise<Map<string, string | null>> {
    if (this.categoryParentCache) return this.categoryParentCache;
    const rows = await this.prisma.category.findMany({
      select: { id: true, parentId: true },
    });
    this.categoryParentCache = new Map(
      rows.map((row) => [row.id, row.parentId]),
    );
    return this.categoryParentCache;
  }

  /** Drops the cached tree. Called after a category is created or moved. */
  invalidateCategoryCache(): void {
    this.categoryParentCache = null;
  }

  /**
   * SYP per unit of `currency`. Falls back to 1 rather than throwing: a
   * missing rate should degrade one number, not abort the night's roll-up.
   */
  private async sypRate(currency: Currency): Promise<number> {
    if (currency === Currency.SYP) return 1;
    try {
      const converted = await this.rates.toSyp(Money.of(1, currency));
      return Number(converted.amount);
    } catch (error) {
      this.logger.warn(
        `No ${currency}→SYP rate; revenue in ${currency} is counted at par for this roll-up.`,
      );
      return 1;
    }
  }
}

// ── Pure helpers ─────────────────────────────────────────────────────────

function emptyProductBucket(
  categoryId: string,
  brandId: string | null,
): ProductBucket {
  return {
    categoryId,
    brandId,
    impressions: 0,
    views: 0,
    viewerIds: new Set(),
    searchHits: 0,
    searchClicks: 0,
    cartAdds: 0,
    cartRemovals: 0,
    cartAbandons: 0,
    favorites: 0,
    wishlistAdds: 0,
    shares: 0,
    contentEngagements: 0,
    checkouts: 0,
    orders: 0,
    units: 0,
    revenueSyp: 0,
    cancels: 0,
    returns: 0,
    reviews: 0,
    ratingSum: 0,
    stockUnits: 0,
    liveOffers: 0,
    minPriceSyp: null,
    inStock: false,
  };
}

function emptySellerBucket(categoryId: string): SellerBucket {
  return {
    categoryId,
    orders: 0,
    units: 0,
    revenueSyp: 0,
    cancels: 0,
    returns: 0,
    cartAdds: 0,
    checkouts: 0,
    stockUnits: 0,
    priceSyp: null,
    isLive: false,
  };
}

/** A category and every ancestor above it, leaf first, root last. */
export function lineage(
  categoryId: string,
  parents: Map<string, string | null>,
): string[] {
  const chain: string[] = [];
  let current: string | null | undefined = categoryId;
  // A cycle in the tree would otherwise hang the nightly job.
  const guard = new Set<string>();
  while (current && !guard.has(current)) {
    guard.add(current);
    chain.push(current);
    current = parents.get(current) ?? null;
  }
  return chain;
}

function productIdsFromMetadata(metadata: Prisma.JsonValue | null): string[] {
  if (!metadata || typeof metadata !== 'object' || Array.isArray(metadata)) {
    return [];
  }
  const raw = (metadata as Record<string, unknown>).product_ids;
  if (!Array.isArray(raw)) return [];
  return raw.filter((value): value is string => typeof value === 'string');
}

function stringFromMetadata(
  metadata: Prisma.JsonValue | null,
  key: string,
): string | null {
  if (!metadata || typeof metadata !== 'object' || Array.isArray(metadata)) {
    return null;
  }
  const value = (metadata as Record<string, unknown>)[key];
  return typeof value === 'string' && value.trim() ? value : null;
}

function numberFromMetadata(
  metadata: Prisma.JsonValue | null,
  key: string,
): number | null {
  if (!metadata || typeof metadata !== 'object' || Array.isArray(metadata)) {
    return null;
  }
  const value = (metadata as Record<string, unknown>)[key];
  return typeof value === 'number' && Number.isFinite(value) ? value : null;
}

/** Every string value in a variant's attribute object, for colour detection. */
function attributeStrings(attributes: Prisma.JsonValue | null): string[] {
  if (!attributes || typeof attributes !== 'object' || Array.isArray(attributes)) {
    return [];
  }
  return Object.values(attributes as Record<string, unknown>).filter(
    (value): value is string => typeof value === 'string',
  );
}

export { PRICE_BANDS, ProductStatus };
