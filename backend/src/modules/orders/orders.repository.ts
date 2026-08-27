import { Injectable } from '@nestjs/common';
import { Prisma } from '@prisma/client';
import { PrismaService } from '../../prisma/prisma.service';

const SELLER_ORDER_INCLUDE = {
  seller: true,
  items: true,
  shipment: true,
  events: { orderBy: { createdAt: 'asc' as const } },
};

export const ORDER_DETAIL_INCLUDE = {
  sellerOrders: {
    orderBy: { number: 'asc' as const },
    include: SELLER_ORDER_INCLUDE,
  },
  payment: true,
  events: { orderBy: { createdAt: 'asc' as const } },
} satisfies Prisma.OrderInclude;

export const ORDER_LIST_INCLUDE = {
  sellerOrders: { include: { items: true } },
} satisfies Prisma.OrderInclude;

@Injectable()
export class OrdersRepository {
  constructor(private readonly prisma: PrismaService) {}

  listForUser(userId: string, skip: number, take: number) {
    return this.prisma.order.findMany({
      where: { userId },
      orderBy: { createdAt: 'desc' },
      skip,
      take,
      include: ORDER_LIST_INCLUDE,
    });
  }

  countForUser(userId: string) {
    return this.prisma.order.count({ where: { userId } });
  }

  findDetail(id: string, userId: string) {
    return this.prisma.order.findFirst({
      where: { id, userId },
      include: ORDER_DETAIL_INCLUDE,
    });
  }

  findDetailById(id: string) {
    return this.prisma.order.findUnique({
      where: { id },
      include: ORDER_DETAIL_INCLUDE,
    });
  }

  /** A seller's own sub-order — never the whole parent. */
  findSellerOrder(sellerOrderId: string, sellerId: string) {
    return this.prisma.sellerOrder.findFirst({
      where: { id: sellerOrderId, sellerId },
      include: { ...SELLER_ORDER_INCLUDE, order: true },
    });
  }

  listForSeller(
    sellerId: string,
    where: Prisma.SellerOrderWhereInput,
    skip: number,
    take: number,
  ) {
    return this.prisma.sellerOrder.findMany({
      where: { sellerId, ...where },
      orderBy: { createdAt: 'desc' },
      skip,
      take,
      include: { ...SELLER_ORDER_INCLUDE, order: true },
    });
  }

  countForSeller(sellerId: string, where: Prisma.SellerOrderWhereInput) {
    return this.prisma.sellerOrder.count({ where: { sellerId, ...where } });
  }
}
