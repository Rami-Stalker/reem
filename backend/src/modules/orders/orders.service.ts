import {
  BadRequestException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { DeliveryStatus, OrderStatus, PaymentStatus } from '@prisma/client';
import { PrismaService } from '../../prisma/prisma.service';
import { buildMeta, PaginationDto } from '../../common/dto/pagination.dto';
import {
  serializeOrder,
  serializeOrderDetail,
  serializeOrderEvent,
} from '../../common/serializers';
import { OrdersRepository } from './orders.repository';
import { CartService } from '../cart/cart.service';
import { CommissionsService } from '../commissions/commissions.service';

const CANCELLABLE: OrderStatus[] = [
  OrderStatus.PENDING_PAYMENT,
  OrderStatus.PAID,
  OrderStatus.PROCESSING,
];

@Injectable()
export class OrdersService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly repo: OrdersRepository,
    private readonly cart: CartService,
    private readonly commissions: CommissionsService,
  ) {}

  async list(userId: string, page: PaginationDto) {
    const [orders, total] = await Promise.all([
      this.repo.listForUser(userId, page.skip, page.limit),
      this.repo.countForUser(userId),
    ]);
    return {
      data: orders.map(serializeOrder),
      pagination: buildMeta(page.page, page.limit, total, orders.length),
    };
  }

  async detail(userId: string, id: string) {
    return serializeOrderDetail(await this.requireOrder(userId, id));
  }

  async timeline(userId: string, id: string) {
    const order = await this.requireOrder(userId, id);
    return order.events.map(serializeOrderEvent);
  }

  async cancel(userId: string, id: string) {
    const order = await this.requireOrder(userId, id);
    if (!CANCELLABLE.includes(order.status)) {
      throw new BadRequestException('This order can no longer be cancelled');
    }

    const wasPaid =
      order.status === OrderStatus.PAID ||
      order.payment?.status === PaymentStatus.PAID;

    await this.prisma.$transaction(async (tx) => {
      // Return reserved stock.
      for (const item of order.items) {
        await tx.product.update({
          where: { id: item.productId },
          data: { stock: { increment: item.quantity } },
        });
        if (item.variantId) {
          await tx.productVariant.updateMany({
            where: { id: item.variantId },
            data: { stock: { increment: item.quantity } },
          });
        }
      }

      await tx.order.update({
        where: { id },
        data: {
          status: wasPaid ? OrderStatus.REFUNDED : OrderStatus.CANCELLED,
          deliveryStatus: DeliveryStatus.CANCELLED,
        },
      });
      if (order.payment && wasPaid) {
        await tx.payment.update({
          where: { id: order.payment.id },
          data: { status: PaymentStatus.REFUNDED },
        });
      }
      await tx.orderEvent.create({
        data: {
          orderId: id,
          title: wasPaid ? 'Order refunded' : 'Order cancelled',
          description: wasPaid
            ? 'A refund has been issued for this order'
            : 'Order cancelled by customer',
        },
      });
    });

    if (wasPaid) {
      await this.commissions.reverseOrder(id, 'Order cancelled or refunded');
    }

    return this.detail(userId, id);
  }

  async reorder(userId: string, id: string) {
    const order = await this.requireOrder(userId, id);
    for (const item of order.items) {
      try {
        await this.cart.addItem(userId, {
          product_id: item.productId,
          variant_id: item.variantId ?? undefined,
          quantity: item.quantity,
        });
      } catch {
        // Skip items that are no longer purchasable.
      }
    }
    return this.cart.getCart(userId);
  }

  private async requireOrder(userId: string, id: string) {
    const order = await this.repo.findDetail(id, userId);
    if (!order) throw new NotFoundException('Order not found');
    return order;
  }
}
