import { Injectable } from '@nestjs/common';
import { Prisma, ProductStatus, UserRole } from '@prisma/client';
import { PrismaService } from '../../prisma/prisma.service';
import { TrendSignalService } from '../trends/collection/trend-signal.service';
import { buildMeta, PaginationDto } from '../../common/dto/pagination.dto';
import {
  serializeLegacyPost,
  serializeProduct,
  serializeUser,
} from '../../common/serializers';
import { ProductSearchDto, SearchSort } from './dto/search-query.dto';
import {
  PRODUCT_CARD_INCLUDE,
  LIVE_OFFER_WHERE,
  PURCHASABLE_PRODUCT_WHERE,
} from '../../common/catalog/product-include';

/** Matches no user — keeps personalised includes static for anonymous viewers. */
const NIL_UUID = '00000000-0000-0000-0000-000000000000';

/**
 * What the search screen offers before anyone has searched anything.
 *
 * In Arabic, because the catalogue is: these are run as real queries against
 * `title`, `description` and brand, and the English list that used to sit here
 * — dresses, perfume, handbags, heels, gifts, makeup — matched not one product
 * in the shop. Every chip on the customer's search screen opened an empty
 * result page. Each term below is one a listing actually contains.
 */
const TRENDING_FALLBACK = [
  'فستان',
  'عطر',
  'حقيبة',
  'حذاء',
  'هدية',
  'ورد',
];

@Injectable()
export class SearchService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly signals: TrendSignalService,
  ) {}

  // ── Products ─────────────────────────────────────────────────────────────

  async searchProducts(dto: ProductSearchDto, viewerId?: string) {
    const where = this.buildProductWhere(dto);
    const [products, total] = await Promise.all([
      this.prisma.product.findMany({
        where,
        orderBy: this.sortBy(dto.sort),
        skip: dto.skip,
        take: dto.limit,
        include: PRODUCT_CARD_INCLUDE,
      }),
      this.prisma.product.count({ where }),
    ]);

    this.recordHistory(viewerId, dto.q);
    // Search Intelligence: the query, how many rows answered it, and which
    // products were on the page. A search that returns nothing is the clearest
    // purchase intent this platform ever sees, and until now it left no trace.
    this.signals.recordSearch({
      query: dto.q,
      resultCount: total,
      productIds: products.map((p) => p.id),
      userId: viewerId ?? null,
      source: 'search.products',
    });
    const favSet = await this.favoriteSet(viewerId, products.map((p) => p.id));

    return {
      data: products.map((p) =>
        serializeProduct(p, { isLiked: favSet.has(p.id) }),
      ),
      pagination: buildMeta(dto.page, dto.limit, total, products.length),
    };
  }

  // ── Sellers ──────────────────────────────────────────────────────────────

  async searchSellers(q: string | undefined, page: PaginationDto) {
    const where = this.sellerWhere(q);
    const [sellers, total] = await Promise.all([
      this.prisma.user.findMany({
        where,
        orderBy: { followersCount: 'desc' },
        skip: page.skip,
        take: page.limit,
      }),
      this.prisma.user.count({ where }),
    ]);
    return {
      data: sellers.map(serializeUser),
      pagination: buildMeta(page.page, page.limit, total, sellers.length),
    };
  }

  // ── Posts ────────────────────────────────────────────────────────────────

  async searchPosts(q: string | undefined, viewerId: string | undefined, page: PaginationDto) {
    const where = this.postWhere(q);
    const [posts, total] = await Promise.all([
      this.prisma.commerceContent.findMany({
        where,
        orderBy: { createdAt: 'desc' },
        skip: page.skip,
        take: page.limit,
        include: {
          author: true,
          productTags: {
            orderBy: { sortOrder: 'asc' },
            include: { product: { include: PRODUCT_CARD_INCLUDE } },
          },
          reactions: { where: { userId: viewerId ?? NIL_UUID } },
          saves: { where: { userId: viewerId ?? NIL_UUID } },
        },
      }),
      this.prisma.commerceContent.count({ where }),
    ]);
    return {
      data: posts.map((post) =>
        serializeLegacyPost(post, {
          liked: new Set(post.reactions.map((r) => r.contentId)),
          saved: new Set(post.saves.map((s) => s.contentId)),
          viewed: new Set(),
          reactions: new Map(),
        }),
      ),
      pagination: buildMeta(page.page, page.limit, total, posts.length),
    };
  }

  // ── Unified (top hits per type) ──────────────────────────────────────────

  async unified(q: string | undefined, viewerId?: string) {
    const [products, sellers, posts] = await Promise.all([
      this.prisma.product.findMany({
        where: this.buildProductWhere({ q } as ProductSearchDto),
        orderBy: [{ ordersCount: 'desc' }, { createdAt: 'desc' }],
        take: 8,
        include: PRODUCT_CARD_INCLUDE,
      }),
      this.prisma.user.findMany({
        where: this.sellerWhere(q),
        orderBy: { followersCount: 'desc' },
        take: 6,
      }),
      this.prisma.commerceContent.findMany({
        where: this.postWhere(q),
        orderBy: { createdAt: 'desc' },
        take: 6,
        include: {
          author: true,
          productTags: {
            orderBy: { sortOrder: 'asc' },
            include: { product: { include: PRODUCT_CARD_INCLUDE } },
          },
        },
      }),
    ]);

    this.recordHistory(viewerId, q);
    this.signals.recordSearch({
      query: q,
      // The unified search caps at eight products, so its own count is the
      // honest answer to "did the catalogue have anything", not to "how many".
      resultCount: products.length,
      productIds: products.map((p) => p.id),
      userId: viewerId ?? null,
      source: 'search.unified',
    });
    const favSet = await this.favoriteSet(viewerId, products.map((p) => p.id));

    return {
      products: products.map((p) =>
        serializeProduct(p, { isLiked: favSet.has(p.id) }),
      ),
      sellers: sellers.map(serializeUser),
      posts: posts.map((post) => serializeLegacyPost(post)),
    };
  }

  // ── Suggestions / trending / history ─────────────────────────────────────

  async suggestions(q: string | undefined) {
    const query = (q ?? '').trim();
    if (query.length < 1) return { products: [], categories: [] };

    const [products, categories] = await Promise.all([
      this.prisma.product.findMany({
        where: {
          ...PURCHASABLE_PRODUCT_WHERE,
          title: { contains: query, mode: 'insensitive' },
        },
        select: { title: true },
        take: 8,
      }),
      // Suggestions come from the taxonomy itself now, in Arabic, rather than
      // from DISTINCT over a free-text column.
      this.prisma.category.findMany({
        where: {
          isActive: true,
          OR: [
            { nameAr: { contains: query, mode: 'insensitive' } },
            { nameEn: { contains: query, mode: 'insensitive' } },
            { slug: { contains: query, mode: 'insensitive' } },
          ],
        },
        select: { slug: true, nameAr: true },
        take: 5,
      }),
    ]);

    return {
      products: products.map((product) => product.title),
      categories: categories.map((category) => ({
        slug: category.slug,
        name: category.nameAr,
      })),
    };
  }

  async trending() {
    const since = new Date(Date.now() - 7 * 24 * 60 * 60 * 1000);
    const rows = await this.prisma.searchHistory.groupBy({
      by: ['query'],
      where: { createdAt: { gte: since } },
      _count: { query: true },
      orderBy: { _count: { query: 'desc' } },
      take: 10,
    });
    const fromHistory = rows.map((r) => r.query);
    return [...new Set([...fromHistory, ...TRENDING_FALLBACK])].slice(0, 10);
  }

  async recent(userId: string) {
    const rows = await this.prisma.searchHistory.findMany({
      where: { userId },
      orderBy: { createdAt: 'desc' },
      take: 40,
    });
    const seen = new Set<string>();
    const result: { id: string; query: string; created_at: string }[] = [];
    for (const r of rows) {
      const key = r.query.toLowerCase();
      if (seen.has(key)) continue;
      seen.add(key);
      result.push({
        id: r.id,
        query: r.query,
        created_at: r.createdAt.toISOString(),
      });
      if (result.length >= 10) break;
    }
    return result;
  }

  async clearRecent(userId: string) {
    await this.prisma.searchHistory.deleteMany({ where: { userId } });
    return { message: 'Search history cleared' };
  }

  async removeRecent(userId: string, id: string) {
    await this.prisma.searchHistory.deleteMany({ where: { id, userId } });
    return { message: 'Removed from history' };
  }

  // ── helpers ──────────────────────────────────────────────────────────────

  private buildProductWhere(dto: ProductSearchDto): Prisma.ProductWhereInput {
    const q = dto.q?.trim();
    return {
      ...PURCHASABLE_PRODUCT_WHERE,
      ...(q
        ? {
            OR: [
              { title: { contains: q, mode: 'insensitive' } },
              { description: { contains: q, mode: 'insensitive' } },
            ],
          }
        : {}),
      ...(dto.category
        ? { category: { slug: dto.category.toLowerCase() } }
        : {}),
      // "Products this seller sells" is an offer filter now.
      ...(dto.seller_id
        ? { offers: { some: { ...LIVE_OFFER_WHERE, sellerId: dto.seller_id } } }
        : {}),
      ...(dto.rating ? { rating: { gte: dto.rating } } : {}),
      // Price filters run against the SYP-normalised roll-up.
      ...(dto.min_price !== undefined || dto.max_price !== undefined
        ? {
            minPriceSyp: {
              ...(dto.min_price !== undefined ? { gte: dto.min_price } : {}),
              ...(dto.max_price !== undefined ? { lte: dto.max_price } : {}),
            },
          }
        : {}),
    };
  }

  private sellerWhere(q: string | undefined): Prisma.UserWhereInput {
    const query = q?.trim();
    return {
      role: UserRole.SELLER,
      ...(query
        ? {
            OR: [
              { name: { contains: query, mode: 'insensitive' } },
              { username: { contains: query, mode: 'insensitive' } },
            ],
          }
        : {}),
    };
  }

  /**
   * Searchable social content.
   *
   * Posts and reels, never stories: a story is gone in a day, and a search
   * result that 404s by tomorrow afternoon is worse than no result.
   */
  private postWhere(q: string | undefined): Prisma.CommerceContentWhereInput {
    const base: Prisma.CommerceContentWhereInput = {
      contentType: { in: ['product_post', 'reel'] },
      status: 'PUBLISHED',
      visibility: 'PUBLIC',
      authorIsPublic: true,
    };
    const query = q?.trim();
    if (!query) return base;
    return {
      ...base,
      OR: [
        { body: { contains: query, mode: 'insensitive' } },
        { title: { contains: query, mode: 'insensitive' } },
        {
          productTags: {
            some: {
              product: { title: { contains: query, mode: 'insensitive' } },
            },
          },
        },
      ],
    };
  }

  private sortBy(sort?: SearchSort): Prisma.ProductOrderByWithRelationInput[] {
    switch (sort) {
      // Price sorting runs off the SYP-normalised roll-up so offers priced
      // in different currencies interleave correctly.
      case 'price_asc':
        return [{ minPriceSyp: 'asc' }];
      case 'price_desc':
        return [{ minPriceSyp: 'desc' }];
      case 'best_selling':
        return [{ ordersCount: 'desc' }];
      case 'rating':
        return [{ rating: 'desc' }, { reviewsCount: 'desc' }];
      case 'popular':
        return [{ viewsCount: 'desc' }, { favoritesCount: 'desc' }];
      case 'newest':
      default:
        return [{ createdAt: 'desc' }];
    }
  }

  private async favoriteSet(
    userId: string | undefined,
    productIds: string[],
  ): Promise<Set<string>> {
    if (!userId || productIds.length === 0) return new Set();
    const favorites = await this.prisma.favorite.findMany({
      where: { userId, productId: { in: productIds } },
      select: { productId: true },
    });
    return new Set(favorites.map((f) => f.productId));
  }

  /** Fire-and-forget search logging for trending/recent analytics. */
  private recordHistory(userId: string | undefined, q: string | undefined) {
    const query = q?.trim();
    if (!userId || !query || query.length < 2) return;
    void this.prisma.searchHistory
      .create({ data: { userId, query } })
      .catch(() => undefined);
  }
}
