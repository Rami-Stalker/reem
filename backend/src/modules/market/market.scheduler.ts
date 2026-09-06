import { Injectable, Logger, OnModuleInit } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { Cron } from '@nestjs/schedule';
import { BundlesService } from './bundles/bundles.service';
import { DropsService } from './drops/drops.service';
import { MarketEconomicsService } from './economics/market-economics.service';
import { MissionsService } from './missions/missions.service';

/**
 * When the market is read.
 *
 * 03:25 UTC, after the graph at 02:45 and seller intelligence at 03:10, which
 * is the order the data flows: demand facts, then the graph over them, then
 * the seller screens, then this — because the economics sweep reads the
 * graph's open needs and the trend engine's daily counts, and a market read
 * before either is a market read against yesterday.
 *
 * Off by default in development, like every other sweep here.
 */
@Injectable()
export class MarketScheduler implements OnModuleInit {
  private readonly logger = new Logger(MarketScheduler.name);

  constructor(
    private readonly economics: MarketEconomicsService,
    private readonly bundles: BundlesService,
    private readonly drops: DropsService,
    private readonly missions: MissionsService,
    private readonly config: ConfigService,
  ) {}

  /**
   * The mission catalogue is code, so it is installed on boot.
   *
   * Idempotent, and cheap — six upserts. Doing it here rather than in the seed
   * script means a deployment that adds a mission does not also require
   * somebody to remember to run something.
   */
  async onModuleInit(): Promise<void> {
    if (this.config.get<string>('NODE_ENV') === 'test') return;
    try {
      await this.missions.seed();
    } catch (error) {
      // A boot must not fail because a catalogue upsert did.
      this.logger.warn(`Mission catalogue not installed: ${String(error)}`);
    }
  }

  private get enabled(): boolean {
    return (
      this.config.get<boolean>('market.schedulerEnabled') ??
      this.config.get<boolean>('trends.schedulerEnabled') ??
      false
    );
  }

  @Cron('0 25 3 * * *')
  async nightly(): Promise<void> {
    if (!this.enabled) return;
    await this.run();
  }

  /**
   * Drops advance every fifteen minutes, not once a night.
   *
   * A drop scheduled for 8pm that opens at 3am the next morning is not a drop.
   * This is separated from the sweep for that reason alone: the state machine
   * is cheap and time-sensitive, the sweep is expensive and not.
   */
  @Cron('0 */15 * * * *')
  async advanceDrops(): Promise<void> {
    if (!this.enabled) return;
    const moved = await this.drops.advance();
    if (moved.opened || moved.closed) {
      this.logger.log(`Drops: ${moved.opened} opened, ${moved.closed} ended`);
    }
  }

  /** The sweep, also callable by hand. */
  async run(): Promise<{
    categories: number;
    products: number;
    bundles: number;
  }> {
    const started = Date.now();

    // Economics first: bundles do not read it, but drops do, and a candidate
    // list built from yesterday's signals is the one thing this ordering is
    // for.
    const swept = await this.economics.sweep();
    const built = await this.bundles.build();

    this.logger.log(
      `Market swept in ${Date.now() - started}ms: ` +
        `${swept.categories} categories, ${swept.products} products, ` +
        `${built.bundles} bundles`,
    );

    return {
      categories: swept.categories,
      products: swept.products,
      bundles: built.bundles,
    };
  }
}
