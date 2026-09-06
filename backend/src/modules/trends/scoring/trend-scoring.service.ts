import { Injectable, Logger } from '@nestjs/common';
import {
  Prisma,
  TrendRunKind,
  TrendStage,
  TrendWindow,
} from '@prisma/client';
import { PrismaService } from '../../../prisma/prisma.service';
import { TrendRunRecorder } from '../collection/trend-run.recorder';
import { addDays, dayKey, lastDays, utcToday } from '../collection/day';
import { quantile, round } from '../kernel/trend-math';
import {
  CohortContext,
  DemandDay,
  emptyDemandDay,
  rankingScore,
  scoreTrend,
  windowEnum,
} from '../kernel/trend-score';
import { KERNEL_METHOD, SCORED_WINDOWS } from '../trend.constants';

/**
 * Layer 2: the fact tables in, `product_trend_scores` and
 * `category_trend_scores` out.
 *
 * The service's whole job is plumbing — the judgement lives in `scoreTrend`,
 * which is pure and tested. What is *not* trivial, and what this file exists
 * to get right, is three things:
 *
 *  1. **Gaps must become zeros.** A quiet Tuesday writes no fact row, and a
 *     series read straight out of the database would silently shorten by a day
 *     and shift every window comparison. `densify` fills the calendar first.
 *  2. **The cohort has to be computed before anything is classified.** "A
 *     climber off a small base" needs to know what a small base is *this week*,
 *     so the run makes one pass to collect the volume distribution and a second
 *     to score against it.
 *  3. **Ranks are assigned across the cohort, not per row.** A rank is a
 *     statement about a leaderboard, so it can only be written once the whole
 *     leaderboard exists.
 */
@Injectable()
export class TrendScoringService {
  private readonly logger = new Logger(TrendScoringService.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly runs: TrendRunRecorder,
  ) {}

  /**
   * Score everything, for every window, as of `capturedOn` (default today).
   *
   * Idempotent: the unique key is (subject, window, day), so a second run the
   * same day overwrites rather than duplicating.
   */
  async scoreAll(
    options: { capturedOn?: Date; triggeredBy?: string | null } = {},
  ): Promise<{ products: number; categories: number }> {
    const capturedOn = options.capturedOn ?? utcToday();
    const run = await this.runs.start(TrendRunKind.SCORING, {
      fromDay: capturedOn,
      toDay: capturedOn,
      triggeredBy: options.triggeredBy ?? null,
    });

    try {
      let products = 0;
      let categories = 0;
      const stats: Record<string, number> = {};
      for (const windowDays of SCORED_WINDOWS) {
        const p = await this.scoreProducts(capturedOn, windowDays);
        const c = await this.scoreCategories(capturedOn, windowDays);
        stats[`products_d${windowDays}`] = p;
        stats[`categories_d${windowDays}`] = c;
        products += p;
        categories += c;
      }
      await this.runs.succeed(run, products + categories, stats);
      return { products, categories };
    } catch (error) {
      await this.runs.fail(run, error);
      throw error;
    }
  }

  // ── Products ───────────────────────────────────────────────────────────

  private async scoreProducts(
    capturedOn: Date,
    windowDays: number,
  ): Promise<number> {
    // Two windows of history: the kernel compares the second against the first.
    const span = windowDays * 2;
    const days = lastDays(capturedOn, span);
    const from = days[0];

    const facts = await this.prisma.productDemandDaily.findMany({
      where: { day: { gte: from, lte: capturedOn } },
      orderBy: { day: 'asc' },
    });
    if (!facts.length) return 0;

    const byProduct = new Map<
      string,
      { categoryId: string; rows: Map<string, DemandDay> }
    >();
    for (const fact of facts) {
      const entry =
        byProduct.get(fact.productId) ??
        { categoryId: fact.categoryId, rows: new Map<string, DemandDay>() };
      // The newest row wins the category, in case a product was recategorised.
      entry.categoryId = fact.categoryId;
      entry.rows.set(dayKey(fact.day), toDemandDay(fact));
      byProduct.set(fact.productId, entry);
    }

    // Pass one: the cohort's volume distribution, which stage classification
    // is relative to. Only products with any exposure count toward it —
    // including the dead tail would put the median at zero and make every
    // product with one sale look "material".
    const volumes: number[] = [];
    const densified = new Map<string, DemandDay[]>();
    for (const [productId, entry] of byProduct) {
      const series = densify(entry.rows, days);
      densified.set(productId, series);
      const units = series
        .slice(-windowDays)
        .reduce((total, row) => total + row.units, 0);
      const exposure = series
        .slice(-windowDays)
        .reduce((total, row) => total + row.views + row.cartAdds, 0);
      if (exposure > 0) volumes.push(units);
    }
    const cohort: CohortContext = {
      medianUnits: quantile(volumes, 0.5),
      p75Units: quantile(volumes, 0.75),
    };

    // Yesterday's scores, so `delta` and `previousScore` need no second query
    // per row.
    const window = windowEnum(windowDays);
    const previous = await this.previousProductScores(capturedOn, window);

    // Pass two: score, then rank, then write.
    const scored: Array<{
      productId: string;
      categoryId: string;
      result: ReturnType<typeof scoreTrend>;
      ranking: number;
    }> = [];
    for (const [productId, entry] of byProduct) {
      const series = densified.get(productId) ?? [];
      const result = scoreTrend(series, windowDays, cohort);
      // A product with no evidence at all is not worth a row a day forever.
      if (result.sampleSize === 0 && result.score === 0) continue;
      scored.push({
        productId,
        categoryId: entry.categoryId,
        result,
        ranking: rankingScore(result.score, result.confidence),
      });
    }

    scored.sort((a, b) => b.ranking - a.ranking);
    const categoryCounters = new Map<string, number>();

    let written = 0;
    for (let index = 0; index < scored.length; index += 1) {
      const row = scored[index];
      const categoryRank = (categoryCounters.get(row.categoryId) ?? 0) + 1;
      categoryCounters.set(row.categoryId, categoryRank);

      const previousScore = previous.get(row.productId) ?? null;
      const data = {
        categoryId: row.categoryId,
        score: row.result.score,
        previousScore,
        delta: previousScore === null ? 0 : round(row.result.score - previousScore, 2),
        stage: row.result.stage,
        confidence: row.result.confidence,
        sampleSize: row.result.sampleSize,
        ...row.result.components,
        metrics: {
          ...row.result.metrics,
          ranking_score: row.ranking,
        } as unknown as Prisma.InputJsonValue,
        rank: index + 1,
        categoryRank,
        method: KERNEL_METHOD,
      };

      await this.prisma.productTrendScore.upsert({
        where: {
          productId_window_capturedOn: {
            productId: row.productId,
            window,
            capturedOn,
          },
        },
        create: { productId: row.productId, window, capturedOn, ...data },
        update: data,
      });
      written += 1;
    }

    this.logger.log(
      `Scored ${written} products over ${windowDays}d ` +
        `(cohort median ${cohort.medianUnits}, p75 ${cohort.p75Units})`,
    );
    return written;
  }

  // ── Categories ─────────────────────────────────────────────────────────

  private async scoreCategories(
    capturedOn: Date,
    windowDays: number,
  ): Promise<number> {
    const days = lastDays(capturedOn, windowDays * 2);
    const from = days[0];

    const facts = await this.prisma.categoryDemandDaily.findMany({
      where: { day: { gte: from, lte: capturedOn } },
      orderBy: { day: 'asc' },
    });
    if (!facts.length) return 0;

    const byCategory = new Map<string, Map<string, DemandDay>>();
    for (const fact of facts) {
      const rows = byCategory.get(fact.categoryId) ?? new Map<string, DemandDay>();
      rows.set(dayKey(fact.day), {
        ...emptyDemandDay(dayKey(fact.day)),
        views: fact.views,
        searchHits: fact.searchHits,
        cartAdds: fact.cartAdds,
        favorites: fact.favorites,
        orders: fact.orders,
        units: fact.units,
        revenueSyp: Number(fact.revenueSyp),
        returns: fact.returns,
        reviews: fact.reviews,
        ratingSum: fact.ratingSum,
        // A category's "stock" is how much of it is buyable at all.
        stockUnits: fact.inStockProducts,
        inStock: fact.inStockProducts > 0,
      });
      byCategory.set(fact.categoryId, rows);
    }

    const volumes: number[] = [];
    const densified = new Map<string, DemandDay[]>();
    for (const [categoryId, rows] of byCategory) {
      const series = densify(rows, days);
      densified.set(categoryId, series);
      volumes.push(
        series.slice(-windowDays).reduce((total, row) => total + row.units, 0),
      );
    }
    const cohort: CohortContext = {
      medianUnits: quantile(volumes, 0.5),
      p75Units: quantile(volumes, 0.75),
    };

    const window = windowEnum(windowDays);
    const previous = await this.previousCategoryScores(capturedOn, window);

    const scored: Array<{
      categoryId: string;
      result: ReturnType<typeof scoreTrend>;
      ranking: number;
    }> = [];
    for (const [categoryId, series] of densified) {
      const result = scoreTrend(series, windowDays, cohort);
      scored.push({
        categoryId,
        result,
        ranking: rankingScore(result.score, result.confidence),
      });
    }
    scored.sort((a, b) => b.ranking - a.ranking);

    let written = 0;
    for (let index = 0; index < scored.length; index += 1) {
      const row = scored[index];
      const previousScore = previous.get(row.categoryId) ?? null;
      const data = {
        score: row.result.score,
        previousScore,
        delta: previousScore === null ? 0 : round(row.result.score - previousScore, 2),
        stage: row.result.stage,
        confidence: row.result.confidence,
        sampleSize: row.result.sampleSize,
        ...row.result.components,
        metrics: {
          ...row.result.metrics,
          ranking_score: row.ranking,
        } as unknown as Prisma.InputJsonValue,
        rank: index + 1,
        method: KERNEL_METHOD,
      };
      await this.prisma.categoryTrendScore.upsert({
        where: {
          categoryId_window_capturedOn: {
            categoryId: row.categoryId,
            window,
            capturedOn,
          },
        },
        create: { categoryId: row.categoryId, window, capturedOn, ...data },
        update: data,
      });
      written += 1;
    }
    return written;
  }

  // ── Previous capture ───────────────────────────────────────────────────

  /**
   * The last score each product carried *before* today.
   *
   * Reads a week back rather than exactly yesterday, so a missed nightly run
   * leaves a stale comparison rather than silently resetting every delta on
   * the platform to zero.
   */
  private async previousProductScores(
    capturedOn: Date,
    window: TrendWindow,
  ): Promise<Map<string, number>> {
    const rows = await this.prisma.productTrendScore.findMany({
      where: {
        window,
        capturedOn: { gte: addDays(capturedOn, -7), lt: capturedOn },
      },
      select: { productId: true, score: true, capturedOn: true },
      orderBy: { capturedOn: 'asc' },
    });
    // Ascending, so the last write per product is the most recent capture.
    const latest = new Map<string, number>();
    for (const row of rows) latest.set(row.productId, row.score);
    return latest;
  }

  private async previousCategoryScores(
    capturedOn: Date,
    window: TrendWindow,
  ): Promise<Map<string, number>> {
    const rows = await this.prisma.categoryTrendScore.findMany({
      where: {
        window,
        capturedOn: { gte: addDays(capturedOn, -7), lt: capturedOn },
      },
      select: { categoryId: true, score: true },
      orderBy: { capturedOn: 'asc' },
    });
    const latest = new Map<string, number>();
    for (const row of rows) latest.set(row.categoryId, row.score);
    return latest;
  }
}

// ── Helpers ──────────────────────────────────────────────────────────────

/**
 * Turn a sparse map of days into a complete calendar.
 *
 * The bug this prevents is quiet and expensive: a product with rows on four of
 * the last fourteen days would otherwise be handed to the kernel as a
 * four-element series, `splitWindows` would take two as "this week" and two as
 * "last week", and its growth would be computed between two arbitrary
 * Tuesdays. Filling the gaps makes a quiet day mean zero, which is what it is.
 */
export function densify(
  rows: Map<string, DemandDay>,
  days: readonly Date[],
): DemandDay[] {
  let lastStock = 0;
  return days.map((date) => {
    const key = dayKey(date);
    const row = rows.get(key);
    if (row) {
      lastStock = row.stockUnits;
      return row;
    }
    // Stock carries forward across a gap — it did not become zero just because
    // nothing happened — while every flow measure is genuinely zero.
    return { ...emptyDemandDay(key), stockUnits: lastStock, inStock: lastStock > 0 };
  });
}

/** The Prisma row, in the shape the kernel takes. */
export function toDemandDay(fact: {
  day: Date;
  views: number;
  searchHits: number;
  cartAdds: number;
  favorites: number;
  wishlistAdds: number;
  shares: number;
  contentEngagements: number;
  orders: number;
  units: number;
  revenueSyp: Prisma.Decimal;
  returns: number;
  reviews: number;
  ratingSum: number;
  stockUnits: number;
  inStock: boolean;
}): DemandDay {
  return {
    day: dayKey(fact.day),
    views: fact.views,
    searchHits: fact.searchHits,
    cartAdds: fact.cartAdds,
    favorites: fact.favorites,
    wishlistAdds: fact.wishlistAdds,
    shares: fact.shares,
    contentEngagements: fact.contentEngagements,
    orders: fact.orders,
    units: fact.units,
    revenueSyp: Number(fact.revenueSyp),
    returns: fact.returns,
    reviews: fact.reviews,
    ratingSum: fact.ratingSum,
    stockUnits: fact.stockUnits,
    inStock: fact.inStock,
  };
}

export { TrendStage };
