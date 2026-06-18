import { Injectable } from '@nestjs/common';
import { Prisma } from '@prisma/client';
import { PrismaService } from '../../prisma/prisma.service';

export const CART_INCLUDE = {
  product: { include: { media: { orderBy: { sortOrder: 'asc' as const } } } },
  variant: true,
} satisfies Prisma.CartItemInclude;

@Injectable()
export class CartRepository {
  constructor(private readonly prisma: PrismaService) {}

  findItems(userId: string) {
    return this.prisma.cartItem.findMany({
      where: { userId },
      include: CART_INCLUDE,
      orderBy: { createdAt: 'desc' },
    });
  }

  findItem(id: string, userId: string) {
    return this.prisma.cartItem.findFirst({
      where: { id, userId },
      include: CART_INCLUDE,
    });
  }

  findExisting(userId: string, productId: string, variantId: string | null) {
    return this.prisma.cartItem.findFirst({
      where: { userId, productId, variantId },
    });
  }

  create(data: Prisma.CartItemCreateInput) {
    return this.prisma.cartItem.create({ data });
  }

  updateQuantity(id: string, quantity: number) {
    return this.prisma.cartItem.update({ where: { id }, data: { quantity } });
  }

  delete(id: string) {
    return this.prisma.cartItem.delete({ where: { id } });
  }

  clear(userId: string) {
    return this.prisma.cartItem.deleteMany({ where: { userId } });
  }
}
