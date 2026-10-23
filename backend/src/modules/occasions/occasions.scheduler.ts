import { Injectable, Logger } from '@nestjs/common';
import { ScheduledJob } from '../../common/scheduling/scheduled-job.decorator';
import { OccasionsService } from './occasions.service';

/**
 * The countdown, while nobody is looking.
 *
 * Hourly is enough: the marks are days apart, and the sweep only sends inside
 * the local daytime window (`SENDING_HOURS`), so the hour a reminder lands in
 * is "the first hour after ten in the morning" rather than "whenever the
 * instance woke up".
 *
 * Idempotent against `last_reminder_stage`, so the catch-up pass a sleeping
 * Free instance runs on waking cannot ring her twice for the same mark.
 */
@Injectable()
export class OccasionsScheduler {
  private readonly logger = new Logger(OccasionsScheduler.name);

  constructor(private readonly occasions: OccasionsService) {}

  @ScheduledJob({ cron: '0 7 * * * *', staleAfterMinutes: 180 })
  async remindUpcoming(): Promise<void> {
    const sent = await this.occasions.sendDueReminders();
    if (sent > 0) this.logger.log(`Sent ${sent} occasion countdown(s)`);
  }
}
