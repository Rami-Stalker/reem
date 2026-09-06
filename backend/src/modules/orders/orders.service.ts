import {
  BadRequestException,
  Injectable,
  Logger,
  NotFoundException,
} from '@nestjs/common';
import {
  OrderStatus,
  PaymentStatus,
  Prisma,
  SellerOrderStatus,
} from '@prisma/client';
import { PrismaService } from '../../prisma/prisma.service';
import { buildMeta, PaginationDto } from '../../common/dto/pagination.dto';
import {
  serializeOrder,
  serializeOrderDetail,
  serializeOrderEvent,
} from '../../common/serializers';
import { CUSTOMER_CANCELLABLE, canTransition } from '../../common/money';
import { OrdersRepository } from './orders.repository';
import { CartService } from '../cart/cart.service';
import { CustomerRefundsService } from '../finance/customer-refunds.service';
import { CodTrustService } from '../cod-trust/cod-trust.service';
import { SellerOrderWorkflowService } from './workflow/seller-order-workflow.service';

/**
 * The four piles a customer thinks in — and the only definition of them.
 *
 * `ProfileOverviewService` counts orders into these same buckets for the
 * profile screen; both read this table so a tile's number and the list behind
 * it can never mean different things.
 */
export const ORDER_BUCKETS = {
  pending: [OrderStatus.PENDING_PAYMENT, OrderStatus.CONFIRMED],
  processing: [
    OrderStatus.PARTIALLY_SHIPPED,
    OrderStatus.SHIPPED,
    OrderStatus.PARTIALLY_DELIVERED,
  ],
  delivered: [OrderStatus.DELIVERED, OrderStatus.CLOSED],
  cancelled: [OrderStatus.CANCELLED, OrderStatus.PARTIALLY_CANCELLED],
} as const satisfies Record<string, readonly OrderStatus[]>;

export type OrderBucket = keyof typeof ORDER_BUCKETS;

export function isOrderBucket(value: string): value is OrderBucket {
  return Object.prototype.hasOwnProperty.call(ORDER_BUCKETS, value);
}

/**
 * The customer's view of their orders.
 *
 * Cancellation is now per sub-order: a basket split across three sellers can
 * have one seller's parcel cancelled while the other two ship. The parent's
 * status is re-derived from its children rather than set directly, which is
 * what makes "partially cancelled" representable at all.
 */
@Injectable()
export class OrdersService {
  private readonly logger = new Logger(OrdersService.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly repo: OrdersRepository,
    private readonly cart: CartService,
    private readonly workflow: SellerOrderWorkflowService,
    private readonly refunds: CustomerRefundsService,
    private readonly codTrust: CodTrustService,
  ) {}

  /**
   * Her orders, optionally narrowed to one of the four piles her profile
   * counts.
   *
   * The profile screen has shown those four counts since it was built and
   * every tile opened the same unfiltered list — tapping «ملغاة» gave her
   * everything she had ever bought. The buckets are defined once, in
   * `ORDER_BUCKETS`, so the count and the list can never disagree about what
   * "processing" means.
   */
  async list(userId: string, page: PaginationDto, bucket?: OrderBucket) {
    const statuses = bucket ? [...ORDER_BUCKETS[bucket]] : undefined;
    const [orders, total] = await Promise.all([
      this.repo.listForUser(userId, page.skip, page.limit, statuses),
      this.repo.countForUser(userId, statuses),
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
    const events = [
      ...order.events,
      ...order.sellerOrders.flatMap((sellerOrder) => sellerOrder.events ?? []),
    ].sort((a, b) => a.createdAt.getTime() - b.createdAt.getTime());
    return events.map(serializeOrderEvent);
  }

  /** Cancels every sub-order that is still cancellable. */
  async cancel(userId: string, id: string, reason?: string) {
    const order = await this.requireOrder(userId, id);

    const cancellable = order.sellerOrders.filter((sellerOrder) =>
      CUSTOMER_CANCELLABLE.includes(sellerOrder.status),
    );
    if (cancellable.length === 0) {
      throw new BadRequestException('This order can no longer be cancelled');
    }

    for (const sellerOrder of cancellable) {
      await this.cancelSellerOrder(userId, sellerOrder.id, reason);
    }

    // A basket she called off before it moved is not a refusal, and a trust
    // engine that never learned the difference would read every change of mind
    // as a parcel sent back at the door.
    await this.codTrust.observe(id, 'cancelled');

    return this.detail(userId, id);
  }

  /**
   * Cancels one seller's parcel: returns its stock, records the transition and
   * re-derives the parent status.
   *
   * A paid parcel walks two steps rather than one — cancelled, then awaiting
   * its refund. The old code asserted the first transition and then wrote the
   * second status, which meant the timeline showed a jump nobody had checked
   * was legal and `REFUND_PENDING` appeared with no cancellation behind it.
   */
  async cancelSellerOrder(userId: string, sellerOrderId: string, reason?: string) {
    const sellerOrder = await this.prisma.sellerOrder.findFirst({
      where: { id: sellerOrderId, order: { userId } },
      include: { items: true, order: { include: { payment: true } } },
    });
    if (!sellerOrder) throw new NotFoundException('Order not found');

    if (
      !canTransition(
        sellerOrder.status,
        SellerOrderStatus.CANCELLED_BY_CUSTOMER,
        'CUSTOMER',
      )
    ) {
      throw new BadRequestException('This order can no longer be cancelled');
    }

    const wasPaid = sellerOrder.order.payment?.status === PaymentStatus.PAID;

    await this.prisma.$transaction(async (tx) => {
      // Put the reserved stock back on the OFFER it came off.
      for (const item of sellerOrder.items) {
        if (item.offerId) {
          await tx.sellerOffer.update({
            where: { id: item.offerId },
            data: { stock: { increment: item.quantity } },
          });
        }
        if (item.offerId && item.variantId) {
          await tx.sellerOfferVariant.updateMany({
            where: { offerId: item.offerId, variantId: item.variantId },
            data: { stock: { increment: item.quantity } },
          });
        }
      }

      await this.workflow.move(
        tx,
        sellerOrderId,
        SellerOrderStatus.CANCELLED_BY_CUSTOMER,
        { id: userId, role: 'CUSTOMER' },
        {
          title: 'Cancelled',
          description: reason ?? 'Cancelled by the customer',
          data: { cancellationReason: reason ?? 'Cancelled by the customer' },
        },
      );

    });

    // The parcel is left in its cancelled state rather than pushed into
    // `REFUND_PENDING` here. That status is part of the refund, not part of
    // the cancellation, and the refund is the only thing that knows whether
    // the delivery fee comes back with it.

    // Paid parcels are refunded outside the transaction, for the same reason
    // delivery settles outside its own: a cancellation the customer asked for
    // has already happened, and a busy ledger must not be able to refuse it.
    // Anything that fails here stays `REFUND_PENDING` and the hourly sweep in
    // `CustomerRefundsService` picks it up.
    if (wasPaid) await this.refundQuietly(sellerOrderId, userId);

    return { message: 'Sub-order cancelled' };
  }

  private async refundQuietly(
    sellerOrderId: string,
    actorId: string,
  ): Promise<void> {
    try {
      await this.refunds.refundUndeliveredParcel(sellerOrderId, actorId);
    } catch (error) {
      this.logger.error(
        `Cancelled ${sellerOrderId} but the refund failed — the sweep will ` +
          `retry: ${(error as Error).message}`,
      );
    }
  }

  async reorder(userId: string, id: string) {
    const order = await this.requireOrder(userId, id);
    for (const sellerOrder of order.sellerOrders) {
      for (const item of sellerOrder.items) {
        if (!item.offerId) continue;
        try {
          await this.cart.addItem(userId, {
            offer_id: item.offerId,
            quantity: item.quantity,
          });
        } catch {
          // Skip lines whose offer is gone, out of stock or paused.
        }
      }
    }
    return this.cart.getCart(userId);
  }

  /**
   * Recomputes the parent from its children.
   *
   * Kept as a method because callers outside this module reach for it, but the
   * derivation itself lives in the workflow service — one authority, so a
   * parent status can never depend on which service happened to update it.
   */
  async syncParentStatus(
    tx: Prisma.TransactionClient,
    orderId: string,
  ): Promise<OrderStatus> {
    return this.workflow.syncParent(tx, orderId);
  }

  private async requireOrder(userId: string, id: string) {
    const order = await this.repo.findDetail(id, userId);
    if (!order) throw new NotFoundException('Order not found');
    return order;
  }
}
