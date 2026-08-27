import { Injectable } from '@nestjs/common';
import { Cron, CronExpression } from '@nestjs/schedule';
import { MediaService } from './media.service';

/**
 * Deletes uploads that were never attached to anything.
 *
 * Hourly rather than nightly, and capped per pass inside the service: the
 * failure this guards against is a full disk, and a sweep that only runs at
 * 03:00 gives an abandoned-form loop a whole day to fill one.
 */
@Injectable()
export class MediaSweeperService {
  constructor(private readonly media: MediaService) {}

  @Cron(CronExpression.EVERY_HOUR)
  async sweep(): Promise<void> {
    await this.media.sweepOrphans();
  }
}
