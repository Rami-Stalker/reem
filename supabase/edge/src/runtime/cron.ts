/**
 * `cron`, as `@nestjs/schedule` imports it on the edge.
 *
 * No timer ever starts here (`patches.ts` stops the scheduler from mounting
 * jobs; pg_cron triggers them). The real package and its date library would
 * add ~100 KB for code that never runs, so a job that somehow tried to mount
 * fails loudly instead of silently double-scheduling.
 */
export class CronJob {
  static from(): never {
    throw new Error('In-process cron timers are disabled on the edge; pg_cron triggers /internal/cron');
  }

  constructor() {
    CronJob.from();
  }
}

export class CronTime {}
