import { Injectable } from '@nestjs/common';
import { Prisma } from '@prisma/client';
import { PrismaService } from '../../prisma/prisma.service';

export const ORDER_DETAIL_INCLUDE = {
  items: true,
  payment: true,
  events: { orderBy: { createdAt: 'asc' as const } },
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
      include: { items: true },
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
}
