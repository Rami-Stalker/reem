import { Injectable, Logger } from '@nestjs/common';
import { Currency, Prisma } from '@prisma/client';
import { PrismaService } from '../../prisma/prisma.service';
import { Money } from '../../common/money';
import { CustomerFactsService } from './customer-facts.service';
import {
  CustomerReading,
  VALUE_HORIZON_DAYS,
  readCustomer,
} from './kernel/propensity';

/** How stale a cached profile may be before a reader should distrust it. */
export const PROFILE_FRESH_HOURS = 36;

@Injectable()
export class CustomerIntelligenceService {
  private readonly logger = new Logger(CustomerIntelligenceService.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly facts: CustomerFactsService,
  ) {}

  /**
   * The live reading for one customer, computed now.
   *
   * Used by anything that has to be right this second — a support screen
   * looking at one woman, an offer being decided at checkout. Everything that
   * runs over many customers reads the cache instead.
   */
  async read(userId: string): Promise<CustomerReading> {
    return readCustomer(await this.facts.forCustomer(userId));
  }

  /** Computes and stores one profile. */
  async refresh(userId: string) {
    const reading = await this.read(userId);
    return this.store(userId, reading);
  }

  /**
   * Refreshes the customers whose reading can have changed.
   *
   * Bounded, and driven by activity rather than by walking the whole user
   * table: a customer who has done nothing since her last refresh will produce
   * the same four numbers, and spending a nightly job proving that is how a
   * sweep becomes an outage as the platform grows.
   */
  async sweep(options: { sinceDays: number; limit: number }) {
    const since = new Date(
      Date.now() - options.sinceDays * 24 * 60 * 60 * 1000,
    );

    const active = await this.prisma.analyticsEvent.findMany({
      where: { userId: { not: null }, occurredAt: { gte: since } },
      select: { userId: true },
      distinct: ['userId'],
      take: options.limit,
    });

    let refreshed = 0;
    for (const row of active) {
      if (!row.userId) continue;
      try {
        await this.refresh(row.userId);
        refreshed += 1;
      } catch (error) {
        // One unreadable customer must not stop the sweep.
        this.logger.warn(`Profile ${row.userId} not refreshed: ${String(error)}`);
      }
    }

    return { scanned: active.length, refreshed };
  }

  /** The cached profile, or null when she has never been scored. */
  async profile(userId: string) {
    const row = await this.prisma.customerProfile.findUnique({
      where: { userId },
    });
    return row ? this.serialize(row) : null;
  }

  /**
   * Customers in a band, worst (or warmest) first.
   *
   * The one query every downstream consumer wants: who is leaving, who is
   * about to buy, who is worth the most. Reads the cache — that is what it is
   * for.
   */
  async inBand(options: {
    dimension: 'churn' | 'propensity';
    band: string;
    limit: number;
    skip: number;
    minValue?: number;
  }) {
    const where: Prisma.CustomerProfileWhereInput =
      options.dimension === 'churn'
        ? { churnBand: options.band }
        : { propensityBand: options.band };

    if (options.minValue !== undefined) {
      where.projectedValue = { gte: options.minValue };
    }

    const [rows, total] = await Promise.all([
      this.prisma.customerProfile.findMany({
        where,
        orderBy:
          options.dimension === 'churn'
            ? [{ projectedValue: 'desc' }, { churnScore: 'desc' }]
            : [{ propensityScore: 'desc' }, { projectedValue: 'desc' }],
        take: options.limit,
        skip: options.skip,
        include: { user: { select: { id: true, name: true, username: true } } },
      }),
      this.prisma.customerProfile.count({ where }),
    ]);

    return {
      data: rows.map((row) => ({
        ...this.serialize(row),
        customer: row.user,
      })),
      total,
    };
  }

  /**
   * How the customer base looks, by band.
   *
   * The screen that says whether retention is working: a churn distribution
   * that shifts right over a month is a marketplace losing people, however
   * good the month's revenue looked.
   */
  async distribution() {
    const [churn, propensity, aggregate] = await Promise.all([
      this.prisma.customerProfile.groupBy({
        by: ['churnBand'],
        _count: { _all: true },
        _sum: { projectedValue: true },
      }),
      this.prisma.customerProfile.groupBy({
        by: ['propensityBand'],
        _count: { _all: true },
      }),
      this.prisma.customerProfile.aggregate({
        _sum: { realisedValue: true, projectedValue: true },
        _count: { _all: true },
      }),
    ]);

    return {
      customers: aggregate._count._all,
      realised_value: Money.of(
        aggregate._sum.realisedValue ?? 0,
        Currency.SYP,
      ).toJSON(),
      projected_value: Money.of(
        aggregate._sum.projectedValue ?? 0,
        Currency.SYP,
      ).toJSON(),
      churn: churn.map((row) => ({
        band: row.churnBand,
        customers: row._count._all,
        // What leaving would cost, which is the number that gets a retention
        // budget approved — a count of at-risk customers does not.
        value_at_risk: Money.of(
          row._sum.projectedValue ?? 0,
          Currency.SYP,
        ).toJSON(),
      })),
      propensity: propensity.map((row) => ({
        band: row.propensityBand,
        customers: row._count._all,
      })),
    };
  }

  // ── internals ────────────────────────────────────────────────────────────

  private async store(userId: string, reading: CustomerReading) {
    const data = {
      propensityScore: reading.propensity.score,
      propensityBand: reading.propensity.band,
      churnScore: reading.churn.score,
      churnBand: reading.churn.band,
      cadenceDays: reading.churn.cadenceDays,
      realisedValue: new Prisma.Decimal(reading.value.realisedValue),
      projectedValue: new Prisma.Decimal(reading.value.projectedValue),
      valueHorizonDays: reading.value.horizonDays,
      bestContactHour: reading.contact.bestHour,
      signals: {
        propensity: reading.propensity.signals,
        churn: reading.churn.signals,
      } as unknown as Prisma.InputJsonValue,
      // A profile is confident only when every reading behind it is. A caller
      // spending money on one number should not have to check three flags.
      confident:
        reading.propensity.confident &&
        reading.churn.confident &&
        reading.value.confident,
      computedAt: new Date(),
    };

    const row = await this.prisma.customerProfile.upsert({
      where: { userId },
      create: { userId, ...data },
      update: data,
    });

    return this.serialize(row);
  }

  private serialize(row: {
    userId: string;
    propensityScore: number;
    propensityBand: string;
    churnScore: number;
    churnBand: string;
    cadenceDays: number | null;
    realisedValue: Prisma.Decimal;
    projectedValue: Prisma.Decimal;
    valueHorizonDays: number;
    currency: Currency;
    bestContactHour: number | null;
    signals: Prisma.JsonValue;
    confident: boolean;
    computedAt: Date;
  }) {
    return {
      user_id: row.userId,
      propensity: {
        score: row.propensityScore,
        band: row.propensityBand,
      },
      churn: {
        score: row.churnScore,
        band: row.churnBand,
        cadence_days: row.cadenceDays,
      },
      value: {
        realised: Money.of(row.realisedValue, row.currency).toJSON(),
        projected: Money.of(row.projectedValue, row.currency).toJSON(),
        horizon_days: row.valueHorizonDays,
      },
      best_contact_hour: row.bestContactHour,
      signals: row.signals,
      confident: row.confident,
      computed_at: row.computedAt.toISOString(),
      // Said rather than implied: a consumer reading a three-day-old profile
      // should know it is three days old.
      stale:
        Date.now() - row.computedAt.getTime() >
        PROFILE_FRESH_HOURS * 60 * 60 * 1000,
    };
  }
}
