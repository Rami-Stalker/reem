import { BadRequestException, Injectable } from '@nestjs/common';
import { DeliveryStatus, OrderStatus, ProductStatus } from '@prisma/client';
import { EventEmitter2 } from '@nestjs/event-emitter';
import { PrismaService } from '../../prisma/prisma.service';
import { serializeOrderDetail } from '../../common/serializers';
import { AppEvent } from '../../common/events/app-events';
import { CartService } from '../cart/cart.service';
import { CartItemRecord } from '../cart/cart.serializer';
import { DeliveryService } from '../delivery/delivery.service';
import { PaymentsService } from '../payments/payments.service';
import { CouponsService } from '../rewards/coupons.service';
import { MembershipService } from '../rewards/membership.service';
import { PointsService } from '../rewards/points.service';
import { ReferralsService } from '../rewards/referrals.service';
import { CommissionsService } from '../commissions/commissions.service';
import { OrdersRepository } from './orders.repository';
import { CreateOrderDto } from './dto/create-order.dto';

const round = (n: number) => Math.round(n * 100) / 100;

@Injectable()
export class CheckoutService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly cart: CartService,
    private readonly payments: PaymentsService,
    private readonly delivery: DeliveryService,
    private readonly coupons: CouponsService,
    private readonly points: PointsService,
    private readonly membership: MembershipService,
    private readonly referrals: ReferralsService,
    private readonly commissions: CommissionsService,
    private readonly events: EventEmitter2,
    private readonly ordersRepo: OrdersRepository,
  ) {}

  async checkout(userId: string, dto: CreateOrderDto) {
    const items = await this.cart.rawItems(userId);
    if (items.length === 0) {
      throw new BadRequestException('Your cart is empty');
    }

    // 1. Validate availability + compute the subtotal from authoritative prices.
    let subtotal = 0;
    const lines = items.map((item) => {
      this.assertPurchasable(item);
      const unitPrice = item.variant?.price ?? item.product.price;
      subtotal += unitPrice * item.quantity;
      return { item, unitPrice };
    });
    subtotal = round(subtotal);

    // 2. Coupon — full eligibility check via the rewards service.
    let discount = 0;
    let couponCode: string | null = null;
    let couponId: string | null = null;
    if (dto.coupon_code) {
      const evaluation = await this.coupons.evaluate(
        dto.coupon_code,
        userId,
        subtotal,
      );
      discount = evaluation.discount;
      couponCode = evaluation.coupon.code;
      couponId = evaluation.coupon.id;
    }

    // 3. Delivery + totals.
    const deliveryFee = this.delivery.feeFor(dto.shipping.governorate, subtotal);
    const total = round(subtotal - discount + deliveryFee);
    const estimatedDeliveryAt = this.delivery.estimatedDeliveryAt(
      dto.shipping.governorate,
    );
    const number = `REEM-${Date.now().toString(36).toUpperCase()}${Math.floor(
      Math.random() * 900 + 100,
    )}`;

    // 4. Persist order + items, decrement stock, clear cart — atomically.
    const order = await this.prisma.$transaction(async (tx) => {
      const created = await tx.order.create({
        data: {
          number,
          userId,
          subtotal,
          discount,
          deliveryFee,
          total,
          couponCode,
          recipientName: dto.shipping.recipient_name,
          recipientPhone: dto.shipping.recipient_phone,
          governorate: dto.shipping.governorate,
          city: dto.shipping.city,
          addressLine: dto.shipping.address_line,
          landmark: dto.shipping.landmark ?? null,
          deliveryInstructions: dto.delivery_instructions ?? null,
          notes: dto.notes ?? null,
          estimatedDeliveryAt,
          items: {
            create: lines.map(({ item, unitPrice }) => ({
              productId: item.productId,
              titleSnapshot: item.product.title,
              imageSnapshot: item.product.media[0]?.url ?? null,
              variantId: item.variantId,
              variantName: item.variant?.name ?? null,
              quantity: item.quantity,
              price: unitPrice,
            })),
          },
          events: {
            create: [
              { title: 'Order created', description: `Order ${number} placed` },
            ],
          },
        },
      });

      for (const { item } of lines) {
        await tx.product.update({
          where: { id: item.productId },
          data: {
            stock: { decrement: item.quantity },
            ordersCount: { increment: item.quantity },
          },
        });
        if (item.variantId) {
          await tx.productVariant.updateMany({
            where: { id: item.variantId },
            data: { stock: { decrement: item.quantity } },
          });
        }
      }

      await tx.cartItem.deleteMany({ where: { userId } });
      return created;
    });

    // 5. Kick off payment (provider call is outside the DB transaction).
    const { redirectUrl, requiresOnlineConfirmation } =
      await this.payments.initiateForOrder(
        order.id,
        order.number,
        total,
        dto.payment_method,
      );

    // COD needs no upfront capture → confirm immediately.
    if (!requiresOnlineConfirmation) {
      await this.prisma.order.update({
        where: { id: order.id },
        data: {
          status: OrderStatus.PROCESSING,
          deliveryStatus: DeliveryStatus.CONFIRMED,
        },
      });
      await this.prisma.orderEvent.create({
        data: {
          orderId: order.id,
          title: 'Order confirmed',
          description: 'Cash on delivery — preparing your order',
        },
      });
      await this.commissions.settleOrder(order.id);
    }

    // Record coupon usage, award loyalty points, and fire the order event.
    if (couponId) {
      await this.coupons.recordRedemption(couponId, userId, order.id, discount);
    }
    await this.points.earn(userId, Math.floor(total), 'Order purchase', order.id);
    await this.membership.recordPurchase(userId, order.id, total);
    await this.referrals.qualifyReferralForOrder(userId, order.id);
    this.events.emit(AppEvent.OrderStatusChanged, {
      userId,
      orderId: order.id,
      orderNumber: order.number,
      status: requiresOnlineConfirmation ? 'pending_payment' : 'processing',
    });

    const detail = await this.ordersRepo.findDetailById(order.id);
    return {
      order: serializeOrderDetail(detail!),
      redirect_url: redirectUrl,
      requires_online_confirmation: requiresOnlineConfirmation,
    };
  }

  private assertPurchasable(item: CartItemRecord) {
    if (item.product.status !== ProductStatus.ACTIVE) {
      throw new BadRequestException(
        `${item.product.title} is no longer available`,
      );
    }
    const stock = item.variant ? item.variant.stock : item.product.stock;
    if (item.quantity > stock) {
      throw new BadRequestException(
        `Only ${stock} left of ${item.product.title}`,
      );
    }
  }
}
