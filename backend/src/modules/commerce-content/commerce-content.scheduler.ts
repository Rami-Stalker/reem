import { Injectable, Logger } from '@nestjs/common';
import { Cron, CronExpression } from '@nestjs/schedule';
import { CommerceContentService } from './commerce-content.service';

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
