import { Injectable, Logger } from '@nestjs/common';
import { InventoryReservationState, Prisma } from '@prisma/client';

import { PrismaService } from '../../../prisma/prisma.service';
import { claimStock } from './stock-claim';

type Tx = Prisma.TransactionClient;

/** One line's worth of stock to take off an offer. */
export interface ReservationRequest {
  orderId: string;
  sellerOrderId: string;
  offerId: string;
  offerVariantId: string | null;
  quantity: number;
  /** Used only to word the refusal — a customer sees a garment, not an id. */
  title: string;
  /** When an unconfirmed hold lets go by itself. */
  expiresAt: Date;
}

/** The states a reservation may still be undone from. */
const UNDOABLE: InventoryReservationState[] = [
  InventoryReservationState.HELD,
  InventoryReservationState.COMMITTED,
];

/**
 * Stock, and the promises made against it.
 *
 * **What this replaces.** Stock came off `SellerOffer.stock` in one atomic
 * `UPDATE ... WHERE stock >= n` — which was right, and is kept — and went back
 * on with an unconditional `increment`, which was not. Nothing recorded that a
 * particular order had taken a particular unit, so:
 *
 * - **Releasing twice released twice.** A cancellation retried after a
 *   timeout, or a refusal recorded by both the rider and the carrier's
 *   webhook, credited the seller units she never got back. The shelf drifted
 *   upward and the next customer was sold something that did not exist.
 * - **A wedged order kept its stock for ever.** The only thing that returned
 *   units was the order lifecycle; if a sub-order could not be moved, the
 *   garment was withdrawn from sale permanently and nobody could say why.
 * - **"Available" and "spoken for" were the same number.**
 *
 * **The guarantee.** Every state change is a conditional `updateMany` on the
 * reservation's current state, and the stock movement is derived from how many
 * rows that matched. A second call matches nothing and moves nothing — so
 * every operation here is safe to retry, which is what lets the callers above
 * be careless in the way that distributed systems force them to be.
 *
 * **What did not change.** `SellerOffer.stock` still means *available*. Every
 * catalogue query, product card and roll-up reads it; redefining it as
 * "physically present" would have made availability a join on the hot path,
 * and the whole point of the stored roll-ups is that it is not one.
 */
@Injectable()
export class InventoryReservationService {
  private readonly logger = new Logger(InventoryReservationService.name);

  constructor(private readonly prisma: PrismaService) {}

  /**
   * Takes stock off an offer and records who took it.
   *
   * The claim itself is unchanged and stays where it was — inside the UPDATE,
   * where Postgres re-evaluates it against the row it has locked. Checkout
   * validates availability while building the basket, and under READ COMMITTED
   * that read is history by the time the write lands; two women reaching for
   * the last dress both saw `stock: 1`, both passed the check, and an
   * unconditional decrement sold the same garment twice. The loser is turned
   * away here, at checkout, with her money untaken.
   *
   * The reservation row is written **after** the stock moves, in the same
   * transaction: if the claim fails there is nothing to record, and if the
   * transaction rolls back neither happened.
   */
  async reserve(tx: Tx, request: ReservationRequest): Promise<void> {
    // The race itself lives in `claimStock`, which is the primitive and is
    // where the concurrency tests point: the condition is inside the UPDATE,
    // so Postgres re-evaluates it against the row it has locked. This method
    // adds the bookkeeping around it, not the safety.
    await claimStock(tx, {
      offerId: request.offerId,
      offerVariantId: request.offerVariantId,
      quantity: request.quantity,
      title: request.title,
    });

    await tx.inventoryReservation.create({
      data: {
        orderId: request.orderId,
        sellerOrderId: request.sellerOrderId,
        offerId: request.offerId,
        offerVariantId: request.offerVariantId,
        quantity: request.quantity,
        state: InventoryReservationState.HELD,
        expiresAt: request.expiresAt,
      },
    });
  }

  /**
   * The order is paid for (or accepted on cash terms) and the seller is
   * preparing it — so no timer may take it back.
   *
   * Clearing `expiresAt` is the point of this call. A parcel a seller has
   * begun packing must never be released by a sweep that has no idea she is
   * standing over it.
   */
  async commit(tx: Tx, orderId: string): Promise<number> {
    const moved = await tx.inventoryReservation.updateMany({
      where: { orderId, state: InventoryReservationState.HELD },
      data: {
        state: InventoryReservationState.COMMITTED,
        committedAt: new Date(),
        expiresAt: null,
      },
    });
    return moved.count;
  }

  /**
   * The goods reached the customer. The units are gone for good.
   *
   * A parcel that comes back afterwards is a *return*, and a return is new
   * stock arriving rather than this reservation being undone — which is why
   * `ReturnsService` puts units back on the shelf directly and this state is
   * terminal. Collapsing the two would erase the difference between "she never
   * received it" and "she received it and sent it back", and the second is a
   * fact the seller's reputation depends on.
   */
  async consume(tx: Tx, sellerOrderId: string): Promise<number> {
    const moved = await tx.inventoryReservation.updateMany({
      where: {
        sellerOrderId,
        state: { in: UNDOABLE },
      },
      data: {
        state: InventoryReservationState.CONSUMED,
        consumedAt: new Date(),
        expiresAt: null,
      },
    });
    return moved.count;
  }

  /**
   * Puts a parcel's units back on the shelf — once, however many times it is
   * called.
   *
   * This is the whole reason the table exists. Each reservation is moved to
   * `RELEASED` by a conditional update, and **only the rows that actually
   * moved** have their units returned. A second call matches nothing, adds
   * nothing, and reports zero.
   */
  async releaseForSellerOrder(
    tx: Tx,
    sellerOrderId: string,
    reason: string,
  ): Promise<number> {
    const held = await tx.inventoryReservation.findMany({
      where: { sellerOrderId, state: { in: UNDOABLE } },
      select: {
        id: true,
        offerId: true,
        offerVariantId: true,
        quantity: true,
      },
    });
    return this.releaseEach(tx, held, reason);
  }

  /** The same, for every parcel of an order — used when a basket expires. */
  async releaseForOrder(
    tx: Tx,
    orderId: string,
    reason: string,
  ): Promise<number> {
    const held = await tx.inventoryReservation.findMany({
      where: { orderId, state: { in: UNDOABLE } },
      select: {
        id: true,
        offerId: true,
        offerVariantId: true,
        quantity: true,
      },
    });
    return this.releaseEach(tx, held, reason);
  }

  /**
   * Lets go of holds nobody came back to confirm.
   *
   * The safety net that does not depend on the order lifecycle: even if a
   * sub-order is stuck in a state no service will move it out of, its stock
   * comes back. Returns the ids it released so the caller can log which orders
   * were affected.
   */
  async releaseExpired(
    now: Date = new Date(),
    take = 500,
  ): Promise<{ released: number; orders: string[] }> {
    const due = await this.prisma.inventoryReservation.findMany({
      where: {
        state: InventoryReservationState.HELD,
        expiresAt: { lt: now },
      },
      select: {
        id: true,
        orderId: true,
        offerId: true,
        offerVariantId: true,
        quantity: true,
      },
      orderBy: { expiresAt: 'asc' },
      take,
    });
    if (due.length === 0) return { released: 0, orders: [] };

    let released = 0;
    const orders = new Set<string>();
    for (const reservation of due) {
      try {
        // One transaction per reservation: a sweep that took every affected
        // offer row in one lock would block checkout across the platform for
        // as long as it ran.
        await this.prisma.$transaction(async (tx) => {
          const count = await this.releaseEach(
            tx,
            [reservation],
            'انتهت مهلة الحجز',
          );
          released += count;
          if (count) orders.add(reservation.orderId);
        });
      } catch (error) {
        this.logger.warn(
          `Could not release reservation ${reservation.id}: ${
            (error as Error).message
          }`,
        );
      }
    }
    return { released, orders: [...orders] };
  }

  /** What an offer currently has spoken for, for the seller's stock screen. */
  async reservedFor(offerId: string): Promise<number> {
    const sum = await this.prisma.inventoryReservation.aggregate({
      where: { offerId, state: { in: UNDOABLE } },
      _sum: { quantity: true },
    });
    return sum._sum.quantity ?? 0;
  }

  /**
   * Moves each reservation to RELEASED and returns its units — but only for
   * the rows the conditional update actually claimed.
   *
   * The order matters: the state moves **first**, and the stock moves only if
   * that matched. Doing it the other way round would return units and then
   * discover somebody else had already returned them, with no way to take them
   * back off the shelf.
   */
  private async releaseEach(
    tx: Tx,
    reservations: ReadonlyArray<{
      id: string;
      offerId: string;
      offerVariantId: string | null;
      quantity: number;
    }>,
    reason: string,
  ): Promise<number> {
    let released = 0;

    for (const reservation of reservations) {
      const claimed = await tx.inventoryReservation.updateMany({
        where: { id: reservation.id, state: { in: UNDOABLE } },
        data: {
          state: InventoryReservationState.RELEASED,
          releasedAt: new Date(),
          releaseReason: reason,
          expiresAt: null,
        },
      });
      // Somebody else got there first. Their call returned the units; this one
      // must not return them again.
      if (claimed.count === 0) continue;

      await tx.sellerOffer.update({
        where: { id: reservation.offerId },
        data: { stock: { increment: reservation.quantity } },
      });
      if (reservation.offerVariantId) {
        await tx.sellerOfferVariant.updateMany({
          where: { id: reservation.offerVariantId },
          data: { stock: { increment: reservation.quantity } },
        });
      }
      released += 1;
    }

    return released;
  }
}
