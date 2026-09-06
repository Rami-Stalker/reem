import { Injectable, Logger } from '@nestjs/common';
import {
  Prisma,
  TrendEngineRun,
  TrendRunKind,
  TrendRunStatus,
} from '@prisma/client';
import { PrismaService } from '../../../prisma/prisma.service';

/**
 * Bookkeeping for the engine's own jobs.
 *
 * Every stage of the nightly run opens a row here and closes it. It costs one
 * insert and one update a night, and it buys the three questions an operator
 * actually asks when a dashboard looks wrong: did last night's run finish, how
 * long did it take, and what did it write. Without it the honest answer is
 * "read the container logs, if they are still there".
 *
 * `fail()` never rethrows and never lets a bookkeeping problem mask the real
 * one — the caller's error is what should reach the log.
 */
@Injectable()
export class TrendRunRecorder {
  private readonly logger = new Logger(TrendRunRecorder.name);

  constructor(private readonly prisma: PrismaService) {}

  async start(
    kind: TrendRunKind,
    options: {
      fromDay?: Date | null;
      toDay?: Date | null;
      triggeredBy?: string | null;
    } = {},
  ): Promise<TrendEngineRun> {
    return this.prisma.trendEngineRun.create({
      data: {
        kind,
        status: TrendRunStatus.RUNNING,
        fromDay: options.fromDay ?? null,
        toDay: options.toDay ?? null,
        triggeredBy: options.triggeredBy ?? null,
      },
    });
  }

  async succeed(
    run: TrendEngineRun,
    rowsWritten: number,
    stats?: Record<string, unknown>,
  ): Promise<void> {
    const finishedAt = new Date();
    await this.prisma.trendEngineRun.update({
      where: { id: run.id },
      data: {
        status: TrendRunStatus.SUCCEEDED,
        finishedAt,
        durationMs: finishedAt.getTime() - run.startedAt.getTime(),
        rowsWritten,
        stats: (stats ?? undefined) as Prisma.InputJsonValue | undefined,
      },
    });
    this.logger.log(
      `${run.kind} finished: ${rowsWritten} rows in ${
        finishedAt.getTime() - run.startedAt.getTime()
      }ms`,
    );
  }

  async fail(run: TrendEngineRun, error: unknown): Promise<void> {
    const finishedAt = new Date();
    const message = error instanceof Error ? error.message : String(error);
    this.logger.error(`${run.kind} failed: ${message}`);
    try {
      await this.prisma.trendEngineRun.update({
        where: { id: run.id },
        data: {
          status: TrendRunStatus.FAILED,
          finishedAt,
          durationMs: finishedAt.getTime() - run.startedAt.getTime(),
          error: message.slice(0, 2000),
        },
      });
    } catch (bookkeeping) {
      // Losing the marker is a nuisance; masking the real failure is not.
      this.logger.error(
        'Could not record the failed run',
        bookkeeping instanceof Error ? bookkeeping.stack : String(bookkeeping),
      );
    }
  }

  /** The most recent run of each kind — the ops panel's whole content. */
  async recent(limit = 20): Promise<TrendEngineRun[]> {
    return this.prisma.trendEngineRun.findMany({
      orderBy: { startedAt: 'desc' },
      take: Math.min(Math.max(limit, 1), 100),
    });
  }

  /** True when a run of this kind is already in flight. */
  async isRunning(kind: TrendRunKind): Promise<boolean> {
    const running = await this.prisma.trendEngineRun.findFirst({
      where: { kind, status: TrendRunStatus.RUNNING },
      select: { id: true, startedAt: true },
      orderBy: { startedAt: 'desc' },
    });
    if (!running) return false;
    // A run that has been "running" for over an hour is a crashed process, not
    // a busy one; without this the engine would lock itself out permanently
    // after a single container kill.
    const stale = Date.now() - running.startedAt.getTime() > 3_600_000;
    if (stale) {
      await this.prisma.trendEngineRun.update({
        where: { id: running.id },
        data: {
          status: TrendRunStatus.FAILED,
          error: 'Abandoned — the process did not finish the run.',
          finishedAt: new Date(),
        },
      });
      return false;
    }
    return true;
  }
}
