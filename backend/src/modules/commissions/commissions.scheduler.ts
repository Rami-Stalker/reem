import { Injectable, Logger } from '@nestjs/common';
import { Cron } from '@nestjs/schedule';

import { CommissionsService } from './commissions.service';

/**
 * The nightly release of seller escrow.
 *
 * **Why this file exists.** `CommissionsService.releaseDueEscrow` was written,
 * tested and correct — and nothing ever called it. No cron, no route, no
 * caller outside its own spec. The consequence was not subtle: a payout can
 * only claim a commission ledger whose sub-order carries `escrowReleased`
 * (`SellerPayoutsService.claimableLedgers`), so with the flag never set, every
 * payout request from every seller returned zero. The platform could take
 * money and could never pay it out. `ReturnsScheduler` even documents "the
 * nightly jobs (escrow release at 3am…)" — describing a job that did not
 * exist.
 *
 * **Why 02:30 and not 03:00.** The night has an order, and it is not
 * arbitrary:
 *
 * 1. `ReturnsScheduler` settles received returns hourly, so by the small hours
 *    the returns that came back today have taken their share out of escrow.
 * 2. **This sweep, 02:30** — what is left after the returns is now final and
 *    becomes payable.
 * 3. `ReconciliationService` at 03:00 then checks a settled picture. Running
 *    it *before* the release would have it reconcile a ledger that is about to
 *    move, and report a discrepancy that fixes itself half an hour later.
 * 4. `FxRevaluationService` at 04:00 revalues what remains.
 *
 * **Single instance only.** This job posts to the ledger, and the postings are
 * idempotent on their `reference`, so a second instance running it in parallel
 * would not double-pay — but it would double the work and race on the
 * `escrowReleased` flag. See `docs/DEPLOYMENT.md`: the platform runs one API
 * process until a distributed lock exists.
 */
@Injectable()
export class CommissionsScheduler {
  private readonly logger = new Logger(CommissionsScheduler.name);

  constructor(private readonly commissions: CommissionsService) {}

  @Cron('0 30 2 * * *')
  async releaseEscrow(): Promise<void> {
    try {
      const { released, failed } = await this.commissions.releaseDueEscrow();
      if (released || failed) {
        this.logger.log(`Escrow released: ${released}, failed: ${failed}`);
      }
      if (failed) {
        this.logger.warn(
          `${failed} parcel(s) could not be released and stay in escrow until ` +
            `the next sweep. Their money is not lost — it is unreleased.`,
        );
      }
    } catch (error) {
      // A sweep that throws must not take the scheduler down with it; the
      // money stays exactly where it is and tomorrow's run tries again.
      this.logger.error(
        `Escrow sweep failed outright: ${(error as Error).message}`,
      );
    }
  }
}
