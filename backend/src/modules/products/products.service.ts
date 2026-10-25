import { Injectable, Logger, NotFoundException } from '@nestjs/common';
import {
  AnalyticsEventType,
  CommerceContentCommentStatus,
  OrderStatus,
  Prisma,
  ReviewStatus,
} from '@prisma/client';
import { PrismaService } from '../../prisma/prisma.service';
import { CacheService } from '../../common/cache/cache.service';
import { ValueVisibilityService } from '../value/value-visibility.service';
import { TrendSignalService } from '../trends/collection/trend-signal.service';
import {
  PRODUCT_CARD_INCLUDE,
  PRODUCT_INCLUDE,
  PURCHASABLE_PRODUCT_WHERE,
} from '../../common/catalog/product-include';
import { categorySubtreeIds } from '../../common/catalog/category-subtree';
import { serializeProduct } from '../../common/serializers';
import { ProductQueryDto } from './dto/product-query.dto';

type Query = ProductQueryDto;
type OrderBy = Prisma.ProductOrderByWithRelationInput[];

/** One view per person per product per day. */
const VIEW_WINDOW_MS = 24 * 60 * 60 * 1000;

/** Orders that never became a sale are not "sold". */
const UNSOLD_ORDER_STATUSES = [
  OrderStatus.DRAFT,
  OrderStatus.PENDING_PAYMENT,
  OrderStatus.CANCELLED,
];

/** The figures the product page prints under the title, counted live. */
interface LiveCounters {
  rating: number;
  reviewsCount: number;
  favoritesCount: number;
  likesCount: number;
  picksCount: number;
  commentsCount: number;
  ordersCount: number;
}

/**
 * Public catalog browsing.
 *
 * Everything here reads the CANONICAL product and the offers hanging off it —
 * price, stock and availability are properties of an offer now, so "in stock"
 * is `offers: { some: … }` rather than a column on the product row.
 */
@Injectable()
export class ProductsService {
  private readonly logger = new Logger(ProductsService.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly signals: TrendSignalService,
    private readonly visibility: ValueVisibilityService,
    private readonly cache: CacheService,
  ) {}

  async home(viewerId?: string) {
    const gate = await this.visibility.catalogFilter(viewerId);
    const [trending, newArrivals, featured, mostLoved, forYou] =
      await Promise.all([
        this.find({
          orderBy: [{ ordersCount: 'desc' }, { viewsCount: 'desc' }],
          take: 12,
          gate,
        }),
        this.find({ orderBy: [{ createdAt: 'desc' }], take: 12, gate }),
        this.find({
          where: { ...PURCHASABLE_PRODUCT_WHERE, isFeatured: true },
          orderBy: [{ createdAt: 'desc' }],
          take: 12,
          gate,
        }),
        this.find({
          orderBy: [{ favoritesCount: 'desc' }, { rating: 'desc' }],
          take: 12,
          gate,
        }),
        this.find({
          where: { ...PURCHASABLE_PRODUCT_WHERE, showInFeed: true },
          orderBy: [{ rating: 'desc' }, { createdAt: 'desc' }],
          take: 12,
          gate,
        }),
      ]);

    return {
      trending: await this.serializeList(trending, viewerId),
      new_arrivals: await this.serializeList(newArrivals, viewerId),
      featured: await this.serializeList(featured, viewerId),
      most_loved: await this.serializeList(mostLoved, viewerId),
      for_you: await this.serializeList(forYou, viewerId),
    };
  }

  trending(viewerId?: string) {
    return this.collection(
      { orderBy: [{ ordersCount: 'desc' }, { viewsCount: 'desc' }] },
      viewerId,
    );
  }

  newArrivals(viewerId?: string) {
    return this.collection({ orderBy: [{ createdAt: 'desc' }] }, viewerId);
  }

  featured(viewerId?: string) {
    return this.collection(
      {
        where: { ...PURCHASABLE_PRODUCT_WHERE, isFeatured: true },
        orderBy: [{ createdAt: 'desc' }],
      },
      viewerId,
    );
  }

  mostLoved(viewerId?: string) {
    return this.collection(
      { orderBy: [{ favoritesCount: 'desc' }, { createdAt: 'desc' }] },
      viewerId,
    );
  }

  topRated(viewerId?: string) {
    return this.collection(
      { orderBy: [{ rating: 'desc' }, { reviewsCount: 'desc' }] },
      viewerId,
    );
  }

  async list(query: Query, viewerId?: string) {
    return this.paginated(
      this.buildFilters(query),
      this.sortFor(query),
      query,
      viewerId,
    );
  }

  async search(query: Query, viewerId?: string) {
    const q = (query.q ?? '').trim();
    const where: Prisma.ProductWhereInput = {
      ...this.buildFilters(query),
      ...(q
        ? {
            OR: [
              { title: { contains: q, mode: 'insensitive' } },
              { description: { contains: q, mode: 'insensitive' } },
              { brand: { nameAr: { contains: q, mode: 'insensitive' } } },
              { brand: { nameEn: { contains: q, mode: 'insensitive' } } },
            ],
          }
        : {}),
    };
    return this.paginated(where, this.sortFor(query), query, viewerId);
  }

  /**
   * Category browsing by slug. A leaf slug matches its own products; a parent
   * slug matches everything beneath it, so `/women/clothing` still returns
   * dresses without the client having to expand the tree itself.
   */
  async byCategory(
    slug: string,
    query: Query,
    viewerId: string | undefined,
    orderBy: OrderBy,
  ) {
    const categoryIds = await this.categorySubtree(slug);
    if (categoryIds.length === 0) throw new NotFoundException('Category not found');

    const where: Prisma.ProductWhereInput = {
      ...this.buildFilters(query),
      categoryId: { in: categoryIds },
    };
    return this.paginated(where, orderBy, query, viewerId);
  }

  async detail(id: string, viewerId?: string) {
    // The same visibility rule the listings apply, applied to the one-product
    // read as well.
    //
    // Hiding an exclusive piece from the catalogue but serving it to anyone who
    // holds its id is not a rule, it is an inconvenience: links travel through
    // chats, posts and stories, which is precisely how a "members only" drop
    // would leak. The listing gate is the wrong place to stop, so the gate is
    // repeated here.
    //
    // A hidden product answers 404, not 403, and deliberately: refusing by name
    // would confirm to someone without the standing that there is something
    // there to want.
    const visibility = await this.visibility.catalogFilter(viewerId);
    const visible = await this.prisma.product.findFirst({
      where: { id, ...visibility },
      select: { id: true },
    });
    if (!visible) throw new NotFoundException('Product not found');

    const stored = await this.prisma.product.findUnique({
      where: { id },
      include: PRODUCT_INCLUDE,
    });
    if (!stored) throw new NotFoundException('Product not found');

    const [counted, live] = await Promise.all([
      this.registerView(stored, viewerId, 'product.detail'),
      this.liveCounters(stored.id),
    ]);
    this.healCounters(stored, live);
    // The figures under the title are the ones the tables hold right now —
    // see `liveCounters` — and the view she just made is among them.
    const product = {
      ...stored,
      ...live,
      viewsCount: stored.viewsCount + (counted ? 1 : 0),
    };

    // The detail screen is where price comparison happens, so every live offer
    // travels with it (Q23 P2).
    const favSet = viewerId
      ? await this.favoriteSet(viewerId, [product.id])
      : new Set<string>();

    return serializeProduct(product, {
      isLiked: favSet.has(product.id),
      includeOffers: true,
    });
  }

  async recordView(id: string, viewerId?: string) {
    const product = await this.requireProduct(id);
    await this.registerView(product, viewerId, 'product.view');
    return { message: 'View recorded' };
  }

  // ── The numbers under the title ───────────────────────────────────────
  //
  // The product page prints a rating, a save count, a view count and how many
  // were sold, and the client read every one of them as invented. Some were:
  // a view was added on *every* load of the page — a refresh, a return from
  // the bag, the boutique checking her own listing — and the stored counters
  // are incremented in a dozen places, so any missed path left them drifting
  // with nothing to bring them back. Now a view is a person, once a day, and
  // never the boutique; and every other figure is counted from its own table
  // when the page is served.

  /**
   * Counts this open as a view when it is one: once per viewer per day, and
   * never the boutique looking at her own listing. A guest has no identity to
   * de-duplicate on, so each of her opens counts — they are real opens by
   * somebody who is not the seller.
   *
   * The dated analytics row is written for the same opens and no others, so
   * the trend engine and the seller's funnel read the same views the page
   * shows.
   */
  private async registerView(
    product: { id: string; createdBySellerId: string | null },
    viewerId: string | undefined,
    source: string,
  ): Promise<boolean> {
    if (viewerId) {
      if (product.createdBySellerId === viewerId) return false;
      // Fast path for the page being re-fetched within the same minute; the
      // database check below covers a restart and a second instance.
      const key = `pv:${product.id}:${viewerId}`;
      if (this.cache.get<boolean>(key)) return false;
      this.cache.set(key, true, VIEW_WINDOW_MS);

      const since = new Date(Date.now() - VIEW_WINDOW_MS);
      const [ownOffers, recent] = await Promise.all([
        this.prisma.sellerOffer.count({
          where: { productId: product.id, sellerId: viewerId },
        }),
        this.prisma.analyticsEvent.count({
          where: {
            productId: product.id,
            userId: viewerId,
            type: AnalyticsEventType.PRODUCT_VIEW,
            occurredAt: { gte: since },
          },
        }),
      ]);
      if (ownOffers > 0 || recent > 0) return false;
    }

    await this.prisma.product.update({
      where: { id: product.id },
      data: { viewsCount: { increment: 1 } },
    });
    // `viewsCount` is a lifetime counter and cannot answer "was this product
    // climbing last week". The dated signal can, so both are kept.
    this.signals.recordProductView({
      productId: product.id,
      userId: viewerId ?? null,
      source,
    });
    return true;
  }

  /**
   * Every figure the page shows, counted from the rows behind it — the same
   * definitions `prisma/demo/reconcile.ts` rebuilds the columns with. Six
   * indexed aggregates over one product's rows.
   */
  private async liveCounters(productId: string): Promise<LiveCounters> {
    const [reviews, favorites, likes, picks, comments, sold] =
      await Promise.all([
        this.prisma.productReview.aggregate({
          where: { productId, status: ReviewStatus.APPROVED },
          _avg: { rating: true },
          _count: { _all: true },
        }),
        this.prisma.favorite.count({ where: { productId } }),
        this.prisma.productLike.count({ where: { productId } }),
        this.prisma.productPick.count({ where: { productId } }),
        this.prisma.productComment.count({
          where: { productId, status: CommerceContentCommentStatus.VISIBLE },
        }),
        this.prisma.orderItem.aggregate({
          where: {
            productId,
            sellerOrder: {
              order: { status: { notIn: UNSOLD_ORDER_STATUSES } },
            },
          },
          _sum: { quantity: true },
        }),
      ]);
    return {
      rating: Math.round((reviews._avg.rating ?? 0) * 100) / 100,
      reviewsCount: reviews._count._all,
      favoritesCount: favorites,
      likesCount: likes,
      picksCount: picks,
      commentsCount: comments,
      ordersCount: sold._sum.quantity ?? 0,
    };
  }

  /**
   * Writes the live figures back when the stored columns have drifted, so
   * the cards, rails and rankings that read the columns agree with the page.
   * Off the request path: the page already has its numbers.
   */
  private healCounters(
    stored: LiveCounters & { id: string },
    live: LiveCounters,
  ): void {
    const drift = (Object.keys(live) as (keyof LiveCounters)[]).filter(
      (key) => stored[key] !== live[key],
    );
    if (drift.length === 0) return;
    void this.prisma.product
      .update({ where: { id: stored.id }, data: live })
      .catch((error: unknown) =>
        this.logger.warn(
          `Counters not healed for ${stored.id}: ${String(error)}`,
        ),
      );
  }

  async incrementOrders(id: string, amount = 1) {
    await this.requireProduct(id);
    await this.prisma.product.update({
      where: { id },
      data: { ordersCount: { increment: amount } },
    });
    return { message: 'Order count updated' };
  }

  // ── internals ──────────────────────────────────────────────────────────

  private async requireProduct(id: string) {
    const product = await this.prisma.product.findUnique({ where: { id } });
    if (!product) throw new NotFoundException('Product not found');
    return product;
  }

  /** The category itself plus every descendant, for the 3-level tree (Q26). */
  private categorySubtree(slug: string): Promise<string[]> {
    return categorySubtreeIds(this.prisma, slug);
  }

  private find(args: {
    where?: Prisma.ProductWhereInput;
    orderBy: OrderBy;
    take?: number;
    skip?: number;
    /** Ohara Value's visibility clause for the viewer — see `paginated`. */
    gate?: Prisma.ProductWhereInput;
  }) {
    const where = args.where ?? PURCHASABLE_PRODUCT_WHERE;
    return this.prisma.product.findMany({
      where:
        args.gate && Object.keys(args.gate).length
          ? { AND: [where, args.gate] }
          : where,
      orderBy: args.orderBy,
      skip: args.skip ?? 0,
      take: args.take ?? 20,
      include: PRODUCT_CARD_INCLUDE,
    });
  }

  private async collection(
    args: { where?: Prisma.ProductWhereInput; orderBy: OrderBy },
    viewerId?: string,
  ) {
    const gate = await this.visibility.catalogFilter(viewerId);
    const products = await this.find({ ...args, take: 20, gate });
    return this.serializeList(products, viewerId);
  }

  private async paginated(
    where: Prisma.ProductWhereInput,
    orderBy: OrderBy,
    query: Query,
    viewerId?: string,
  ) {
    const { page, limit, skip } = this.pagination(query);

    /**
     * Ohara Value's visibility rules, applied here rather than at each call
     * site.
     *
     * `list`, `search` and `byCategory` all funnel through this method, so one
     * clause covers every browse surface — and, because the same `where` feeds
     * both the page and the count, a hidden product does not leave a gap in the
     * pagination. Filtering after the fetch would have done both jobs badly.
     */
    const visibility = await this.visibility.catalogFilter(viewerId);
    const gated: Prisma.ProductWhereInput = Object.keys(visibility).length
      ? { AND: [where, visibility] }
      : where;

    const [products, total] = await Promise.all([
      this.find({ where: gated, orderBy, take: limit, skip }),
      this.prisma.product.count({ where: gated }),
    ]);

    return {
      data: await this.serializeList(products, viewerId),
      pagination: {
        page,
        limit,
        total,
        total_pages: Math.ceil(total / limit),
        has_next_page: skip + products.length < total,
      },
    };
  }

  private async serializeList(
    products: Prisma.ProductGetPayload<{
      include: typeof PRODUCT_CARD_INCLUDE;
    }>[],
    viewerId?: string,
  ) {
    if (!viewerId) {
      return products.map((product) =>
        serializeProduct(product, { isLiked: false }),
      );
    }
    const favSet = await this.favoriteSet(
      viewerId,
      products.map((product) => product.id),
    );
    return products.map((product) =>
      serializeProduct(product, { isLiked: favSet.has(product.id) }),
    );
  }

  private async favoriteSet(
    userId: string,
    productIds: string[],
  ): Promise<Set<string>> {
    if (productIds.length === 0) return new Set();
    const favorites = await this.prisma.favorite.findMany({
      where: { userId, productId: { in: productIds } },
      select: { productId: true },
    });
    return new Set(favorites.map((favorite) => favorite.productId));
  }

  private pagination(query: Query) {
    const page = Math.max(1, query.page ?? 1);
    const limit = Math.min(50, Math.max(1, query.limit ?? 20));
    return { page, limit, skip: (page - 1) * limit };
  }

  private sortFor(query: Query): OrderBy {
    switch (query.sort) {
      // Price sorts run off the SYP-normalised roll-up so offers priced in USD
      // interleave correctly instead of sorting as raw numbers.
      case 'price_asc':
        return [{ minPriceSyp: 'asc' }, { createdAt: 'desc' }];
      case 'price_desc':
        return [{ minPriceSyp: 'desc' }, { createdAt: 'desc' }];
      case 'rating':
        return [{ rating: 'desc' }, { reviewsCount: 'desc' }];
      case 'popular':
        return [{ ordersCount: 'desc' }, { viewsCount: 'desc' }];
      default:
        return [{ createdAt: 'desc' }];
    }
  }

  private buildFilters(query: Query): Prisma.ProductWhereInput {
    const minPrice = query.min_price ? Number(query.min_price) : undefined;
    const maxPrice = query.max_price ? Number(query.max_price) : undefined;
    const rating = query.rating;
    const featured =
      query.featured === undefined ? undefined : query.featured === 'true';

    return {
      ...PURCHASABLE_PRODUCT_WHERE,
      ...(featured !== undefined ? { isFeatured: featured } : {}),
      ...(query.brand_id ? { brandId: query.brand_id } : {}),
      ...(rating !== undefined && !Number.isNaN(rating)
        ? { rating: { gte: rating } }
        : {}),
      ...(minPrice !== undefined || maxPrice !== undefined
        ? {
            minPriceSyp: {
              ...(minPrice !== undefined && !Number.isNaN(minPrice)
                ? { gte: minPrice }
                : {}),
              ...(maxPrice !== undefined && !Number.isNaN(maxPrice)
                ? { lte: maxPrice }
                : {}),
            },
          }
        : {}),
    };
  }
}
