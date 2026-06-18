import { Injectable, NotFoundException } from '@nestjs/common';
import { Prisma, ProductStatus } from '@prisma/client';
import { PrismaService } from '../../prisma/prisma.service';
import { serializeProduct } from '../../common/serializers';

type Query = Record<string, string | undefined>;
type OrderBy = Prisma.ProductOrderByWithRelationInput[];

const productInclude = {
  seller: true,
  media: { orderBy: { sortOrder: 'asc' as const } },
  variants: { orderBy: { sortOrder: 'asc' as const } },
} satisfies Prisma.ProductInclude;

// Public browsing only ever surfaces ACTIVE, in-stock products.
const availableWhere: Prisma.ProductWhereInput = {
  status: ProductStatus.ACTIVE,
  isAvailable: true,
  stock: { gt: 0 },
};

@Injectable()
export class ProductsService {
  constructor(private readonly prisma: PrismaService) {}

  async home(viewerId?: string) {
    const [trending, newArrivals, featured, mostLoved, forYou] = await Promise.all([
      this.find({ orderBy: [{ ordersCount: 'desc' }, { viewsCount: 'desc' }], take: 12 }),
      this.find({ orderBy: [{ createdAt: 'desc' }], take: 12 }),
      this.find({ where: { ...availableWhere, isFeatured: true }, orderBy: [{ createdAt: 'desc' }], take: 12 }),
      this.find({ orderBy: [{ favoritesCount: 'desc' }, { rating: 'desc' }], take: 12 }),
      this.find({ where: { ...availableWhere, showInFeed: true }, orderBy: [{ rating: 'desc' }, { createdAt: 'desc' }], take: 12 }),
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
    return this.collection({ orderBy: [{ ordersCount: 'desc' }, { viewsCount: 'desc' }] }, viewerId);
  }

  newArrivals(viewerId?: string) {
    return this.collection({ orderBy: [{ createdAt: 'desc' }] }, viewerId);
  }

  featured(viewerId?: string) {
    return this.collection(
      { where: { ...availableWhere, isFeatured: true }, orderBy: [{ createdAt: 'desc' }] },
      viewerId,
    );
  }

  mostLoved(viewerId?: string) {
    return this.collection({ orderBy: [{ favoritesCount: 'desc' }, { createdAt: 'desc' }] }, viewerId);
  }

  topRated(viewerId?: string) {
    return this.collection({ orderBy: [{ rating: 'desc' }, { reviewsCount: 'desc' }] }, viewerId);
  }

  async list(query: Query, viewerId?: string) {
    return this.paginated(this.buildFilters(query), [{ createdAt: 'desc' }], query, viewerId);
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
            ],
          }
        : {}),
    };
    return this.paginated(where, [{ createdAt: 'desc' }], query, viewerId);
  }

  async byCategory(category: string, query: Query, viewerId: string | undefined, orderBy: OrderBy) {
    const where = { ...this.buildFilters(query), category: category.toLowerCase() };
    return this.paginated(where, orderBy, query, viewerId);
  }

  async detail(id: string, viewerId?: string) {
    const product = await this.prisma.product
      .update({ where: { id }, data: { viewsCount: { increment: 1 } }, include: productInclude })
      .catch(() => null);
    if (!product) throw new NotFoundException('Product not found');

    if (!viewerId) return serializeProduct(product, { isLiked: false });
    const favSet = await this.favoriteSet(viewerId, [product.id]);
    return serializeProduct(product, { isLiked: favSet.has(product.id) });
  }

  async recordView(id: string) {
    await this.requireProduct(id);
    await this.prisma.product.update({ where: { id }, data: { viewsCount: { increment: 1 } } });
    return { message: 'View recorded' };
  }

  async incrementOrders(id: string, amount = 1) {
    await this.requireProduct(id);
    await this.prisma.product.update({ where: { id }, data: { ordersCount: { increment: amount } } });
    return { message: 'Order count updated' };
  }

  async reduceStock(id: string, quantity: number) {
    await this.requireProduct(id);
    await this.prisma.product.update({ where: { id }, data: { stock: { decrement: quantity } } });
    return { message: 'Stock updated' };
  }

  // ── internals ──────────────────────────────────────────────────────────

  private async requireProduct(id: string) {
    const product = await this.prisma.product.findUnique({ where: { id } });
    if (!product) throw new NotFoundException('Product not found');
    return product;
  }

  private find(args: { where?: Prisma.ProductWhereInput; orderBy: OrderBy; take?: number; skip?: number }) {
    return this.prisma.product.findMany({
      where: args.where ?? availableWhere,
      orderBy: args.orderBy,
      skip: args.skip ?? 0,
      take: args.take ?? 20,
      include: productInclude,
    });
  }

  private async collection(
    args: { where?: Prisma.ProductWhereInput; orderBy: OrderBy },
    viewerId?: string,
  ) {
    const products = await this.find({ ...args, take: 20 });
    return this.serializeList(products, viewerId);
  }

  private async paginated(
    where: Prisma.ProductWhereInput,
    orderBy: OrderBy,
    query: Query,
    viewerId?: string,
  ) {
    const { page, limit, skip } = this.pagination(query);
    const [products, total] = await Promise.all([
      this.find({ where, orderBy, take: limit, skip }),
      this.prisma.product.count({ where }),
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
    products: Prisma.ProductGetPayload<{ include: typeof productInclude }>[],
    viewerId?: string,
  ) {
    if (!viewerId) return products.map((p) => serializeProduct(p, { isLiked: false }));
    const favSet = await this.favoriteSet(viewerId, products.map((p) => p.id));
    return products.map((p) => serializeProduct(p, { isLiked: favSet.has(p.id) }));
  }

  private async favoriteSet(userId: string, productIds: string[]): Promise<Set<string>> {
    if (productIds.length === 0) return new Set();
    const favorites = await this.prisma.favorite.findMany({
      where: { userId, productId: { in: productIds } },
      select: { productId: true },
    });
    return new Set(favorites.map((f) => f.productId));
  }

  private pagination(query: Query) {
    const page = Math.max(1, parseInt(query.page ?? '1', 10) || 1);
    const limit = Math.min(50, Math.max(1, parseInt(query.limit ?? '20', 10) || 20));
    return { page, limit, skip: (page - 1) * limit };
  }

  private buildFilters(query: Query): Prisma.ProductWhereInput {
    const minPrice = query.min_price ? Number(query.min_price) : undefined;
    const maxPrice = query.max_price ? Number(query.max_price) : undefined;
    const featured = query.featured === undefined ? undefined : query.featured === 'true';

    return {
      ...availableWhere,
      ...(featured !== undefined ? { isFeatured: featured } : {}),
      ...(minPrice !== undefined || maxPrice !== undefined
        ? {
            price: {
              ...(minPrice !== undefined ? { gte: minPrice } : {}),
              ...(maxPrice !== undefined ? { lte: maxPrice } : {}),
            },
          }
        : {}),
    };
  }
}
