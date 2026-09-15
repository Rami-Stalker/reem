import {
  BeforeApplicationShutdown,
  Injectable,
  Logger,
  OnApplicationBootstrap,
} from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { DiscoveryService, MetadataScanner, Reflector } from '@nestjs/core';
import { ScheduledJobState } from '@prisma/client';
import { CronJob } from 'cron';
import { randomUUID } from 'node:crypto';
import { hostname } from 'node:os';
import { JobLeaseRepository, JobTrigger } from './job-lease.repository';
import { SCHEDULED_JOB, ScheduledJobMetadata } from './scheduled-job.decorator';

const DEFAULT_LEASE_SECONDS = 120;
/**
 * A short pause after boot before overdue sweeps run: long enough for the
 * request that woke the process to be answered first, short enough that stock
 * held by an abandoned order is back on the shelf within seconds.
 */
const CATCH_UP_DELAY_MS = 15_000;
/** What a host gives a stopping process is usually 30 s; leave it room to exit. */
const SHUTDOWN_WAIT_MS = 20_000;

export type RunResult =
  | { status: 'succeeded' | 'failed'; durationMs: number }
  | { status: 'skipped'; reason: 'held' | 'running' | 'shutting-down' | 'unavailable' };

interface RegisteredJob {
  meta: ScheduledJobMetadata;
  invoke: () => Promise<unknown>;
  timer?: CronJob;
  /** Set while this instance runs the job. */
  running?: Promise<RunResult>;
}

export interface JobReport {
  name: string;
  cron: string;
  critical: boolean;
  last_status: string | null;
  last_trigger: string | null;
  last_started_at: string | null;
  last_succeeded_at: string | null;
  last_duration_ms: number | null;
  consecutive_failures: number;
  running: boolean;
  overdue: boolean;
}

/**
 * Runs every `@ScheduledJob`, one instance at a time.
 *
 * **Why not `ScheduleModule`.** `@nestjs/schedule` starts a timer per job in
 * every process that imports it, so a second instance — including the new
 * container a zero-downtime deploy starts beside the old one — ran every sweep
 * twice. Some sweeps tolerate that; notification campaigns, the exchange-rate
 * sync and the escrow flag race do not. This runner takes a lease in
 * `scheduled_job_states` before each run instead, so any number of instances
 * may schedule a job and exactly one runs each tick.
 *
 * **What it adds.** A record of every run (`/health/jobs` reads it), UTC
 * schedules regardless of the host's zone, catch-up of overdue sweeps after a
 * restart or a sleep, an entry point for a manual or external trigger, and a shutdown
 * that stops taking new runs and waits for the ones in flight.
 *
 * `SCHEDULER_ENABLED=false` keeps the timers off on an instance (the jobs are
 * still discovered, so the health report and the trigger work).
 */
@Injectable()
export class JobRunner implements OnApplicationBootstrap, BeforeApplicationShutdown {
  private readonly logger = new Logger(JobRunner.name);
  private readonly jobs = new Map<string, RegisteredJob>();
  private readonly holder = `${hostname()}:${process.pid}:${randomUUID().slice(0, 8)}`;
  private shuttingDown = false;
  private readonly bootedAt = Date.now();
  private catchUpTimer?: NodeJS.Timeout;

  constructor(
    private readonly discovery: DiscoveryService,
    private readonly scanner: MetadataScanner,
    private readonly reflector: Reflector,
    private readonly leases: JobLeaseRepository,
    private readonly config: ConfigService,
  ) {}

  get schedulingHere(): boolean {
    return this.config.get<boolean>('scheduler.enabled') ?? true;
  }

  onApplicationBootstrap(): void {
    this.discover();
    if (!this.schedulingHere) {
      this.logger.log(
        `${this.jobs.size} scheduled jobs discovered; timers OFF on this instance (SCHEDULER_ENABLED=false)`,
      );
      return;
    }
    for (const job of this.jobs.values()) {
      job.timer = CronJob.from({
        cronTime: job.meta.cron,
        timeZone: 'UTC',
        start: true,
        onTick: () => {
          void this.run(job.meta.name, 'schedule');
        },
      });
    }
    this.logger.log(
      `${this.jobs.size} scheduled jobs running under leases as ${this.holder}`,
    );
    this.catchUpTimer = setTimeout(() => void this.catchUp(), CATCH_UP_DELAY_MS);
    this.catchUpTimer.unref();
  }

  async beforeApplicationShutdown(): Promise<void> {
    this.shuttingDown = true;
    if (this.catchUpTimer) clearTimeout(this.catchUpTimer);
    for (const job of this.jobs.values()) void job.timer?.stop();

    const inFlight = [...this.jobs.values()]
      .map((job) => job.running)
      .filter((run): run is Promise<RunResult> => Boolean(run));
    if (inFlight.length > 0) {
      this.logger.log(`Waiting for ${inFlight.length} running job(s) before shutdown`);
      await Promise.race([
        Promise.allSettled(inFlight),
        new Promise((resolve) => setTimeout(resolve, SHUTDOWN_WAIT_MS).unref()),
      ]);
    }
    // Anything still running is abandoned with the process; give its lease
    // back now rather than making the next instance wait it out.
    try {
      await this.leases.releaseAll(this.holder);
    } catch {
      // The database may be what is going away. The lease expires on its own.
    }
  }

  /** Names of every discovered job. */
  names(): string[] {
    return [...this.jobs.keys()].sort();
  }

  has(name: string): boolean {
    return this.jobs.has(name);
  }

  /**
   * Runs one job now, if this instance can take its lease.
   *
   * Never throws: a job that fails is logged and recorded, and the caller —
   * a timer, the catch-up pass, the trigger endpoint — has nothing useful to
   * do with the exception.
   */
  async run(name: string, trigger: JobTrigger): Promise<RunResult> {
    const job = this.jobs.get(name);
    if (!job) return { status: 'skipped', reason: 'unavailable' };
    if (this.shuttingDown) return { status: 'skipped', reason: 'shutting-down' };
    if (job.running) return { status: 'skipped', reason: 'running' };

    const run = this.execute(job, trigger);
    job.running = run;
    try {
      return await run;
    } finally {
      job.running = undefined;
    }
  }

  /** The run record of every job, joined with what this instance knows. */
  async report(): Promise<JobReport[]> {
    const states = new Map((await this.leases.all()).map((s) => [s.name, s]));
    const now = Date.now();
    return [...this.jobs.values()]
      .sort((a, b) => a.meta.name.localeCompare(b.meta.name))
      .map(({ meta, running }) => {
        const state = states.get(meta.name);
        return {
          name: meta.name,
          cron: meta.cron,
          critical: Boolean(meta.critical),
          last_status: state?.lastStatus ?? null,
          last_trigger: state?.lastTrigger ?? null,
          last_started_at: iso(state?.lastStartedAt),
          last_succeeded_at: iso(state?.lastSucceededAt),
          last_duration_ms: state?.lastDurationMs ?? null,
          consecutive_failures: state?.consecutiveFailures ?? 0,
          running: Boolean(running) || state?.lastStatus === 'RUNNING',
          overdue: isOverdue(meta, state, now, this.bootedAt),
        };
      });
  }

  // ── Internals ───────────────────────────────────────────────────────────

  private discover(): void {
    for (const wrapper of this.discovery.getProviders()) {
      const instance = wrapper.instance as Record<string, unknown> | undefined;
      if (!instance || typeof instance !== 'object' || !wrapper.isDependencyTreeStatic()) {
        continue;
      }
      const prototype = Object.getPrototypeOf(instance);
      if (!prototype) continue;
      for (const method of this.scanner.getAllMethodNames(prototype)) {
        const handler = prototype[method];
        const meta = this.reflector.get<ScheduledJobMetadata | undefined>(
          SCHEDULED_JOB,
          handler,
        );
        if (!meta) continue;
        if (this.jobs.has(meta.name)) {
          throw new Error(`Two scheduled jobs are named ${meta.name}`);
        }
        this.jobs.set(meta.name, {
          meta,
          invoke: () => (instance[method] as () => Promise<unknown>).call(instance),
        });
      }
    }
  }

  private async execute(job: RegisteredJob, trigger: JobTrigger): Promise<RunResult> {
    const { meta } = job;

    if (meta.lease === false) {
      const started = Date.now();
      try {
        await job.invoke();
        return { status: 'succeeded', durationMs: Date.now() - started };
      } catch (error) {
        this.logger.error(`${meta.name} failed: ${describe(error)}`);
        return { status: 'failed', durationMs: Date.now() - started };
      }
    }

    const leaseSeconds = meta.leaseSeconds ?? DEFAULT_LEASE_SECONDS;
    let acquired: boolean;
    try {
      acquired = await this.leases.acquire(meta.name, this.holder, leaseSeconds, trigger);
    } catch (error) {
      // No database, no lease, no run: a job that cannot prove it is alone
      // does not run. The next tick tries again.
      this.logger.warn(`${meta.name} skipped — lease unavailable: ${describe(error)}`);
      return { status: 'skipped', reason: 'unavailable' };
    }
    if (!acquired) return { status: 'skipped', reason: 'held' };

    const heartbeat = setInterval(() => {
      this.leases.renew(meta.name, this.holder, leaseSeconds).then(
        (kept) => {
          if (!kept) {
            this.logger.error(
              `${meta.name} lost its lease while running; another instance may start it`,
            );
          }
        },
        (error) =>
          this.logger.warn(`${meta.name} lease renewal failed: ${describe(error)}`),
      );
    }, Math.max(5, Math.floor(leaseSeconds / 3)) * 1000);
    heartbeat.unref();

    const started = Date.now();
    let outcome: 'SUCCEEDED' | 'FAILED' = 'SUCCEEDED';
    let failure: string | undefined;
    try {
      await job.invoke();
    } catch (error) {
      outcome = 'FAILED';
      failure = describe(error).slice(0, 2000);
      this.logger.error(`${meta.name} failed: ${failure}`);
    } finally {
      clearInterval(heartbeat);
    }

    const durationMs = Date.now() - started;
    try {
      const recorded = await this.leases.finish(
        meta.name,
        this.holder,
        outcome,
        durationMs,
        failure,
      );
      if (!recorded) {
        this.logger.warn(`${meta.name} finished after its lease had been taken over`);
      }
    } catch (error) {
      this.logger.warn(`${meta.name} run could not be recorded: ${describe(error)}`);
    }
    return { status: outcome === 'SUCCEEDED' ? 'succeeded' : 'failed', durationMs };
  }

  /**
   * Runs, one after another, the catch-up jobs that are overdue.
   *
   * Sequential on purpose: a fresh deploy with a week of missed nightlies
   * should not start all of them against the database at once.
   */
  private async catchUp(): Promise<void> {
    let states: Map<string, ScheduledJobState>;
    try {
      states = new Map((await this.leases.all()).map((s) => [s.name, s]));
    } catch (error) {
      this.logger.warn(`Catch-up skipped — job states unreadable: ${describe(error)}`);
      return;
    }
    const now = Date.now();
    const due = [...this.jobs.values()]
      .filter(
        (job) =>
          catchesUp(job.meta) && isDueForCatchUp(job.meta, states.get(job.meta.name), now),
      )
      // Shortest window first: a thirty-minute stock hold matters more than
      // yesterday's reconciliation.
      .sort((a, b) => (a.meta.staleAfterMinutes ?? 0) - (b.meta.staleAfterMinutes ?? 0));
    if (due.length > 0) {
      this.logger.log(`Catching up ${due.length} overdue job(s)`);
    }
    for (const job of due) {
      if (this.shuttingDown) return;
      await this.run(job.meta.name, 'catch-up');
    }
  }
}

/**
 * Whether catch-up should run a job now: it has never succeeded, or not within
 * its window.
 *
 * Deliberately stricter than `isOverdue`, which gives a never-run job the
 * benefit of this process's uptime so a first deploy does not alarm. Catch-up
 * must not: on a host that restarts after every sleep the uptime is always
 * short, and a nightly job that has never run — escrow release, if the instance
 * is always asleep at 02:30 — would otherwise never be caught up at all.
 */
export function isDueForCatchUp(
  meta: Pick<ScheduledJobMetadata, 'staleAfterMinutes'>,
  state: Pick<ScheduledJobState, 'lastSucceededAt'> | undefined,
  now: number,
): boolean {
  if (!meta.staleAfterMinutes) return false;
  const last = state?.lastSucceededAt?.getTime();
  return last === undefined || now - last > meta.staleAfterMinutes * 60_000;
}

/** Catch-up is on for any job with a staleness window, unless it opts out. */
export function catchesUp(meta: Pick<ScheduledJobMetadata, 'catchUp' | 'staleAfterMinutes'>): boolean {
  return meta.catchUp ?? Boolean(meta.staleAfterMinutes);
}

/**
 * No success within `staleAfterMinutes`.
 *
 * A job that has never run is measured from `since` — this instance's start —
 * rather than counted overdue at once: the first deploy against a database
 * has no run records at all, and an alarm for every job in its first minute
 * would teach everyone to ignore the alarm.
 */
export function isOverdue(
  meta: Pick<ScheduledJobMetadata, 'staleAfterMinutes'>,
  state: Pick<ScheduledJobState, 'lastSucceededAt'> | undefined,
  now: number,
  since: number,
): boolean {
  if (!meta.staleAfterMinutes) return false;
  const reference = state?.lastSucceededAt?.getTime() ?? since;
  return now - reference > meta.staleAfterMinutes * 60_000;
}

function iso(value: Date | null | undefined): string | null {
  return value ? value.toISOString() : null;
}

function describe(error: unknown): string {
  return error instanceof Error ? error.message : String(error);
}
