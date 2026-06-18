import { Injectable } from '@nestjs/common';
import { Prisma, ProductStatus, UserRole } from '@prisma/client';
import { PrismaService } from '../../prisma/prisma.service';
import { buildMeta, PaginationDto } from '../../common/dto/pagination.dto';
import {
  serializePost,
  serializeProduct,
  serializeUser,
} from '../../common/serializers';
import { ProductSearchDto, SearchSort } from './dto/search-query.dto';

const productInclude = {
  seller: true,
  media: { orderBy: { sortOrder: 'asc' as const } },
} satisfies Prisma.ProductInclude;

const activeWhere: Prisma.ProductWhereInput = {
  status: ProductStatus.ACTIVE,
  isAvailable: true,
  stock: { gt: 0 },
};

/** Matches no user — keeps personalised includes static for anonymous viewers. */
const NIL_UUID = '00000000-0000-0000-0000-000000000000';

const TRENDING_FALLBACK = [
  'dresses',
  'perfume',
  'handbags',
  'heels',
  'gifts',
  'makeup',
];

@Injectable()
export class SearchService {
  constructor(private readonly prisma: PrismaService) {}

  // ── Products ─────────────────────────────────────────────────────────────

  async searchProducts(dto: ProductSearchDto, viewerId?: string) {
    const where = this.buildProductWhere(dto);
    const [products, total] = await Promise.all([
      this.prisma.product.findMany({
        where,
        orderBy: this.sortBy(dto.sort),
        skip: dto.skip,
        take: dto.limit,
        include: productInclude,
      }),
      this.prisma.product.count({ where }),
    ]);

    this.recordHistory(viewerId, dto.q);
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
      this.prisma.post.findMany({
        where,
        orderBy: { createdAt: 'desc' },
        skip: page.skip,
        take: page.limit,
        include: {
          author: true,
          product: { include: productInclude },
          likes: { where: { userId: viewerId ?? NIL_UUID } },
          saves: { where: { userId: viewerId ?? NIL_UUID } },
        },
      }),
      this.prisma.post.count({ where }),
    ]);
    return {
      data: posts.map((p) => serializePost(p, viewerId)),
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
        include: productInclude,
      }),
      this.prisma.user.findMany({
        where: this.sellerWhere(q),
        orderBy: { followersCount: 'desc' },
        take: 6,
      }),
      this.prisma.post.findMany({
        where: this.postWhere(q),
        orderBy: { createdAt: 'desc' },
        take: 6,
        include: { author: true, product: { include: productInclude } },
      }),
    ]);

    this.recordHistory(viewerId, q);
    const favSet = await this.favoriteSet(viewerId, products.map((p) => p.id));

    return {
      products: products.map((p) =>
        serializeProduct(p, { isLiked: favSet.has(p.id) }),
      ),
      sellers: sellers.map(serializeUser),
      posts: posts.map((p) => serializePost(p, viewerId)),
    };
  }

  // ── Suggestions / trending / history ─────────────────────────────────────

  async suggestions(q: string | undefined) {
    const query = (q ?? '').trim();
    if (query.length < 1) return { products: [], categories: [] };

    const [products, categories] = await Promise.all([
      this.prisma.product.findMany({
        where: { ...activeWhere, title: { contains: query, mode: 'insensitive' } },
        select: { title: true },
        take: 8,
      }),
      this.prisma.product.findMany({
        where: {
          ...activeWhere,
          category: { contains: query, mode: 'insensitive' },
        },
        select: { category: true },
        distinct: ['category'],
        take: 5,
      }),
    ]);

    return {
      products: products.map((p) => p.title),
      categories: categories.map((c) => c.category),
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
      ...activeWhere,
      ...(q
        ? {
            OR: [
              { title: { contains: q, mode: 'insensitive' } },
              { description: { contains: q, mode: 'insensitive' } },
            ],
          }
        : {}),
      ...(dto.category ? { category: dto.category.toLowerCase() } : {}),
      ...(dto.seller_id ? { sellerId: dto.seller_id } : {}),
      ...(dto.rating ? { rating: { gte: dto.rating } } : {}),
      ...(dto.min_price !== undefined || dto.max_price !== undefined
        ? {
            price: {
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

  private postWhere(q: string | undefined): Prisma.PostWhereInput {
    const query = q?.trim();
    if (!query) return {};
    return {
      OR: [
        { caption: { contains: query, mode: 'insensitive' } },
        { product: { title: { contains: query, mode: 'insensitive' } } },
      ],
    };
  }

  private sortBy(sort?: SearchSort): Prisma.ProductOrderByWithRelationInput[] {
    switch (sort) {
      case 'price_asc':
        return [{ price: 'asc' }];
      case 'price_desc':
        return [{ price: 'desc' }];
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
