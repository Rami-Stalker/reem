import { Injectable, Logger } from '@nestjs/common';
import { ValueCollectorService } from '../../../../backend/src/modules/value/value-collector.service';
import { JobProgressRepository } from './job-progress.repository';

/**
 * `ValueCollectorService.sweep`, in slices that fit an edge invocation.
 *
 * On a server the half-hourly sweep reads seven evidence sources and then
 * recomputes every woman they touched, in one call. Measured on Supabase, that
 * single call needs more than the 2 s of CPU an Edge Function invocation is
 * allowed (`WORKER_RESOURCE_LIMIT`). The work itself is the backend's: each
 * source is the backend's own method and each recompute is
 * `ValueScoringService.recompute`. What changes is only the orchestration —
 * one source or a handful of recomputes per invocation, with the position
 * saved in `reem_supabase.job_progress`, so the next pg_cron tick (every
 * minute while a sweep is unfinished) carries on where this one stopped.
 *
 * The seven source names mirror `ValueCollectorService.sweep`; a renamed or
 * added source fails loudly here rather than being silently skipped.
 */
const SOURCES = [
  ['reliability', 'sweepReliability', 'since'],
  ['commerce', 'sweepCommerce', 'since'],
  ['craft', 'sweepCraft', 'since'],
  ['community', 'sweepCommunity', 'since'],
  ['advocacy', 'sweepAdvocacy', 'since'],
  ['discovery', 'sweepDiscovery', 'now'],
  ['reversals', 'sweepReversals', 'since'],
] as const;

const WINDOW_DAYS = 45;
const JOB = 'value.collect';

interface SweepState {
  phase: 'sources' | 'recompute';
  now: string;
  since: string;
  step: number;
  touched: string[];
  cursor: number;
  counts: Record<string, number>;
  /** Which unit the last invocation started, and how many times in a row. */
  unit?: string;
  attempts?: number;
}

/** A unit that kills its isolate this many times in a row is skipped. */
const MAX_ATTEMPTS = 3;

type Callable = (arg: Date) => Promise<string[]>;

@Injectable()
export class EdgeValueCollectorService extends ValueCollectorService {
  private readonly edgeLogger = new Logger('EdgeValueCollector');

  private get budgetMs(): number {
    return Number(process.env.REEM_JOB_SLICE_MS ?? '600');
  }

  override async sweep(options: { now?: Date } = {}): Promise<Record<string, number>> {
    const progress = this.progress();
    const startedAt = Date.now();
    const claimed = await progress.acquire<SweepState>(JOB, 90);
    if (claimed === 'busy') return { in_progress: 1, busy: 1 };
    let state = claimed ?? this.fresh(options.now ?? new Date());

    // At least one unit per invocation, however slow the first read was.
    do {
      const unitStartedAt = Date.now();
      const cpuBefore = process.env.REEM_JOB_DEBUG === 'true' ? process.cpuUsage() : null;

      // Record the attempt before doing the work: an isolate killed for CPU
      // mid-unit leaves this behind, and the third such kill skips the unit
      // instead of stopping the sweep for good.
      const unit = `${state.phase}:${state.phase === 'sources' ? state.step : state.cursor}`;
      state.attempts = state.unit === unit ? (state.attempts ?? 0) + 1 : 1;
      state.unit = unit;
      if (state.attempts > MAX_ATTEMPTS) {
        this.edgeLogger.warn(`Value sweep unit ${unit} exceeded the edge CPU budget ${MAX_ATTEMPTS} times; skipped`);
        if (state.phase === 'sources') {
          state.counts[SOURCES[state.step][0]] = -2;
          state.step += 1;
          if (state.step >= SOURCES.length) state.phase = 'recompute';
        } else {
          state.cursor += 1;
        }
        state.attempts = 0;
        state.unit = undefined;
        await progress.save(JOB, state);
        continue;
      }
      await progress.save(JOB, state);

      if (state.phase === 'sources') {
        const [name, method, argument] = SOURCES[state.step];
        const run = (this as unknown as Record<string, Callable>)[method];
        if (typeof run !== 'function') {
          throw new Error(`ValueCollectorService.${method} no longer exists; update EdgeValueCollectorService`);
        }
        try {
          const users = await run.call(this, new Date(argument === 'now' ? state.now : state.since));
          state.counts[name] = users.length;
          state.touched = [...new Set([...state.touched, ...users])];
        } catch (error) {
          this.edgeLogger.warn(`Value sweep source ${name} failed: ${String(error)}`);
          state.counts[name] = -1;
        }
        state.step += 1;
        if (state.step >= SOURCES.length) state.phase = 'recompute';
      } else {
        if (state.cursor >= state.touched.length) {
          await progress.clear(JOB);
          const counts = { ...state.counts, recomputed: state.touched.length };
          this.edgeLogger.log(`Value sweep complete: ${JSON.stringify(counts)}`);
          return counts;
        }
        const userId = state.touched[state.cursor];
        try {
          await this.scoringService().recompute(userId, { now: new Date(state.now) });
        } catch (error) {
          this.edgeLogger.warn(`Value recompute failed for ${userId}: ${String(error)}`);
        }
        state.cursor += 1;
      }
      await progress.save(JOB, state);
      if (cpuBefore) {
        const cpu = process.cpuUsage(cpuBefore);
        this.edgeLogger.log(
          `unit ${state.phase}:${state.step}/${state.cursor} ${Date.now() - unitStartedAt}ms wall, ${Math.round((cpu.user + cpu.system) / 1000)}ms cpu`,
        );
      }
    } while (Date.now() - startedAt < this.budgetMs);

    await progress.release(JOB);
    return {
      ...state.counts,
      in_progress: 1,
      recomputed: state.cursor,
      remaining: state.phase === 'sources' ? -1 : state.touched.length - state.cursor,
    };
  }

  private fresh(now: Date): SweepState {
    return {
      phase: 'sources',
      now: now.toISOString(),
      since: new Date(now.getTime() - WINDOW_DAYS * 86_400_000).toISOString(),
      step: 0,
      touched: [],
      cursor: 0,
      counts: {},
    };
  }

  private scoringService() {
    return (this as unknown as { scoring: { recompute(userId: string, options: { now: Date }): Promise<unknown> } })
      .scoring;
  }

  private progress(): JobProgressRepository {
    return new JobProgressRepository((this as unknown as { prisma: ConstructorParameters<typeof JobProgressRepository>[0] }).prisma);
  }
}
