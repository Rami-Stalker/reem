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
