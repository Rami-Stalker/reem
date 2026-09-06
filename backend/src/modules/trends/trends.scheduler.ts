import { Injectable, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { Cron, CronExpression } from '@nestjs/schedule';
import { TrendSignalService } from './collection/trend-signal.service';
import { PrismaService } from '../../prisma/prisma.service';
import { TrendsOrchestrator } from './trends.orchestrator';

/**
 * When the engine thinks.
 *
 * Once a night, at 02:15 UTC — 05:15 in Damascus, which is after the last
 * order of the evening and well before the first seller opens her dashboard.
 * The quarter-past is not superstition: the platform already runs three jobs
 * on the hour and two on the half hour, and a pipeline that reads the order
 * tables should not be competing with the reconciliation that writes them.
 *
 * There is deliberately no hourly re-scoring. A trend score is a statement
 * about a week; recomputing it at lunchtime produces a different number for
 * the same week and teaches everyone to refresh the page instead of trusting
 * it. The engine has one opinion a day and says when it formed it.
 */
@Injectable()
export class TrendsScheduler {
  private readonly logger = new Logger(TrendsScheduler.name);

  constructor(
    private readonly orchestrator: TrendsOrchestrator,
    private readonly signals: TrendSignalService,
    private readonly prisma: PrismaService,
    private readonly config: ConfigService,
  ) {}

  private get enabled(): boolean {
    // Off in development by default. A nightly job that reads the whole order
    // history is not something a `nest start --watch` should start doing on
    // its own the first night someone leaves their laptop open.
    return this.config.get<boolean>('trends.schedulerEnabled') ?? false;
  }

  @Cron('0 15 2 * * *')
  async nightly(): Promise<void> {
    if (!this.enabled) return;
    if (await this.orchestrator.isBusy()) {
      this.logger.warn('Skipping the nightly run: one is already in progress.');
      return;
    }

    try {
      await this.orchestrator.runAll({
        // Three days, because facts settle late: an order placed on Monday can
        // be cancelled on Wednesday, and Monday's row should say so.
        lookbackDays: this.config.get<number>('trends.lookbackDays') ?? 3,
      });
    } catch (error) {
      // Already recorded against its stage's `TrendEngineRun` row; logged here
      // so it reaches whatever watches the container's stderr too.
      this.logger.error(
        `Nightly trend run failed: ${
          error instanceof Error ? error.message : String(error)
        }`,
      );
    }
  }

  /**
   * Mark carts that have gone quiet.
   *
   * Abandonment is the one signal with no event of its own — nobody taps
   * "abandon" — so it has to be inferred from a cart that has sat untouched
   * past the horizon. Hourly, because a cart abandoned at 9pm should be
   * counted on the day it was abandoned rather than swept up at 2am into the
   * next one.
   *
   * `updatedAt` is the clock, not `createdAt`: a cart she keeps adding to is
   * not abandoned, and the marker moves every time she touches it.
   */
  @Cron(CronExpression.EVERY_HOUR)
  async sweepAbandonedCarts(): Promise<void> {
    if (!this.enabled) return;

    const hours = this.config.get<number>('trends.cartAbandonHours') ?? 6;
    const cutoff = new Date(Date.now() - hours * 3_600_000);
    // Only the hour that just crossed the line, so a cart is counted once and
    // not on every sweep for the rest of its life.
    const floor = new Date(cutoff.getTime() - 3_600_000);

    try {
      const items = await this.prisma.cartItem.findMany({
        where: { updatedAt: { gte: floor, lt: cutoff } },
        select: {
          userId: true,
          offer: { select: { productId: true, sellerId: true } },
        },
        take: 5_000,
      });

      for (const item of items) {
        this.signals.recordCartAbandoned({
          productId: item.offer.productId,
          sellerId: item.offer.sellerId,
          userId: item.userId,
        });
      }
      if (items.length) {
        this.logger.debug(`Marked ${items.length} cart lines as abandoned.`);
      }
    } catch (error) {
      this.logger.warn(
        `Cart abandonment sweep failed: ${
          error instanceof Error ? error.message : String(error)
        }`,
      );
    }
  }
}
