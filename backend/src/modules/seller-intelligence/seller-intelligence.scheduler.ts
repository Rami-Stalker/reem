import { Injectable, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { Cron } from '@nestjs/schedule';
import { PrismaService } from '../../prisma/prisma.service';
import { ProductHealthService } from './product-health/product-health.service';
import { SellerHealthService } from './health/seller-health.service';

/**
 * When the shop is measured.
 *
 * 03:10 UTC, which is after the trend engine's 02:15 run and before any
 * seller is awake. The order matters and is the reason this is not merged
 * into the trend scheduler: product health reads `ProductDemandDaily`, which
 * the trend collector writes at 02:15, so running the two together would
 * score every listing against yesterday's demand for the rest of time.
 *
 * Within this job the order matters again — listings first, then shops —
 * because a seller's quality dimension is the mean of her listings' health.
 * Getting that backwards would not fail, which is worse: it would quietly
 * score every seller against the previous day's listings and nobody would
 * notice for a month.
 *
 * Off by default in development, like the trend engine's, for the same
 * reason: a job that walks every seller's order history is not something a
 * watch-mode process should decide to do overnight on somebody's laptop.
 */
@Injectable()
export class SellerIntelligenceScheduler {
  private readonly logger = new Logger(SellerIntelligenceScheduler.name);

  constructor(
    private readonly products: ProductHealthService,
    private readonly health: SellerHealthService,
    private readonly prisma: PrismaService,
    private readonly config: ConfigService,
  ) {}

  private get enabled(): boolean {
    return (
      this.config.get<boolean>('sellerIntelligence.schedulerEnabled') ??
      this.config.get<boolean>('trends.schedulerEnabled') ??
      false
    );
  }

  @Cron('0 10 3 * * *')
  async nightly(): Promise<void> {
    if (!this.enabled) return;
    await this.run();
  }

  /**
   * The sweep, also callable by hand.
   *
   * Per-seller isolation throughout: one shop with unusual data must not stop
   * the rest of the marketplace being scored, and a failure that takes down
   * the whole run is a failure that goes unnoticed until somebody asks why
   * their score is a month old.
   */
  async run(options: { now?: Date } = {}): Promise<{
    sellers: number;
    listings: number;
    failed: number;
  }> {
    const started = Date.now();
    const sellers = await this.prisma.user.findMany({
      where: { sellerOffers: { some: {} } },
      select: { id: true },
    });

    let listings = 0;
    let scored = 0;
    let failed = 0;

    for (const seller of sellers) {
      try {
        listings += await this.products.snapshotSeller(seller.id, options);
        await this.health.snapshot(seller.id, options);
        scored += 1;
      } catch (error) {
        failed += 1;
        this.logger.warn(
          `Seller intelligence failed for ${seller.id}: ${String(error)}`,
        );
      }
    }

    this.logger.log(
      `Seller intelligence: ${scored} shops, ${listings} listings, ${failed} failed, ${
        Date.now() - started
      }ms`,
    );
    return { sellers: scored, listings, failed };
  }
}
