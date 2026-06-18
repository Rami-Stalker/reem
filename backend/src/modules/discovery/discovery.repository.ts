import { Injectable } from '@nestjs/common';
import { Prisma, ProductStatus } from '@prisma/client';
import { PrismaService } from '../../prisma/prisma.service';

export const DISCOVERY_INCLUDE = {
  seller: true,
  media: { orderBy: { sortOrder: 'asc' as const } },
  variants: { orderBy: { sortOrder: 'asc' as const } },
} satisfies Prisma.ProductInclude;

export type DiscoveryProduct = Prisma.ProductGetPayload<{
  include: typeof DISCOVERY_INCLUDE;
}>;

/** Only ACTIVE, in-stock products are ever discoverable. */
export const AVAILABLE_WHERE: Prisma.ProductWhereInput = {
  status: ProductStatus.ACTIVE,
  isAvailable: true,
  stock: { gt: 0 },
};

export type ProductOrderBy = Prisma.ProductOrderByWithRelationInput[];

@Injectable()
export class DiscoveryRepository {
  constructor(private readonly prisma: PrismaService) {}

  findMany(
    where: Prisma.ProductWhereInput,
    orderBy: ProductOrderBy,
    skip: number,
    take: number,
  ): Promise<DiscoveryProduct[]> {
    return this.prisma.product.findMany({
      where,
      orderBy,
      skip,
      take,
      include: DISCOVERY_INCLUDE,
    });
  }

  count(where: Prisma.ProductWhereInput): Promise<number> {
    return this.prisma.product.count({ where });
  }

  async categoryOf(productId: string): Promise<string | null> {
    const product = await this.prisma.product.findUnique({
      where: { id: productId },
      select: { category: true },
    });
    return product?.category ?? null;
  }

  async favoriteSet(
    userId: string,
    productIds: string[],
  ): Promise<Set<string>> {
    if (productIds.length === 0) return new Set();
    const favorites = await this.prisma.favorite.findMany({
      where: { userId, productId: { in: productIds } },
      select: { productId: true },
    });
    return new Set(favorites.map((f) => f.productId));
  }

  /** Categories the user engages with most (favourites), for recommendations. */
  async preferredCategories(userId: string, limit = 3): Promise<string[]> {
    const favorites = await this.prisma.favorite.findMany({
      where: { userId },
      select: { product: { select: { category: true } } },
      take: 50,
    });
    const counts = new Map<string, number>();
    for (const f of favorites) {
      const c = f.product.category;
      counts.set(c, (counts.get(c) ?? 0) + 1);
    }
    return [...counts.entries()]
      .sort((a, b) => b[1] - a[1])
      .slice(0, limit)
      .map(([category]) => category);
  }
}
