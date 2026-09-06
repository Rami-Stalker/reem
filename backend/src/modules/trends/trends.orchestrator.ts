import { Injectable, Logger } from '@nestjs/common';
import { TrendRunKind, TrendWindow } from '@prisma/client';
import { PrismaService } from '../../prisma/prisma.service';
import { SignalCollectorService } from './collection/signal-collector.service';
import { TrendRunRecorder } from './collection/trend-run.recorder';
import { addDays, utcToday } from './collection/day';
import { TrendForecastService } from './forecasting/trend-forecast.service';
import { TrendInsightsService } from './insights/trend-insights.service';
import { TrendScoringService } from './scoring/trend-scoring.service';
import { SearchIntelligenceService } from './search/search-intelligence.service';
import { RAW_EVENT_RETENTION_DAYS } from './trend.constants';

/**
 * The pipeline, in the one order it can run in.
 *
 * Each stage consumes the previous stage's output, so the sequence is a
 * dependency graph rather than a preference:
 *
 *   collect → score → forecast → search intelligence → insights → prune
 *
 * Scores need facts. Forecasts need facts. Insights need scores *and*
 * forecasts *and* the unmet-demand signals, which is why they are last. The
 * pruner runs at the end because it deletes the raw events the collector had
 * to read first — running it earlier would delete this morning's input.
 *
 * A stage that throws stops the run. That is deliberate: scoring yesterday's
 * facts because today's collection failed would produce a dashboard that looks
 * fresh and is not, and a stale-but-labelled number is far better than a
 * confidently wrong one. The `TrendEngineRun` row from the failed stage says
 * where it stopped.
 */
@Injectable()
export class TrendsOrchestrator {
  private readonly logger = new Logger(TrendsOrchestrator.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly collector: SignalCollectorService,
    private readonly scoring: TrendScoringService,
    private readonly forecasts: TrendForecastService,
    private readonly searchIntel: SearchIntelligenceService,
    private readonly insights: TrendInsightsService,
    private readonly runs: TrendRunRecorder,
  ) {}

  /** True when any stage is already in flight. */
  async isBusy(): Promise<boolean> {
    for (const kind of [
      TrendRunKind.FULL,
      TrendRunKind.DAILY_ROLLUP,
      TrendRunKind.SCORING,
      TrendRunKind.FORECAST,
      TrendRunKind.INSIGHTS,
      TrendRunKind.BACKFILL,
    ]) {
      if (await this.runs.isRunning(kind)) return true;
    }
    return false;
  }

  /**
   * The whole pipeline.
   *
   * `rollupOnly` exists for the case an operator actually has at 9am: the
   * facts look wrong, and re-reading them is the fix. Re-scoring and
   * re-forecasting after that is a second click, not a five-minute wait.
   */
  async runAll(
    options: {
      lookbackDays?: number;
      rollupOnly?: boolean;
      triggeredBy?: string | null;
    } = {},
  ): Promise<{
    rollup: { days: number; rows: number };
    scoring: { products: number; categories: number } | null;
    forecast: { rows: number } | null;
    search: { signals: number; resolved: number } | null;
    insights: { admin: number; seller: number } | null;
    pruned: number;
  }> {
    const triggeredBy = options.triggeredBy ?? null;
    const started = Date.now();

    const rollup = await this.collector.rollup({
      lookbackDays: options.lookbackDays,
      triggeredBy,
    });

    if (options.rollupOnly) {
      this.logger.log(
        `Trend roll-up only: ${rollup.rows} rows in ${Date.now() - started}ms`,
      );
      return {
        rollup,
        scoring: null,
        forecast: null,
        search: null,
        insights: null,
        pruned: 0,
      };
    }

    const scoring = await this.scoring.scoreAll({ triggeredBy });
    const forecast = await this.forecasts.forecastAll({ triggeredBy });
    const search = await this.searchIntel.refresh({ triggeredBy });
    // D7 is what the dashboards open on, so it is the window insights speak
    // about. Generating for all three would triple the feed to say the same
    // thing three times at three speeds.
    const insights = await this.insights.generate({
      window: TrendWindow.D7,
      triggeredBy,
    });
    const pruned = await this.pruneRawEvents(triggeredBy);

    this.logger.log(
      `Trend pipeline finished in ${Date.now() - started}ms — ` +
        `${rollup.rows} facts, ${scoring.products} product scores, ` +
        `${forecast.rows} forecasts, ${search.signals} demand signals, ` +
        `${insights.admin + insights.seller} insights, ${pruned} raw events pruned`,
    );

    return { rollup, scoring, forecast, search, insights, pruned };
  }

  /**
   * Delete raw analytics events past the retention window.
   *
   * This is the privacy half of the engine, and it is a job rather than a
   * policy document. The aggregates are identity-free and permanent; the raw
   * rows carry a user id, a session id and — for a search — the text she
   * typed, and they exist only long enough to be folded into a daily total.
   *
   * Deleted in batches so a first run against a large table does not take a
   * lock for minutes or blow out the transaction log.
   */
  private async pruneRawEvents(triggeredBy: string | null): Promise<number> {
    if (RAW_EVENT_RETENTION_DAYS <= 0) return 0;

    const cutoff = addDays(utcToday(), -RAW_EVENT_RETENTION_DAYS);
    const run = await this.runs.start(TrendRunKind.RETENTION, {
      toDay: cutoff,
      triggeredBy,
    });

    try {
      let deleted = 0;
      // Bounded: a runaway loop here would hold the database all night.
      for (let batch = 0; batch < 200; batch += 1) {
        const ids = await this.prisma.analyticsEvent.findMany({
          where: { occurredAt: { lt: cutoff } },
          select: { id: true },
          take: 5_000,
        });
        if (!ids.length) break;
        const result = await this.prisma.analyticsEvent.deleteMany({
          where: { id: { in: ids.map((row) => row.id) } },
        });
        deleted += result.count;
        if (ids.length < 5_000) break;
      }
      await this.runs.succeed(run, deleted, { cutoff: cutoff.toISOString() });
      return deleted;
    } catch (error) {
      await this.runs.fail(run, error);
      // A failed prune must not fail the night's analysis — the data is
      // already collected and the sweep will run again tomorrow.
      return 0;
    }
  }

  /**
   * Rebuild history from scratch, one day at a time.
   *
   * For the first switch-on, and for after an outage. Not exposed on the HTTP
   * surface: over ninety days this reads the whole order history and is a job
   * to be started deliberately and watched, not something a dashboard button
   * should be able to begin inside a request.
   */
  async backfill(
    days: number,
    options: { triggeredBy?: string | null } = {},
  ): Promise<{ rows: number }> {
    const today = utcToday();
    const from = addDays(today, -(Math.max(1, days) - 1));
    const run = await this.runs.start(TrendRunKind.BACKFILL, {
      fromDay: from,
      toDay: today,
      triggeredBy: options.triggeredBy ?? null,
    });

    try {
      let rows = 0;
      for (let offset = days - 1; offset >= 0; offset -= 1) {
        const day = addDays(today, -offset);
        rows += await this.collector.rollupDay(day);
        if (offset % 10 === 0) {
          this.logger.log(`Backfill: ${days - offset}/${days} days, ${rows} rows`);
        }
      }
      await this.runs.succeed(run, rows, { days });
      return { rows };
    } catch (error) {
      await this.runs.fail(run, error);
      throw error;
    }
  }
}
