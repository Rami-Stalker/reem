import { Injectable } from '@nestjs/common';
import { Prisma, User } from '@prisma/client';
import { PrismaService } from '../../prisma/prisma.service';

@Injectable()
export class UsersRepository {
  constructor(private readonly prisma: PrismaService) {}

  findById(id: string): Promise<User | null> {
    return this.prisma.user.findUnique({ where: { id } });
  }

  update(id: string, data: Prisma.UserUpdateInput): Promise<User> {
    return this.prisma.user.update({ where: { id }, data });
  }

  countProducts(sellerId: string): Promise<number> {
    return this.prisma.product.count({ where: { sellerId } });
  }

  countPosts(authorId: string): Promise<number> {
    return this.prisma.post.count({ where: { authorId } });
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

  /** Aggregate sales/rating for a seller from their products & order items. */
  async sellerStats(sellerId: string) {
    const [productsCount, ratingAgg, items] = await Promise.all([
      this.prisma.product.count({ where: { sellerId } }),
      this.prisma.product.aggregate({
        _avg: { rating: true },
        where: { sellerId },
      }),
      this.prisma.orderItem.findMany({
        where: { product: { sellerId } },
        select: { price: true, quantity: true },
      }),
    ]);

    const totalSales = items.reduce((sum, i) => sum + i.price * i.quantity, 0);

    return {
      productsCount,
      ordersCount: items.length,
      totalSales: Math.round(totalSales * 100) / 100,
      averageRating: Math.round((ratingAgg._avg.rating ?? 0) * 10) / 10,
    };
  }
}
