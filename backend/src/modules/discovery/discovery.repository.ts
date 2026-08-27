import { Injectable } from '@nestjs/common';
import { Prisma, ProductStatus } from '@prisma/client';
import { PrismaService } from '../../prisma/prisma.service';
import {
  PRODUCT_CARD_INCLUDE,
  PURCHASABLE_PRODUCT_WHERE,
} from '../../common/catalog/product-include';

export type DiscoveryProduct = Prisma.ProductGetPayload<{
  include: typeof PRODUCT_CARD_INCLUDE;
}>;

/** Only ACTIVE, in-stock products are ever discoverable. */

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
      include: PRODUCT_CARD_INCLUDE,
    });
  }

  count(where: Prisma.ProductWhereInput): Promise<number> {
    return this.prisma.product.count({ where });
  }

  /** The product's leaf category slug — the key discovery rails group by. */
  async categoryOf(productId: string): Promise<string | null> {
    const product = await this.prisma.product.findUnique({
      where: { id: productId },
      select: { category: { select: { slug: true } } },
    });
    return product?.category.slug ?? null;
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
      select: { product: { select: { category: { select: { slug: true } } } } },
      take: 50,
    });
    const counts = new Map<string, number>();
    for (const favorite of favorites) {
      if (!favorite.product) continue;
      const slug = favorite.product.category.slug;
      counts.set(slug, (counts.get(slug) ?? 0) + 1);
    }
    return [...counts.entries()]
      .sort((a, b) => b[1] - a[1])
      .slice(0, limit)
      .map(([category]) => category);
  }
}

export { PRODUCT_CARD_INCLUDE };

export { PURCHASABLE_PRODUCT_WHERE };
