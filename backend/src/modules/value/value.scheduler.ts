import { Injectable, Logger } from '@nestjs/common';
import { CronExpression } from '@nestjs/schedule';
import { ValueBenefitService } from './value-benefit.service';
import { ValueCollectorService } from './value-collector.service';
import { ValueScoringService } from './value-scoring.service';
import { ScheduledJob } from '../../common/scheduling/scheduled-job.decorator';

/**
 * The programme's clock.
 *
 * Two rhythms, and the split matters. The collector runs often, because
 * evidence matures at odd hours and a woman who earned something at noon should
 * not wait until midnight to see it. The full recompute runs once a night,
 * because decay is the only thing that moves a standing without an event, and
 * decay is slow.
 *
 * Everything here is idempotent — the collector by `dedupeKey`, the recompute
 * by being a pure function of stored events — so a missed run costs nothing and
 * a double run does nothing.
 */
@Injectable()
export class ValueScheduler {
  private readonly logger = new Logger(ValueScheduler.name);

  constructor(
    private readonly collector: ValueCollectorService,
    private readonly scoring: ValueScoringService,
    private readonly benefits: ValueBenefitService,
  ) {}

  /** New evidence, four times an hour's worth of latency at most. */
  @ScheduledJob({ cron: CronExpression.EVERY_30_MINUTES, staleAfterMinutes: 120 })
  async collect(): Promise<void> {
    try {
      const counts = await this.collector.sweep();
      this.logger.log(`Value sweep: ${JSON.stringify(counts)}`);
    } catch (error) {
      this.logger.error(`Value sweep failed: ${String(error)}`);
    }
  }

  /**
   * Decay, momentum and the daily snapshot.
   *
   * Runs for everybody, including women who did nothing today — which is the
   * point. A standing that only moved when she acted would not fade, and a
   * standing that does not fade is a balance.
   */
  @ScheduledJob({ cron: CronExpression.EVERY_DAY_AT_3AM, staleAfterMinutes: 1560, catchUp: true })
  async nightly(): Promise<void> {
    try {
      const expired = await this.benefits.expireStale();
      const recomputed = await this.scoring.recomputeAll();
      this.logger.log(
        `Value nightly: recomputed ${recomputed} profiles, expired ${expired} grants`,
      );
    } catch (error) {
      this.logger.error(`Value nightly failed: ${String(error)}`);
    }
  }
}
