import { Module } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { PricingModule } from '../pricing/pricing.module';
import { SignalCollectorService } from './collection/signal-collector.service';
import { TrendRunRecorder } from './collection/trend-run.recorder';
import { TrendSignalService } from './collection/trend-signal.service';
import { AdminTrendsService } from './dashboards/admin-trends.service';
import { SellerTrendsService } from './dashboards/seller-trends.service';
import { TrendForecastService } from './forecasting/trend-forecast.service';
import { AnthropicTrendLlm } from './insights/llm/anthropic-trend-llm';
import { DisabledTrendLlm, TREND_LLM, TrendLlm } from './insights/llm/trend-llm';
import { TrendInsightsService } from './insights/trend-insights.service';
import { TrendScoringService } from './scoring/trend-scoring.service';
import { SearchIntelligenceService } from './search/search-intelligence.service';
import { TrendsController } from './trends.controller';
import { TrendsOrchestrator } from './trends.orchestrator';
import { TrendsScheduler } from './trends.scheduler';

/**
 * Ohara Trend Engine.
 *
 * Sits inside the existing API rather than beside it: same Nest process, same
 * Prisma client, same guards, same `PricingModule` for currency. There is no
 * separate analytics backend to deploy, secure, keep in sync or explain — the
 * engine reads the tables the platform already writes and adds ten of its own.
 *
 * ── The layering, which is the whole design ─────────────────────────────
 *
 *   `collection/`  raw activity → daily facts. The only layer that ever sees a
 *                  user id, and the only one that enforces k-anonymity.
 *   `kernel/`      pure functions. No database, no clock, no network, no model.
 *                  Every number a dashboard prints is produced here and is
 *                  re-derivable from the rows a month later.
 *   `scoring/`     `kernel/trend-score` applied across the catalogue.
 *   `forecasting/` `kernel/forecast` applied to the same facts.
 *   `search/`      what she asked for and whether the catalogue could answer.
 *   `insights/`    rules fire on the numbers; Arabic templates phrase them;
 *                  Claude, if configured, phrases them better.
 *   `dashboards/`  read-only assembly of pre-computed rows.
 *
 * ── Where an ML model attaches ──────────────────────────────────────────
 *
 * Three seams, all already load-bearing rather than aspirational:
 *
 *  - **Ranking.** `ProductTrendScore.method` records which kernel wrote a row.
 *    A learned ranker becomes a second writer with a different `method`, and
 *    the two can be compared on the same days before anything is switched.
 *  - **Forecasting.** `TrendForecastMethod.MODEL` already exists in the enum.
 *    A predictor implements `ForecastResult` and `TrendForecastService` stops
 *    caring which arithmetic produced the points.
 *  - **Narration.** `TREND_LLM` below. The seam takes finished findings and
 *    returns prose, and never the other way round.
 *
 * The binding is the whole configuration story: with `TREND_LLM_PROVIDER`
 * unset — the default — insights are phrased by the Arabic templates and every
 * path runs deterministically. Setting it to `anthropic` with a key swaps in
 * the HTTP client, and nothing else in the module changes.
 */
@Module({
  imports: [PricingModule],
  controllers: [TrendsController],
  providers: [
    // Collection
    SignalCollectorService,
    TrendSignalService,
    TrendRunRecorder,
    // Analysis
    TrendScoringService,
    TrendForecastService,
    SearchIntelligenceService,
    TrendInsightsService,
    // Read side
    SellerTrendsService,
    AdminTrendsService,
    // Jobs
    TrendsOrchestrator,
    TrendsScheduler,
    {
      provide: TREND_LLM,
      inject: [ConfigService],
      useFactory: (config: ConfigService): TrendLlm => {
        const provider = config.get<string>('trends.llm.provider') ?? 'none';
        const apiKey = config.get<string>('trends.llm.apiKey') ?? '';

        // A provider named without a key is a misconfiguration, not a request
        // to fail: the template path is a complete implementation, so the
        // engine stays up and the operator sees an unconfigured provider.
        if (provider !== 'anthropic' || !apiKey) return new DisabledTrendLlm();

        return new AnthropicTrendLlm({
          apiKey,
          baseUrl:
            config.get<string>('trends.llm.baseUrl') ?? 'https://api.anthropic.com',
          model: config.get<string>('trends.llm.model') ?? 'claude-sonnet-5',
          timeoutMs: config.get<number>('trends.llm.timeoutMs') ?? 20_000,
          maxOutputTokens: config.get<number>('trends.llm.maxOutputTokens') ?? 4096,
          batchSize: config.get<number>('trends.llm.batchSize') ?? 8,
        });
      },
    },
  ],
  /**
   * `TrendSignalService` is the only export, and that is the point: other
   * modules *write* signals and never read analysis. Search, cart, favourites
   * and products depend on a thin fire-and-forget recorder rather than on the
   * engine, so nothing on a request path can be slowed or broken by it.
   */
  exports: [TrendSignalService, TrendsOrchestrator],
})
export class TrendsModule {}
