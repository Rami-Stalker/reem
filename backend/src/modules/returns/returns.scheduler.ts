import { Injectable, Logger } from '@nestjs/common';
import { Cron, CronExpression } from '@nestjs/schedule';

import { ReturnsService } from './returns.service';

/**
 * Pays out returns whose goods are back.
 *
 * Hourly rather than nightly: a refund is a customer waiting for her money,
 * and the sweep is cheap — it reads only the requests a seller has confirmed
 * receipt of since the last run. The nightly jobs (escrow release at 3am,
 * reconciliation right after) then see a settled picture rather than a day's
 * worth of returns still holding escrow open.
 */
@Injectable()
export class ReturnsScheduler {
  private readonly logger = new Logger(ReturnsScheduler.name);

  constructor(private readonly returns: ReturnsService) {}

  @Cron(CronExpression.EVERY_HOUR)
  async settleReceivedReturns(): Promise<void> {
    const { settled, failed } = await this.returns.settleDue();
    if (settled || failed) {
      this.logger.log(`Returns settled: ${settled}, failed: ${failed}`);
    }
  }
}
