import { Injectable } from '@nestjs/common';
import { Prisma, User } from '@prisma/client';
import { PrismaService } from '../../prisma/prisma.service';
import { Money, REVENUE_STATUSES } from '../../common/money';

@Injectable()
export class UsersRepository {
  constructor(private readonly prisma: PrismaService) {}

  findById(id: string): Promise<User | null> {
    return this.prisma.user.findUnique({ where: { id } });
  }

  update(id: string, data: Prisma.UserUpdateInput): Promise<User> {
    return this.prisma.user.update({ where: { id }, data });
  }

  /** A seller's catalog size is their live offer count. */
  countProducts(sellerId: string): Promise<number> {
    return this.prisma.sellerOffer.count({ where: { sellerId } });
  }

  /**
   * The number under «منشورات» on her profile.
   *
   * Published social formats only — a draft, a scheduled piece or something
   * taken down is not something a visitor can open, and a count that does not
   * match the grid beneath it reads as a bug.
   */
  countPosts(authorId: string): Promise<number> {
    return this.prisma.commerceContent.count({
      where: {
        authorId,
        contentType: { in: ['product_post', 'reel'] },
        status: 'PUBLISHED',
      },
    });
  }

  /**
   * The pieces on her page a viewer may see — none, to a stranger, while a
   * customer's page is closed. Mirrors `ProductSocialService.picksOf`.
   */
  countVisiblePicks(owner: User, viewerId?: string): Promise<number> {
    if (
      owner.role === 'CUSTOMER' &&
      !owner.profileIsPublic &&
      owner.id !== viewerId
    ) {
      return Promise.resolve(0);
    }
    return this.prisma.productPick.count({
      where: {
        userId: owner.id,
        product: { status: { in: ['ACTIVE', 'OUT_OF_STOCK'] } },
      },
    });
  }

  /** Whether she has a live story this viewer may watch. */
  async hasVisibleStory(owner: User, viewerId?: string): Promise<boolean> {
    const isOwner = owner.id === viewerId;
    const story = await this.prisma.commerceContent.findFirst({
      where: {
        authorId: owner.id,
        contentType: 'story',
        status: 'PUBLISHED',
        moderationStatus: { not: 'REJECTED' },
        expiresAt: { gt: new Date() },
        ...(isOwner
          ? {}
          : {
              authorIsPublic: true,
              OR: [
                { visibility: 'PUBLIC' },
                ...(viewerId
                  ? [
                      {
                        visibility: 'FOLLOWERS' as const,
                        author: { followers: { some: { followerId: viewerId } } },
                      },
                    ]
                  : []),
              ],
            }),
      },
      select: { id: true },
    });
    return story !== null;
  }

  findFollow(followerId: string, followingId: string) {
    return this.prisma.follow.findUnique({
      where: { followerId_followingId: { followerId, followingId } },
    });
  }

  listFollowers(userId: string): Promise<User[]> {
    return this.prisma.user.findMany({
      where: { following: { some: { followingId: userId } } },
      orderBy: { createdAt: 'desc' },
      take: 100,
    });
  }

  listFollowing(userId: string): Promise<User[]> {
    return this.prisma.user.findMany({
      where: { followers: { some: { followerId: userId } } },
      orderBy: { createdAt: 'desc' },
      take: 100,
    });
  }

  /**
   * Seller sales and rating.
   *
   * The old version reduced over EVERY order item with no status filter at
   * all, so cancelled and unpaid orders counted as sales. Revenue now comes
   * from revenue-bearing sub-orders only, and stays inside its currency.
   */
  async sellerStats(sellerId: string) {
    const [productsCount, ratingAgg, revenueRows, ordersCount] =
      await Promise.all([
        this.prisma.sellerOffer.count({ where: { sellerId } }),
        this.prisma.product.aggregate({
          _avg: { rating: true },
          where: { offers: { some: { sellerId } } },
        }),
        this.prisma.sellerOrder.groupBy({
          by: ['currency'],
          where: { sellerId, status: { in: [...REVENUE_STATUSES] } },
          _sum: { itemsSubtotal: true },
        }),
        this.prisma.sellerOrder.count({
          where: { sellerId, status: { in: [...REVENUE_STATUSES] } },
        }),
      ]);

    return {
      productsCount,
      ordersCount,
      totalSales: revenueRows.map((row) =>
        Money.of(row._sum.itemsSubtotal ?? 0, row.currency).toJSON(),
      ),
      averageRating: Math.round((ratingAgg._avg.rating ?? 0) * 10) / 10,
    };
  }
}
