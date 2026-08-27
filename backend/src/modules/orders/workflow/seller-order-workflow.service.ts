import { Injectable, NotFoundException } from '@nestjs/common';
import {
  OrderStatus,
  PaymentStatus,
  Prisma,
  SellerOrderStatus,
} from '@prisma/client';

import { AuthUser } from '../../../common/decorators/current-user.decorator';
import {
  AWAITING_COLLECTION,
  StatusActor,
  actorForRole,
  assertTransition,
  deriveOrderStatus,
} from '../../../common/money';
import { PrismaService } from '../../../prisma/prisma.service';
// The escrow clock and the return window are the same seven days seen from
// two sides, so they share one constant rather than agreeing by coincidence.
import { RETURN_WINDOW_DAYS } from '../../returns/return-policy';

type Tx = Prisma.TransactionClient;

/** Who is moving the parcel, and under whose name the timeline records it. */
export interface WorkflowActor {
  readonly id: string | null;
  readonly role: StatusActor;
}

/** The scheduler, the courier settlement, anything with no human behind it. */
export const SYSTEM_ACTOR: WorkflowActor = Object.freeze({
  id: null,
  role: 'SYSTEM',
});

export function actorOf(user: AuthUser | null): WorkflowActor {
  return user ? { id: user.id, role: actorForRole(user.role) } : SYSTEM_ACTOR;
}

export interface MoveOptions {
  /** Shown on the customer's timeline. */
  readonly title: string;
  readonly description?: string | null;
  readonly metadata?: Prisma.InputJsonValue;
  /** Extra columns to write in the same statement as the status. */
  readonly data?: Prisma.SellerOrderUpdateInput;
}

/**
 * The one place a sub-order changes state.
 *
 * Before this, three services moved parcels and each did it slightly
 * differently: one wrote the timeline event, one forgot the parent
 * re-derivation, and none of them set `shippedAt` or `deliveredAt` — which is
 * why nothing in the platform could tell when a return window had opened.
 *
 * Four things happen together here, or none of them do:
 *
 * 1. **The transition is checked** against the table in `common/money`, with
 *    the actor. A service that "knows better" and writes `status` directly is
 *    how a lifecycle table stops being true.
 * 2. **The clocks are set from the status**, not from the caller. `shippedAt`
 *    when it leaves, `deliveredAt` when it lands, and — the important one —
 *    `escrowReleaseAt` counted from **delivery**, because Q56's seven days run
 *    from receipt and Q24 holds the seller's money for exactly that window.
 * 3. **The timeline gets an entry**, so the customer's order screen and the
 *    seller's both read the same history.
 * 4. **The parent order is re-derived** from its children — never written
 *    directly, which is what makes "partially shipped" representable at all.
 */
@Injectable()
export class SellerOrderWorkflowService {
  constructor(private readonly prisma: PrismaService) {}

  /**
   * Moves one sub-order.
   *
   * Takes an id rather than a row on purpose: the status it is moving *from*
   * decides whether the move is legal, and re-reading it inside the caller's
   * transaction is the only way that check sees the truth rather than whatever
   * was loaded a few statements ago.
   */
  async move(
    tx: Tx,
    sellerOrderId: string,
    to: SellerOrderStatus,
    actor: WorkflowActor,
    options: MoveOptions,
  ): Promise<SellerOrderStatus> {
    const current = await tx.sellerOrder.findUnique({
      where: { id: sellerOrderId },
      select: { id: true, orderId: true, status: true, deliveredAt: true },
    });
    if (!current) throw new NotFoundException('Sub-order not found');

    assertTransition(current.status, to, actor.role);

    await tx.sellerOrder.update({
      where: { id: sellerOrderId },
      data: {
        status: to,
        ...this.clocksFor(to, current.deliveredAt),
        ...(options.data ?? {}),
      },
    });

    await tx.orderEvent.create({
      data: {
        sellerOrderId,
        orderId: current.orderId,
        title: options.title,
        description: options.description ?? null,
        fromStatus: current.status,
        toStatus: to,
        actorId: actor.id,
        actorRole: actor.role,
        metadata: options.metadata,
      },
    });

    await this.syncParent(tx, current.orderId);
    return current.status;
  }

  /**
   * A timeline entry that changes no status.
   *
   * Used where something real happened to a parcel that its status cannot
   * express — a partial return, a note from support — so the history stays
   * complete without the status lying about it.
   */
  async note(
    tx: Tx,
    sellerOrderId: string,
    actor: WorkflowActor,
    title: string,
    description?: string | null,
  ): Promise<void> {
    const parcel = await tx.sellerOrder.findUnique({
      where: { id: sellerOrderId },
      select: { orderId: true },
    });
    if (!parcel) throw new NotFoundException('Sub-order not found');

    await tx.orderEvent.create({
      data: {
        sellerOrderId,
        orderId: parcel.orderId,
        title,
        description: description ?? null,
        actorId: actor.id,
        actorRole: actor.role,
      },
    });
  }

  /**
   * Puts a parcel's goods back on the shelf.
   *
   * Stock comes off the *offer* at checkout, and off the offer's variant when
   * one was chosen — the canonical product has no stock of its own. Anything
   * that stops a parcel reaching its customer has to undo that, or the seller
   * loses inventory to an order nobody received. Three services were each
   * doing this slightly differently before it moved here.
   *
   * Whether goods *can* go back on sale is a different question, and not this
   * one: a returned item may be damaged (see `isResaleable` in the returns
   * policy). A cancelled or refused parcel never left its packaging.
   */
  async restock(tx: Tx, sellerOrderId: string): Promise<void> {
    const items = await tx.orderItem.findMany({
      where: { sellerOrderId },
      select: { offerId: true, variantId: true, quantity: true },
    });

    for (const item of items) {
      if (!item.offerId) continue;
      await tx.sellerOffer.update({
        where: { id: item.offerId },
        data: { stock: { increment: item.quantity } },
      });
      if (item.variantId) {
        await tx.sellerOfferVariant.updateMany({
          where: { offerId: item.offerId, variantId: item.variantId },
          data: { stock: { increment: item.quantity } },
        });
      }
    }
  }

  /**
   * Recomputes the parent from its children.
   *
   * The parent's status is a pure function of the sub-orders and the payment;
   * writing it directly anywhere would let the two disagree, and a basket that
   * says "delivered" over a parcel still in transit is the kind of thing a
   * customer screenshots.
   */
  async syncParent(tx: Tx, orderId: string): Promise<OrderStatus> {
    const [children, payment] = await Promise.all([
      tx.sellerOrder.findMany({
        where: { orderId },
        select: { status: true },
      }),
      tx.payment.findUnique({
        where: { orderId },
        select: { paidAt: true },
      }),
    ]);

    const status = deriveOrderStatus(
      children.map((child) => child.status),
      { paid: payment?.paidAt != null },
    );

    await tx.order.update({ where: { id: orderId }, data: { status } });
    return status;
  }

  /**
   * Records what a parcel's delivery collected against the order's payment.
   *
   * One order has one payment row but may have several parcels, so a
   * cash-on-delivery order is only settled once the last of them is off the
   * road. `capturedAmount` — the column the schema keeps for exactly this
   * (Q30/Q54 P1, deposits and instalments) — carries the running total, and it
   * is written whether or not the total covers the order.
   *
   * The payment closes on **whichever comes first**: the captured cash
   * covering the order, or every parcel having arrived. The second clause is
   * not a shortcut — Q48 rounds an order's grand total to the nearest thousand
   * SYP while each parcel is collected on its own unrounded share, so the sum
   * of what the couriers hand over can sit a few hundred either side of the
   * figure on the order. Waiting for an exact match would leave honest orders
   * PENDING over a rounding step.
   *
   * Any real difference stays visible as `capturedAmount < amount` rather than
   * being papered over by the status: a parcel collected short is something
   * somebody has to chase, and hiding it here is the surest way for nobody
   * to.
   */
  async recordCollection(
    tx: Tx,
    orderId: string,
    collected: Prisma.Decimal,
  ): Promise<void> {
    const payment = await tx.payment.findUnique({ where: { orderId } });
    if (!payment || payment.status === PaymentStatus.PAID) return;

    const captured = payment.capturedAmount.plus(collected);
    const outstanding = await tx.sellerOrder.count({
      where: { orderId, status: { in: [...AWAITING_COLLECTION] } },
    });
    const covered =
      captured.greaterThanOrEqualTo(payment.amount) || outstanding === 0;

    await tx.payment.update({
      where: { id: payment.id },
      data: {
        capturedAmount: captured,
        ...(covered
          ? { status: PaymentStatus.PAID, paidAt: new Date() }
          : {}),
      },
    });

    if (covered) {
      await tx.paymentTransaction.create({
        data: {
          paymentId: payment.id,
          event: 'collected',
          status: PaymentStatus.PAID,
          currency: payment.currency,
          amount: captured,
          message: 'Collected on delivery',
        },
      });
    }
  }

  /**
   * Which timestamps a status implies.
   *
   * Derived rather than passed in: a caller that has to remember to set
   * `deliveredAt` alongside `DELIVERED` will eventually forget, and everything
   * downstream — the return window, the escrow clock, the review gate — reads
   * that column rather than the status.
   */
  private clocksFor(
    to: SellerOrderStatus,
    deliveredAt: Date | null,
  ): Prisma.SellerOrderUpdateInput {
    const now = new Date();

    switch (to) {
      case SellerOrderStatus.HANDED_TO_COURIER:
        return { shippedAt: now };

      case SellerOrderStatus.DELIVERED: {
        // A second delivery (after a failed attempt, or a returned parcel
        // going back out) must not restart the return window. The first
        // arrival is the one Q56 counts from.
        if (deliveredAt) return {};
        const escrowReleaseAt = new Date(now);
        escrowReleaseAt.setDate(escrowReleaseAt.getDate() + RETURN_WINDOW_DAYS);
        return { deliveredAt: now, escrowReleaseAt };
      }

      case SellerOrderStatus.CANCELLED_BY_CUSTOMER:
      case SellerOrderStatus.CANCELLED_BY_SELLER:
      case SellerOrderStatus.REJECTED_ON_DELIVERY:
        // Nothing is released for a parcel that never completed.
        return { closedAt: now, escrowReleaseAt: null };

      case SellerOrderStatus.REFUNDED:
      case SellerOrderStatus.EXCHANGED:
        return { closedAt: now };

      default:
        return {};
    }
  }
}
