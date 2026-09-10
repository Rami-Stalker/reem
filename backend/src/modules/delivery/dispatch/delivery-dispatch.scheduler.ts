import { Injectable, Logger } from '@nestjs/common';
import { Cron } from '@nestjs/schedule';

import { PrismaService } from '../../../prisma/prisma.service';
import { DeliveryDispatchService } from './delivery-dispatch.service';

/** One sweep's worth. A backlog drains over consecutive runs. */
const BATCH = 50;

/**
 * How many times the platform will ask a carrier on its own.
 *
 * Past this, retrying is no longer plausibly a transient failure — a rejected
 * address, a closed account, a changed API — and the honest thing is to leave it
 * on the delivery desk for a person to read rather than to keep hammering an
 * endpoint that has answered the same way six times.
 */
const MAX_AUTOMATIC_ATTEMPTS = 6;

/**
 * The minimum age of a dispatch before it is retried, in minutes.
 *
 * Backoff by attempt count: 2, 8, 18, 32, 50 minutes. A carrier that just
 * refused is unlikely to accept a second later, and a carrier that is
 * restarting deserves a widening gap rather than a tight loop from every
 * pending parcel at once.
 */
const backoffMinutes = (attempts: number) => 2 * Math.max(1, attempts) ** 2;

/**
 * Re-attempts parcels the carrier never accepted.
 *
 * **What this closes.** `DeliveryDispatchService` was written correctly: a
 * carrier's failure is never the seller's problem, so the dispatch row records
 * `lastError`, the order is left alone, and "ops (or a retry) tries again". The
 * retry existed — `POST /admin/delivery/dispatches/:id/retry` — and nothing
 * called it. So a dispatch that failed because the carrier's API blipped for
 * thirty seconds sat there for ever: the parcel was never collected, the
 * customer watched a tracking page that never moved, the seller's escrow clock
 * never started because it runs from delivery, and the only way anyone found
 * out was an administrator happening to open the delivery desk and filter by
 * failed.
 *
 * On a cash platform that is money: an uncollected parcel is a sale that
 * silently did not happen.
 *
 * **What it deliberately does not do.** It does not create dispatches, does not
 * touch a parcel the carrier has accepted, and does not give up quietly. The
 * one-parcel-dispatched-once guarantee lives in the dispatch row and its
 * idempotency key, which a retry reuses — so this is safe precisely because it
 * calls the same `retry()` an administrator would.
 *
 * Every five minutes: fast enough that a brief carrier outage costs a parcel
 * minutes rather than a morning, slow enough that the backoff above is what
 * actually paces the calls.
 */
@Injectable()
export class DeliveryDispatchScheduler {
  private readonly logger = new Logger(DeliveryDispatchScheduler.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly dispatches: DeliveryDispatchService,
  ) {}

  @Cron('0 */5 * * * *')
  async retryFailedDispatches(): Promise<void> {
    const now = Date.now();

    const candidates = await this.prisma.deliveryDispatch.findMany({
      where: {
        // Never accepted. A dispatch the carrier took has an id, and retrying
        // it would be asking for a second parcel.
        externalDeliveryId: null,
        // Something actually went wrong. A dispatch with no error has not been
        // attempted yet and belongs to `ready()`, not here.
        lastError: { not: null },
        attemptCount: { lt: MAX_AUTOMATIC_ATTEMPTS },
        cancelledAt: null,
      },
      select: { id: true, attemptCount: true, updatedAt: true },
      orderBy: { updatedAt: 'asc' },
      take: BATCH,
    });

    const due = candidates.filter(
      (dispatch) =>
        now - dispatch.updatedAt.getTime() >=
        backoffMinutes(dispatch.attemptCount) * 60_000,
    );
    if (due.length === 0) return;

    let handedOver = 0;
    let stillFailing = 0;

    for (const dispatch of due) {
      try {
        const result = await this.dispatches.retry(dispatch.id);
        if (result.externalDeliveryId) handedOver += 1;
        else stillFailing += 1;
      } catch (error) {
        // One carrier being unreachable must not stop the sweep reaching the
        // others: these are independent parcels at independent providers.
        stillFailing += 1;
        this.logger.warn(
          `Dispatch ${dispatch.id} still refused on attempt ` +
            `${dispatch.attemptCount + 1}: ` +
            `${error instanceof Error ? error.message : String(error)}`,
        );
      }
    }

    if (handedOver > 0) {
      this.logger.log(
        `Handed ${handedOver} parcel(s) to a carrier on retry` +
          (stillFailing > 0 ? `, ${stillFailing} still refused` : ''),
      );
    } else if (stillFailing > 0) {
      this.logger.warn(`${stillFailing} parcel(s) still refused by their carrier`);
    }

    // Anything that has exhausted its attempts needs a person, and saying so
    // once per sweep is the difference between a queue somebody watches and a
    // queue nobody knows exists.
    const exhausted = await this.prisma.deliveryDispatch.count({
      where: {
        externalDeliveryId: null,
        lastError: { not: null },
        attemptCount: { gte: MAX_AUTOMATIC_ATTEMPTS },
        cancelledAt: null,
      },
    });
    if (exhausted > 0) {
      this.logger.error(
        `${exhausted} parcel(s) have exhausted automatic retries and are ` +
          'waiting on the delivery desk. Each one is a customer whose parcel ' +
          'was never collected.',
      );
    }
  }
}
