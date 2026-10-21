import { Injectable, Logger } from '@nestjs/common';
import { CronExpression } from '@nestjs/schedule';
import { ScheduledJob } from '../../common/scheduling/scheduled-job.decorator';
import { AppointmentsService } from './appointments.service';

/**
 * The two things a calendar has to do while nobody is looking.
 *
 * Both are written to survive the way this platform is actually hosted: a Free
 * instance sleeps, wakes, and runs every overdue job once in a catch-up pass.
 * So neither of these may be "send everything since the last run" — they are
 * both idempotent against their own state, and running them four times in a
 * minute produces the same result as running them once.
 */
@Injectable()
export class SalonsScheduler {
  private readonly logger = new Logger(SalonsScheduler.name);

  constructor(private readonly appointments: AppointmentsService) {}

  /**
   * «تذكير العميلة بالموعد».
   *
   * Every ten minutes rather than hourly: a reminder is only useful at roughly
   * the right time, and an hourly sweep on a twelve-hour lead means the actual
   * lead is anywhere between eleven and twelve hours.
   *
   * Idempotent through `reminderSentAt`, which is stamped by a conditional
   * update before the notification is sent — so a catch-up pass that finds the
   * same row cannot send it twice.
   */
  @ScheduledJob({ cron: '0 */10 * * * *', staleAfterMinutes: 60 })
  async remindUpcoming(): Promise<void> {
    const sent = await this.appointments.sendDueReminders();
    if (sent > 0) {
      this.logger.log(`Reminded ${sent} upcoming appointment(s)`);
    }
  }

  /**
   * Housekeeping the salon should not have to do by hand.
   *
   * A request nobody answered before its time is cancelled by the platform
   * rather than left holding a slot for ever; a confirmed appointment a day
   * past its end is taken as served so the review can be written. Both are
   * `updateMany` against a predicate, so they are naturally idempotent — the
   * second run matches nothing.
   */
  @ScheduledJob({ cron: CronExpression.EVERY_30_MINUTES, staleAfterMinutes: 180 })
  async closeStale(): Promise<void> {
    const { expired, completed } =
      await this.appointments.closeStaleAppointments();
    if (expired > 0 || completed > 0) {
      this.logger.log(
        `Appointments swept: ${expired} expired, ${completed} auto-completed`,
      );
    }
  }
}
