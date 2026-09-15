import { Injectable, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { CustomerIntelligenceService } from '../customer-intelligence/customer-intelligence.service';
import { RankingService } from '../ranking/ranking.service';
import { ReengagementService } from '../lifecycle/reengagement.service';
import { TrustService } from '../trust/trust.service';
import { ScheduledJob } from '../../common/scheduling/scheduled-job.decorator';

/**
 * When the marketplace thinks about itself.
 *
 * Two flags, not one, and the split is the whole point of this file.
 *
 * **Computation is safe.** Scoring listings, reading customers, sweeping the
 * trust queue — none of it is visible to anybody until a person opens a screen,
 * and a stale ranking is a worse product than a fresh one. That runs on
 * `INTELLIGENCE_SCHEDULER_ENABLED`.
 *
 * **Sending is not.** A job that pushes notifications to several hundred women
 * is not something a deployment should start doing on its own at nine in the
 * morning, and there is no way to un-send a push. It runs only on
 * `REENGAGEMENT_SCHEDULER_ENABLED`, which is deliberately a *second* switch:
 * somebody turning the intelligence on should not discover they also turned on
 * outbound marketing.
 *
 * Both default off. The endpoints exist for a person to trigger by hand, and
 * that is the correct state until somebody has read what the messages say.
 */
@Injectable()
export class IntelligenceScheduler {
  private readonly logger = new Logger(IntelligenceScheduler.name);

  constructor(
    private readonly config: ConfigService,
    private readonly ranking: RankingService,
    private readonly customers: CustomerIntelligenceService,
    private readonly trust: TrustService,
    private readonly reengagement: ReengagementService,
  ) {}

  private get computeEnabled(): boolean {
    return this.config.get<boolean>('intelligence.schedulerEnabled') ?? false;
  }

  private get sendEnabled(): boolean {
    return this.config.get<boolean>('intelligence.reengagementEnabled') ?? false;
  }

  /**
   * The nightly read.
   *
   * 03:10 UTC — after the trends run at 02:15 and the market sweep, because
   * the rankings read counters those passes refresh. Ten past, for the same
   * reason the others are quarter- and half-past: nothing in this platform
   * should start on the hour alongside everything else.
   */
  @ScheduledJob({ cron: '0 10 3 * * *' })
  async nightly(): Promise<void> {
    if (!this.computeEnabled) return;

    await this.step('listing ranking', () => this.ranking.sweepListings(5000));
    await this.step('seller ranking', () => this.ranking.sweepSellers(2000));
    await this.step('customer profiles', () =>
      this.customers.sweep({ sinceDays: 14, limit: 5000 }),
    );
    await this.step('review trust', () => this.trust.sweepReviews(7, 2000));
    await this.step('customer trust', () => this.trust.sweepCustomers(7, 2000));
    await this.step('seller conduct', () => this.trust.sweepSellers(14, 1000));
  }

  /**
   * Reminders, once a day, at an hour a person would choose.
   *
   * 06:30 UTC is 09:30 in Damascus — the first moment outside the quiet window
   * the contact policy enforces. Sending earlier would mean every message sat
   * queued until the policy released it anyway, which makes the queue depth
   * lie about what went out.
   *
   * The abandoned-basket pass runs first: a woman with something in her basket
   * has a live intention, and spending her one daily message on a win-back
   * instead would be the wrong trade.
   */
  @ScheduledJob({ cron: '0 30 6 * * *' })
  async reminders(): Promise<void> {
    if (!this.computeEnabled || !this.sendEnabled) return;

    await this.step('abandoned baskets', () =>
      this.reengagement.nudgeAbandonedBaskets(500),
    );
    await this.step('win-back (at risk)', () =>
      this.reengagement.winBack('at_risk', 250),
    );
    await this.step('conversion attribution', () =>
      this.reengagement.attribute(14),
    );
  }

  /**
   * Runs one step and keeps going when it fails.
   *
   * A nightly chain that stops at the first error leaves every later step
   * un-run for a whole day because one query timed out — and the step that
   * failed is rarely the one that mattered most.
   */
  private async step(
    name: string,
    run: () => Promise<unknown>,
  ): Promise<void> {
    const started = Date.now();
    try {
      const result = await run();
      this.logger.log(
        `${name}: ${JSON.stringify(result)} in ${Date.now() - started}ms`,
      );
    } catch (error) {
      this.logger.error(`${name} failed: ${String(error)}`);
    }
  }
}
