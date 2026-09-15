import { Injectable } from '@nestjs/common';
import { ScheduledJobState } from '@prisma/client';
import { PrismaService } from '../../prisma/prisma.service';

export type JobTrigger = 'schedule' | 'catch-up' | 'manual';
export type JobOutcome = 'SUCCEEDED' | 'FAILED';

/**
 * The lease on a scheduled job, held in `scheduled_job_states`.
 *
 * Every statement is a single atomic write evaluated against the database's
 * own clock — never this process's — so two instances with drifting clocks
 * still agree on whether a lease has run out. `now() AT TIME ZONE 'UTC'`
 * because the columns are naive UTC timestamps like every other in this
 * schema (see `common/sql/utc-timestamp.ts` for what a bare `now()` would do
 * on a server in another zone).
 */
@Injectable()
export class JobLeaseRepository {
  constructor(private readonly prisma: PrismaService) {}

  /**
   * Takes the lease if nobody holds it, or the holder let it run out.
   *
   * One `INSERT … ON CONFLICT DO UPDATE … WHERE`: the row is created on the
   * first run and taken over only when free, and Postgres serialises two
   * instances racing for the same row, so exactly one gets it back.
   */
  async acquire(
    name: string,
    holder: string,
    leaseSeconds: number,
    trigger: JobTrigger,
  ): Promise<boolean> {
    const rows = await this.prisma.$queryRaw<{ name: string }[]>`
      INSERT INTO scheduled_job_states
        (name, locked_by, locked_until, last_started_at, last_status, last_trigger, updated_at)
      VALUES (
        ${name}, ${holder},
        (now() AT TIME ZONE 'UTC') + make_interval(secs => ${leaseSeconds}::int),
        (now() AT TIME ZONE 'UTC'), 'RUNNING', ${trigger},
        (now() AT TIME ZONE 'UTC')
      )
      ON CONFLICT (name) DO UPDATE SET
        locked_by       = EXCLUDED.locked_by,
        locked_until    = EXCLUDED.locked_until,
        last_started_at = EXCLUDED.last_started_at,
        last_status     = 'RUNNING',
        last_trigger    = EXCLUDED.last_trigger,
        updated_at      = EXCLUDED.updated_at
      WHERE scheduled_job_states.locked_until IS NULL
         OR scheduled_job_states.locked_until < (now() AT TIME ZONE 'UTC')
      RETURNING name
    `;
    return rows.length === 1;
  }

  /** Extends a lease its holder still has. False when it was lost. */
  async renew(name: string, holder: string, leaseSeconds: number): Promise<boolean> {
    const updated = await this.prisma.$executeRaw`
      UPDATE scheduled_job_states
         SET locked_until = (now() AT TIME ZONE 'UTC') + make_interval(secs => ${leaseSeconds}::int),
             updated_at   = (now() AT TIME ZONE 'UTC')
       WHERE name = ${name} AND locked_by = ${holder}
    `;
    return updated === 1;
  }

  /**
   * Releases the lease and records the run. Only the holder can: a run that
   * outlived its lease (and whose job another instance has since taken) must
   * not release somebody else's.
   */
  async finish(
    name: string,
    holder: string,
    outcome: JobOutcome,
    durationMs: number,
    error?: string,
  ): Promise<boolean> {
    const updated = await this.prisma.$executeRaw`
      UPDATE scheduled_job_states SET
        locked_by            = NULL,
        locked_until         = NULL,
        last_finished_at     = (now() AT TIME ZONE 'UTC'),
        last_succeeded_at    = CASE WHEN ${outcome} = 'SUCCEEDED'
                                    THEN (now() AT TIME ZONE 'UTC') ELSE last_succeeded_at END,
        last_status          = ${outcome},
        last_error           = ${error ?? null},
        last_duration_ms     = ${Math.round(durationMs)}::int,
        run_count            = run_count + 1,
        consecutive_failures = CASE WHEN ${outcome} = 'FAILED'
                                    THEN consecutive_failures + 1 ELSE 0 END,
        updated_at           = (now() AT TIME ZONE 'UTC')
      WHERE name = ${name} AND locked_by = ${holder}
    `;
    return updated === 1;
  }

  /** Gives back every lease this instance holds — on shutdown. */
  async releaseAll(holder: string): Promise<number> {
    return this.prisma.$executeRaw`
      UPDATE scheduled_job_states
         SET locked_by = NULL, locked_until = NULL, last_status = 'FAILED',
             last_error = 'interrupted by shutdown',
             updated_at = (now() AT TIME ZONE 'UTC')
       WHERE locked_by = ${holder}
    `;
  }

  async all(): Promise<ScheduledJobState[]> {
    return this.prisma.scheduledJobState.findMany({ orderBy: { name: 'asc' } });
  }

  async one(name: string): Promise<ScheduledJobState | null> {
    return this.prisma.scheduledJobState.findUnique({ where: { name } });
  }
}
