import { Injectable, Logger } from '@nestjs/common';
import { CronExpression } from '@nestjs/schedule';
import { IdempotencyState } from '@prisma/client';

import { PrismaService } from '../../prisma/prisma.service';
import { ScheduledJob } from '../scheduling/scheduled-job.decorator';

/**
 * A request key is a short window against a double tap, not a permanent name.
 *
 * Two things are cleared here, and they are different problems:
 *
 * - **Expired records**, which have simply outlived their purpose. Left alone
 *   the table would grow by one row per unsafe request for ever.
 * - **Stale in-flight claims**, which are the interesting case. A record is
 *   inserted before the handler runs and completed after it; a process that
 *   dies in between leaves a claim nobody will ever finish, and every retry of
 *   that request would answer `409 — still processing` until the record
 *   expired a day later. Ten minutes is long enough that no real request is
 *   still running, and short enough that a customer who tried again during a
 *   restart is not locked out of her own checkout.
 */
@Injectable()
export class IdempotencySweeper {
  private readonly logger = new Logger(IdempotencySweeper.name);

  /** Longer than any request this platform serves, by a wide margin. */
  private readonly staleAfterMs = 10 * 60 * 1000;

  constructor(private readonly prisma: PrismaService) {}

  @ScheduledJob({ cron: CronExpression.EVERY_HOUR, staleAfterMinutes: 180 })
  async sweep(): Promise<void> {
    try {
      const [expired, stale] = await Promise.all([
        this.prisma.idempotencyRecord.deleteMany({
          where: { expiresAt: { lt: new Date() } },
        }),
        this.prisma.idempotencyRecord.deleteMany({
          where: {
            state: IdempotencyState.IN_FLIGHT,
            createdAt: { lt: new Date(Date.now() - this.staleAfterMs) },
          },
        }),
      ]);

      if (stale.count) {
        // Worth a line rather than silence: every one of these is a request
        // that started and never finished, which usually means a crash.
        this.logger.warn(
          `Cleared ${stale.count} idempotency claim(s) that never completed`,
        );
      }
      if (expired.count) {
        this.logger.log(`Cleared ${expired.count} expired idempotency record(s)`);
      }
    } catch (error) {
      this.logger.error(
        `Idempotency sweep failed: ${(error as Error).message}`,
      );
    }
  }
}
