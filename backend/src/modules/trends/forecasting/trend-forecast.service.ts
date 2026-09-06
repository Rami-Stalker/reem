import { Injectable, Logger } from '@nestjs/common';
import {
  Prisma,
  TrendRunKind,
  TrendSubjectKind,
} from '@prisma/client';
import { PrismaService } from '../../../prisma/prisma.service';
import { TrendRunRecorder } from '../collection/trend-run.recorder';
import { addDays, dayKey, lastDays, utcToday } from '../collection/day';
import { ForecastResult, forecast, stockoutInDays } from '../kernel/forecast';
import { round, sum } from '../kernel/trend-math';
import {
  FORECAST_HORIZONS,
  PLATFORM_SCOPE,
} from '../trend.constants';

/**
 * Layer 3: how much will sell, and when the shelf runs out.
 *
 * Three subjects are forecast, and each answers a different person's question:
 *
 *  - **seller × product** — the number a seller restocks against. Scoped to
 *    her, because platform demand for a product she shares with two other
 *    sellers is not her demand.
 *  - **product** — the platform view, for merchandising and for the admin
 *    demand chart.
 *  - **platform** — one line for the whole business.
 *
 * The horizon set is fixed rather than requested: pre-computing three horizons
 * a night is cheap and makes every dashboard read a row instead of fitting a
 * model, which is the difference between a page that opens instantly at any
 * traffic level and one that does not.
 *
 * How far back it reads is `HISTORY_DAYS` — ninety days, which gives Holt
 * roughly thirteen observations of each weekday. Less and the weekday index is
 * noise; more and the fit starts defending a season that has ended.
 */
const HISTORY_DAYS = 90;

/**
 * Only forecast a seller-product pair with real history. Below this the
 * arithmetic still runs and still returns a defensible flat line, but writing
 * a row a night for every dormant listing on the platform would grow the
 * table by the size of the catalogue rather than by the size of the business.
 */
const MIN_UNITS_TO_FORECAST = 3;

@Injectable()
export class TrendForecastService {
  private readonly logger = new Logger(TrendForecastService.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly runs: TrendRunRecorder,
  ) {}

  async forecastAll(
    options: { generatedOn?: Date; triggeredBy?: string | null } = {},
  ): Promise<{ rows: number }> {
    const generatedOn = options.generatedOn ?? utcToday();
    const run = await this.runs.start(TrendRunKind.FORECAST, {
      fromDay: generatedOn,
      toDay: generatedOn,
      triggeredBy: options.triggeredBy ?? null,
    });

    try {
      const days = lastDays(generatedOn, HISTORY_DAYS);
      const start = days[0];

      const sellerRows = await this.forecastSellerProducts(generatedOn, days, start);
      const productRows = await this.forecastProducts(generatedOn, days, start);
      const platformRows = await this.forecastPlatform(generatedOn, days, start);

      const rows = sellerRows + productRows + platformRows;
      await this.runs.succeed(run, rows, {
        seller_products: sellerRows,
        products: productRows,
        platform: platformRows,
      });
      return { rows };
    } catch (error) {
      await this.runs.fail(run, error);
      throw error;
    }
  }

  // ── seller × product ───────────────────────────────────────────────────

  private async forecastSellerProducts(
    generatedOn: Date,
    days: readonly Date[],
    start: Date,
  ): Promise<number> {
    const facts = await this.prisma.sellerDemandDaily.findMany({
      where: { day: { gte: start, lte: generatedOn } },
      select: {
        sellerId: true,
        productId: true,
        day: true,
        units: true,
        revenueSyp: true,
        stockUnits: true,
      },
      orderBy: { day: 'asc' },
    });
    if (!facts.length) return 0;

    interface Series {
      units: Map<string, number>;
      revenue: number;
      unitTotal: number;
      stockUnits: number;
    }
    const grouped = new Map<string, Series>();
    for (const fact of facts) {
      const key = `${fact.sellerId}:${fact.productId}`;
      const entry =
        grouped.get(key) ??
        ({ units: new Map(), revenue: 0, unitTotal: 0, stockUnits: 0 } satisfies Series);
      entry.units.set(dayKey(fact.day), fact.units);
      entry.revenue += Number(fact.revenueSyp);
      entry.unitTotal += fact.units;
      // The last day in the ascending scan is the current stock reading.
      entry.stockUnits = fact.stockUnits;
      grouped.set(key, entry);
    }

    let written = 0;
    for (const [key, entry] of grouped) {
      if (entry.unitTotal < MIN_UNITS_TO_FORECAST) continue;
      const [sellerId, productId] = key.split(':');
      if (!sellerId || !productId) continue;

      const values = days.map((day) => entry.units.get(dayKey(day)) ?? 0);
      // Revenue per unit over the whole history, so the money projection
      // follows the units instead of being forecast separately and drifting
      // out of agreement with them.
      const pricePerUnit = entry.unitTotal > 0 ? entry.revenue / entry.unitTotal : 0;

      for (const horizon of FORECAST_HORIZONS) {
        const result = forecast({ values, startDate: days[0], horizonDays: horizon });
        await this.write({
          subjectKind: TrendSubjectKind.PRODUCT,
          subjectKey: productId,
          scopeKey: sellerId,
          generatedOn,
          horizonDays: horizon,
          result,
          pricePerUnit,
          stockUnits: entry.stockUnits,
        });
        written += 1;
      }
    }
    return written;
  }

  // ── product, across every seller ───────────────────────────────────────

  private async forecastProducts(
    generatedOn: Date,
    days: readonly Date[],
    start: Date,
  ): Promise<number> {
    const facts = await this.prisma.productDemandDaily.findMany({
      where: { day: { gte: start, lte: generatedOn } },
      select: {
        productId: true,
        day: true,
        units: true,
        revenueSyp: true,
        stockUnits: true,
      },
      orderBy: { day: 'asc' },
    });
    if (!facts.length) return 0;

    const grouped = new Map<
      string,
      { units: Map<string, number>; revenue: number; unitTotal: number; stockUnits: number }
    >();
    for (const fact of facts) {
      const entry =
        grouped.get(fact.productId) ??
        { units: new Map<string, number>(), revenue: 0, unitTotal: 0, stockUnits: 0 };
      entry.units.set(dayKey(fact.day), fact.units);
      entry.revenue += Number(fact.revenueSyp);
      entry.unitTotal += fact.units;
      entry.stockUnits = fact.stockUnits;
      grouped.set(fact.productId, entry);
    }

    let written = 0;
    for (const [productId, entry] of grouped) {
      if (entry.unitTotal < MIN_UNITS_TO_FORECAST) continue;
      const values = days.map((day) => entry.units.get(dayKey(day)) ?? 0);
      const pricePerUnit = entry.unitTotal > 0 ? entry.revenue / entry.unitTotal : 0;

      for (const horizon of FORECAST_HORIZONS) {
        const result = forecast({ values, startDate: days[0], horizonDays: horizon });
        await this.write({
          subjectKind: TrendSubjectKind.PRODUCT,
          subjectKey: productId,
          scopeKey: PLATFORM_SCOPE,
          generatedOn,
          horizonDays: horizon,
          result,
          pricePerUnit,
          stockUnits: entry.stockUnits,
        });
        written += 1;
      }
    }
    return written;
  }

  // ── the whole business ─────────────────────────────────────────────────

  private async forecastPlatform(
    generatedOn: Date,
    days: readonly Date[],
    start: Date,
  ): Promise<number> {
    const facts = await this.prisma.productDemandDaily.groupBy({
      by: ['day'],
      where: { day: { gte: start, lte: generatedOn } },
      _sum: { units: true, revenueSyp: true },
    });
    if (!facts.length) return 0;

    const unitsByDay = new Map<string, number>();
    let revenue = 0;
    let unitTotal = 0;
    for (const fact of facts) {
      unitsByDay.set(dayKey(fact.day), fact._sum.units ?? 0);
      revenue += Number(fact._sum.revenueSyp ?? 0);
      unitTotal += fact._sum.units ?? 0;
    }
    const values = days.map((day) => unitsByDay.get(dayKey(day)) ?? 0);
    const pricePerUnit = unitTotal > 0 ? revenue / unitTotal : 0;

    let written = 0;
    for (const horizon of FORECAST_HORIZONS) {
      const result = forecast({ values, startDate: days[0], horizonDays: horizon });
      await this.write({
        subjectKind: TrendSubjectKind.PLATFORM,
        subjectKey: PLATFORM_SCOPE,
        scopeKey: PLATFORM_SCOPE,
        generatedOn,
        horizonDays: horizon,
        result,
        pricePerUnit,
        stockUnits: null,
      });
      written += 1;
    }
    return written;
  }

  // ── Read side ──────────────────────────────────────────────────────────

  /**
   * The most recent forecast for a subject, or null.
   *
   * Looks back a week rather than demanding today's row, so a dashboard shows
   * a slightly stale number with its own date on it instead of an empty panel
   * the morning after a failed run.
   */
  async latest(input: {
    subjectKind: TrendSubjectKind;
    subjectKey: string;
    scopeKey?: string;
    horizonDays: number;
    asOf?: Date;
  }) {
    const asOf = input.asOf ?? utcToday();
    return this.prisma.trendForecast.findFirst({
      where: {
        subjectKind: input.subjectKind,
        subjectKey: input.subjectKey,
        scopeKey: input.scopeKey ?? PLATFORM_SCOPE,
        horizonDays: input.horizonDays,
        generatedOn: { gte: addDays(asOf, -7), lte: asOf },
      },
      orderBy: { generatedOn: 'desc' },
    });
  }

  /** Latest forecasts for many subjects at once, keyed by subject id. */
  async latestForMany(input: {
    subjectKind: TrendSubjectKind;
    subjectKeys: readonly string[];
    scopeKey?: string;
    horizonDays: number;
    asOf?: Date;
  }) {
    if (!input.subjectKeys.length) return new Map<string, ForecastRow>();
    const asOf = input.asOf ?? utcToday();
    const rows = await this.prisma.trendForecast.findMany({
      where: {
        subjectKind: input.subjectKind,
        subjectKey: { in: [...input.subjectKeys] },
        scopeKey: input.scopeKey ?? PLATFORM_SCOPE,
        horizonDays: input.horizonDays,
        generatedOn: { gte: addDays(asOf, -7), lte: asOf },
      },
      orderBy: { generatedOn: 'asc' },
    });
    // Ascending, so the last write per subject is the freshest.
    const latest = new Map<string, ForecastRow>();
    for (const row of rows) latest.set(row.subjectKey, row);
    return latest;
  }

  // ── Writer ─────────────────────────────────────────────────────────────

  private async write(input: {
    subjectKind: TrendSubjectKind;
    subjectKey: string;
    scopeKey: string;
    generatedOn: Date;
    horizonDays: number;
    result: ForecastResult;
    pricePerUnit: number;
    stockUnits: number | null;
  }): Promise<void> {
    const { result } = input;
    const data = {
      method: result.method,
      points: result.points as unknown as Prisma.InputJsonValue,
      totalUnits: result.totalUnits,
      totalRevenueSyp: new Prisma.Decimal(
        (result.totalUnits * Math.max(0, input.pricePerUnit)).toFixed(4),
      ),
      confidence: result.confidence,
      backtestMae: result.backtestMae,
      stockoutInDays:
        input.stockUnits === null
          ? null
          : stockoutInDays(input.stockUnits, result.points),
    };

    await this.prisma.trendForecast.upsert({
      where: {
        subjectKind_subjectKey_scopeKey_horizonDays_generatedOn: {
          subjectKind: input.subjectKind,
          subjectKey: input.subjectKey,
          scopeKey: input.scopeKey,
          horizonDays: input.horizonDays,
          generatedOn: input.generatedOn,
        },
      },
      create: {
        subjectKind: input.subjectKind,
        subjectKey: input.subjectKey,
        scopeKey: input.scopeKey,
        horizonDays: input.horizonDays,
        generatedOn: input.generatedOn,
        ...data,
      },
      update: data,
    });
  }
}

export type ForecastRow = Awaited<
  ReturnType<PrismaService['trendForecast']['findFirst']>
> extends infer T
  ? NonNullable<T>
  : never;

/** Total units across a set of forecast rows — the seller overview headline. */
export function totalForecastUnits(
  rows: Iterable<{ totalUnits: number }>,
): number {
  return round(sum([...rows].map((row) => row.totalUnits)), 2);
}
