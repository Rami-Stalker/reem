import { Injectable, NotFoundException } from '@nestjs/common';
import { Prisma } from '@prisma/client';
import { PrismaService } from '../../prisma/prisma.service';
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

/**
 * Public catalog browsing.
 *
 * Everything here reads the CANONICAL product and the offers hanging off it —
 * price, stock and availability are properties of an offer now, so "in stock"
 * is `offers: { some: … }` rather than a column on the product row.
 */
@Injectable()
export class ProductsService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly signals: TrendSignalService,
    private readonly visibility: ValueVisibilityService,
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

    const product = await this.prisma.product
      .update({
        where: { id },
        data: { viewsCount: { increment: 1 } },
        include: PRODUCT_INCLUDE,
      })
      .catch(() => null);
    if (!product) throw new NotFoundException('Product not found');

    // `viewsCount` above is a lifetime counter and cannot answer "was this
    // product climbing last week". The dated signal can, so both are kept.
    this.signals.recordProductView({
      productId: product.id,
      userId: viewerId ?? null,
      source: 'product.detail',
    });

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
    await this.requireProduct(id);
    await this.prisma.product.update({
      where: { id },
      data: { viewsCount: { increment: 1 } },
    });
    this.signals.recordProductView({
      productId: id,
      userId: viewerId ?? null,
      source: 'product.view',
    });
    return { message: 'View recorded' };
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
    /** Reem Value's visibility clause for the viewer — see `paginated`. */
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
     * Reem Value's visibility rules, applied here rather than at each call
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
