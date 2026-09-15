import { Injectable, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { AffinityBuilderService } from './projection/affinity-builder.service';
import { GraphProjectorService } from './projection/graph-projector.service';
import { ScheduledJob } from '../../common/scheduling/scheduled-job.decorator';

/**
 * When the graph is rebuilt.
 *
 * 02:45 UTC — after the trend engine's 02:45 roll-up feeds `ProductDemandDaily`
 * and before seller intelligence at 03:10, which is the order the data flows:
 * demand facts, then the graph that reads them, then the seller screens that
 * read the graph.
 *
 * Off by default in development for the same reason every other sweep here is:
 * a job that walks every shopper's history is not something a watch-mode
 * process should start doing overnight on somebody's laptop.
 */
@Injectable()
export class GraphScheduler {
  private readonly logger = new Logger(GraphScheduler.name);

  constructor(
    private readonly projector: GraphProjectorService,
    private readonly affinities: AffinityBuilderService,
    private readonly config: ConfigService,
  ) {}

  private get enabled(): boolean {
    return (
      this.config.get<boolean>('graph.schedulerEnabled') ??
      this.config.get<boolean>('trends.schedulerEnabled') ??
      false
    );
  }

  @ScheduledJob({ cron: '0 45 2 * * *' })
  async nightly(): Promise<void> {
    if (!this.enabled) return;
    await this.run();
  }

  /**
   * The sweep, also callable by hand.
   *
   * Affinities first: the shopper projection does not depend on them, but the
   * product page reads both, and rebuilding the catalogue relations before the
   * per-user edges means a page opened mid-sweep sees the older pair rather
   * than a half-built one.
   */
  async run(): Promise<{
    categories: number;
    affinities: number;
    shoppers: number;
    edges: number;
  }> {
    const started = Date.now();
    const built = await this.affinities.buildAll();
    const projected = await this.projector.projectAll();

    this.logger.log(
      `Commerce graph rebuilt in ${Date.now() - started}ms: ` +
        `${built.edges} affinities over ${built.categories} categories, ` +
        `${projected.edges} edges for ${projected.users} shoppers`,
    );

    return {
      categories: built.categories,
      affinities: built.edges,
      shoppers: projected.users,
      edges: projected.edges,
    };
  }
}
