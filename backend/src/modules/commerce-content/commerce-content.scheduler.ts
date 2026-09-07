import { Injectable, Logger } from '@nestjs/common';
import { Cron, CronExpression } from '@nestjs/schedule';
import { CommerceContentService } from './commerce-content.service';

/**
 * The content lifecycle clock: scheduled pieces go live, expired ones stop
 * being shown.
 *
 * This replaced `StoriesCleanupService`, which ran hourly and **hard-deleted**
 * every story past its 24 hours, cascading away its views and reactions. A
 * boutique therefore lost the analytics for a story exactly when it became
 * interesting to look at. Expiry is a status here: the tray filters on
 * `expires_at`, so she stops seeing it, and the numbers survive.
 *
 * The media behind an expired story is not deleted either, and that is
 * deliberate — it is claimed through `markAttached`, so the orphan sweeper
 * leaves it alone, and it is what a re-shared or highlighted story would need.
 */
@Injectable()
export class CommerceContentScheduler {
  private readonly logger = new Logger(CommerceContentScheduler.name);

  constructor(private readonly content: CommerceContentService) {}

  @Cron(CronExpression.EVERY_MINUTE)
  async processLifecycle(): Promise<void> {
    const result = await this.content.processDueContent();
    if (result.published || result.expired) {
      this.logger.log(
        `Commerce content lifecycle processed: ${result.published} published, ${result.expired} expired`,
      );
    }
  }
}
