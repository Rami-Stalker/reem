import { Injectable, Logger } from '@nestjs/common';
import { Cron, CronExpression } from '@nestjs/schedule';
import { StoriesRepository } from './stories.repository';

/** Hard-deletes stories past their 24h TTL (cascades views + reactions). */
@Injectable()
export class StoriesCleanupService {
  private readonly logger = new Logger(StoriesCleanupService.name);

  constructor(private readonly repo: StoriesRepository) {}

  @Cron(CronExpression.EVERY_HOUR)
  async purgeExpired(): Promise<void> {
    const result = await this.repo.deleteExpired();
    if (result.count > 0) {
      this.logger.log(`Purged ${result.count} expired stories`);
    }
  }
}
