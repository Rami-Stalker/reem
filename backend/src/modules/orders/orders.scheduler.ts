import { Injectable, Logger } from '@nestjs/common';
import { Cron, CronExpression } from '@nestjs/schedule';
import { CodAssuranceState, OrderStatus } from '@prisma/client';

import { PrismaService } from '../../prisma/prisma.service';
import { OrdersService } from './orders.service';
import { InventoryReservationService } from './workflow/inventory-reservation.service';

/** One sweep's worth. A backlog drains over consecutive runs. */
const BATCH = 200;

const REASON = 'انتهت مهلة الدفع';

/**
 * Releases the stock held by orders nobody paid for.
 *
 * **What this closes.** Stock comes off the seller's offer inside the checkout
 * transaction — that is what makes the oversell guarantee work — so from the
 * instant an order exists its garments are unavailable to everyone else. The
 * platform had exactly one release valve for that, `CodTrustScheduler`, and it
 * only covers cash orders that the trust engine held for a confirmation code.
 * Every other route into `PENDING_PAYMENT` held its stock **for ever**: a
 * transfer she never sent, a gateway page she closed, a guest checkout, or a
 * crash between creating the order and confirming it. The seller was never
 * told; her dress had simply stopped selling.
 *
 * **The two sweeps do not overlap.** An order with a live cash hold is
 * excluded here and left to `CodTrustScheduler`, which owns that thirty-minute
 * clock. Without the exclusion both would cancel the same order and write two
 * timeline entries for one event.
 *
 * **Ten minutes, matching the cash sweep.** The shortest deadline this
 * enforces is an hour (`order-expiry.ts`), so a coarser sweep would hold an
 * abandoned order well past its own stated deadline — and the whole point is
 * that the deadline is real.
 *
 * Cancellation runs through `OrdersService.expireUnpaid`, not a status write
 * here, so the stock goes back through the one path that knows how to undo a
 * checkout in full, and the customer's timeline records it the same way any
 * other cancellation is recorded.
 *
 * **Single instance only.** A second process running this would race to cancel
 * the same orders; the transition table would refuse the loser, but the log
 * would fill with false failures. See `docs/DEPLOYMENT.md`.
 */
@Injectable()
export class OrdersScheduler {
  private readonly logger = new Logger(OrdersScheduler.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly orders: OrdersService,
    private readonly reservations: InventoryReservationService,
  ) {}

  @Cron(CronExpression.EVERY_10_MINUTES)
  async expireUnpaidOrders(): Promise<void> {
    const expired = await this.prisma.order.findMany({
      where: {
        status: OrderStatus.PENDING_PAYMENT,
        expiresAt: { lt: new Date() },
        // The cash-hold sweep owns these; see the class comment.
        codRiskAssessment: {
          is: null,
        },
      },
      select: { id: true, number: true },
      orderBy: { expiresAt: 'asc' },
      take: BATCH,
    });

    // An order that *has* an assessment is only ours once that hold is over —
    // abandoned or resolved — because until then the cash sweep is still
    // watching it. Expressed as a second query rather than an `OR` so the
    // index on (status, expires_at) serves both.
    const heldButSettled = await this.prisma.order.findMany({
      where: {
        status: OrderStatus.PENDING_PAYMENT,
        expiresAt: { lt: new Date() },
        codRiskAssessment: {
          is: { state: { not: CodAssuranceState.PENDING } },
        },
      },
      select: { id: true, number: true },
      orderBy: { expiresAt: 'asc' },
      take: BATCH,
    });

    let released = 0;
    let skipped = 0;
    for (const order of [...expired, ...heldButSettled]) {
      try {
        const done = await this.orders.expireUnpaid(order.id, REASON);
        if (done) released += 1;
        else skipped += 1;
      } catch (error) {
        // One order that will not cancel — a parcel a seller confirmed in the
        // seconds since the query, most likely — must not stop the sweep.
        skipped += 1;
        this.logger.warn(
          `Could not expire order ${order.number}: ${(error as Error).message}`,
        );
      }
    }

    if (released || skipped) {
      this.logger.log(
        `Expired ${released} unpaid order(s), skipped ${skipped}`,
      );
    }
  }

  /**
   * The net beneath the net.
   *
   * The sweep above releases stock by cancelling the *order*, which is the
   * right thing to do when the order can still be cancelled. This one releases
   * stock by expiring the *reservation*, and it does not care what state the
   * order is in.
   *
   * That difference is the whole reason it exists. Every path that returns
   * units — a customer cancelling, a seller cancelling, a refusal at the door,
   * the expiry sweep — runs through code that can fail or through a status
   * transition that can be refused. A sub-order wedged in a state nothing will
   * move it out of used to take its stock with it permanently, and the seller
   * had no way to discover why a dress had stopped selling. A hold carries its
   * own deadline, so the shelf recovers on its own.
   *
   * Runs a little after the order sweep rather than beside it: an order
   * cancelled at :00 releases its own reservations, and this finds only what
   * that could not reach.
   */
  @Cron('0 5,15,25,35,45,55 * * * *')
  async releaseExpiredReservations(): Promise<void> {
    try {
      const { released, orders } = await this.reservations.releaseExpired();
      if (released) {
        this.logger.warn(
          `Released ${released} expired stock reservation(s) across ` +
            `${orders.length} order(s). These are holds the order sweep could ` +
            `not reach — worth looking at why.`,
        );
      }
    } catch (error) {
      this.logger.error(
        `Reservation sweep failed: ${(error as Error).message}`,
      );
    }
  }
}
