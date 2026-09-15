import { SetMetadata } from '@nestjs/common';
import { Cron } from '@nestjs/schedule';

export const SCHEDULED_JOB = 'reem:scheduled-job';

export interface ScheduledJobOptions {
  /**
   * Cron expression, six fields (seconds first) or five, **evaluated in UTC**
   * whatever the host's clock says — the times written beside each job are
   * UTC, and a container, a laptop in Damascus and a CI runner must agree.
   */
  cron: string;

  /**
   * How long one run may hold the job before another instance may take it,
   * if its holder stops renewing. The holder renews every third of this while
   * it runs, so a long run keeps its lease; a crashed one loses it within
   * this many seconds. Default 120.
   */
  leaseSeconds?: number;

  /**
   * `false` for a job that is already safe to run on several instances at
   * once by construction (the OTP outbox claims rows `FOR UPDATE SKIP
   * LOCKED`) and runs so often that two extra writes per tick would be the
   * main cost of the job. Such a job is guarded against overlapping itself on
   * one instance only, and keeps no run record.
   */
  lease?: boolean;

  /**
   * When the job counts as overdue: no successful run for this many minutes.
   * Drives `/health/jobs` and, with `catchUp`, the run on start-up. Leave it
   * unset for jobs that are switched off by default or harmless to miss.
   */
  staleAfterMinutes?: number;

  /**
   * Run once shortly after start-up when overdue. **On by default for every
   * job that declares `staleAfterMinutes`**; `false` opts out.
   *
   * A process that was not running — a restart, a deploy, or an instance that
   * slept because nobody used it — missed every tick in between. A timer only
   * knows the *next* tick, so without this a nightly sweep waits a day and a
   * ten-minute sweep waits ten more minutes after a customer's request woke
   * the service. Catch-up runs the overdue ones first, most time-sensitive
   * (shortest window) first.
   */
  catchUp?: boolean;

  /**
   * An overdue critical job turns `/health/jobs` into a 503, which is what an
   * uptime monitor alerts on. Reserved for jobs whose silence costs money or
   * access: stock held by abandoned orders, escrow, refunds, sign-in codes.
   */
  critical?: boolean;
}

export interface ScheduledJobMetadata extends ScheduledJobOptions {
  /** `ClassName.method` — the same name the retired pg_cron schedule used. */
  name: string;
}

/**
 * Declares a scheduled job.
 *
 * Replaces `@Cron`. The job is run by `JobRunner`, which takes a lease in
 * `scheduled_job_states` before every run, so no two instances ever run the
 * same job at the same time, and records how the run went.
 *
 * `@Cron` metadata is still written, with the same name and UTC, so tooling
 * that enumerates `@nestjs/schedule` jobs (the retired edge build's cron
 * registry) keeps seeing every job. Nothing mounts those timers any more —
 * `ScheduleModule` is not imported — so this adds no second schedule.
 */
export function ScheduledJob(options: ScheduledJobOptions): MethodDecorator {
  return (target, propertyKey, descriptor) => {
    const name = `${target.constructor.name}.${String(propertyKey)}`;
    Cron(options.cron, { name, timeZone: 'UTC' })(target, propertyKey, descriptor);
    SetMetadata(SCHEDULED_JOB, { ...options, name } satisfies ScheduledJobMetadata)(
      target,
      propertyKey,
      descriptor,
    );
    return descriptor;
  };
}
