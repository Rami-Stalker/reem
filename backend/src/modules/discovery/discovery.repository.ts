import { Injectable } from '@nestjs/common';
import { AiStylistFeedback, Prisma, ProductStatus } from '@prisma/client';
import { PrismaService } from '../../prisma/prisma.service';
import { categorySubtreeIds } from '../../common/catalog/category-subtree';
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
    // Same shape as the card include; only *which* offer rides on the card
    // may differ (see `sellerCardInclude`).
    include: typeof PRODUCT_CARD_INCLUDE = PRODUCT_CARD_INCLUDE,
  ): Promise<DiscoveryProduct[]> {
    return this.prisma.product.findMany({
      where,
      orderBy,
      skip,
      take,
      include,
    });
  }

  count(where: Prisma.ProductWhereInput): Promise<number> {
    return this.prisma.product.count({ where });
  }

  /** A department and everything under it. Empty for an unknown slug. */
  categorySubtree(slug: string): Promise<string[]> {
    return categorySubtreeIds(this.prisma, slug);
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

  // ── «إزالة من المختارة لكِ» ────────────────────────────────────────────
  //
  // Stored as the stylist's own `DISMISSED` signal rather than in a table of
  // its own: it is the same fact — "she was shown this and pushed it away" —
  // and the style profile already reads it as a negative weight, so a piece
  // removed here also stops pulling the stylist towards things like it.

  /** Weight the style profile gives a dismissal (see `style-preference`). */
  private static readonly DISMISS_WEIGHT = -4;

  /** Bounded: an exclusion list is a `NOT IN`, and it must stay cheap. */
  private static readonly DISMISSED_CAP = 500;

  async productExists(productId: string): Promise<boolean> {
    const row = await this.prisma.product.findUnique({
      where: { id: productId },
      select: { id: true },
    });
    return row !== null;
  }

  async dismissRecommendation(userId: string, productId: string) {
    await this.prisma.userStyleSignal.upsert({
      where: {
        userId_productId_feedback: {
          userId,
          productId,
          feedback: AiStylistFeedback.DISMISSED,
        },
      },
      create: {
        userId,
        productId,
        feedback: AiStylistFeedback.DISMISSED,
        weight: DiscoveryRepository.DISMISS_WEIGHT,
      },
      update: { weight: DiscoveryRepository.DISMISS_WEIGHT },
    });
  }

  async restoreRecommendation(userId: string, productId: string) {
    await this.prisma.userStyleSignal.deleteMany({
      where: { userId, productId, feedback: AiStylistFeedback.DISMISSED },
    });
  }

  /** What she has taken out of «مختارة لكِ», newest first. */
  async dismissedProductIds(userId: string): Promise<string[]> {
    const rows = await this.prisma.userStyleSignal.findMany({
      where: { userId, feedback: AiStylistFeedback.DISMISSED },
      select: { productId: true },
      orderBy: { createdAt: 'desc' },
      take: DiscoveryRepository.DISMISSED_CAP,
    });
    return rows.map((row) => row.productId);
  }
}

export { PRODUCT_CARD_INCLUDE };

export { PURCHASABLE_PRODUCT_WHERE };
