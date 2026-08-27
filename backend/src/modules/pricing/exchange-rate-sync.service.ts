import { Inject, Injectable, Logger, Optional } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { Cron, CronExpression } from '@nestjs/schedule';
import { Currency, Prisma } from '@prisma/client';

import { ExchangeRateService } from './exchange-rate.service';

/**
 * Records a rate change in the audit trail. A callback rather than a service
 * import so `PricingModule` stays underneath the finance layer that uses it.
 */
export type RateAuditHook = (event: {
  published: boolean;
  previous?: string;
  rate?: string;
  source: string;
  reason?: string;
}) => Promise<void>;

export const RATE_AUDIT_HOOK = Symbol('RATE_AUDIT_HOOK');

const Decimal = Prisma.Decimal;

/** Matches `ExchangeRate.rate` — `@db.Decimal(18, 6)`. */
const STORED_RATE_DECIMALS = 6;

export interface FxSyncConfig {
  readonly syncEnabled: boolean;
  readonly sourceUrl?: string;
  readonly sourcePath: string;
  readonly sourceName: string;
  readonly maxMoveBps: number;
  readonly minRate: string;
  readonly maxRate: string;
}

/** Why a fetched rate was not published. */
export type RejectionReason =
  | 'DISABLED'
  | 'NOT_CONFIGURED'
  | 'FETCH_FAILED'
  | 'UNPARSEABLE'
  | 'OUT_OF_BOUNDS'
  | 'MOVED_TOO_FAR';

export interface SyncOutcome {
  readonly published: boolean;
  readonly rate?: string;
  readonly previous?: string;
  readonly moveBps?: number;
  readonly reason?: RejectionReason;
  readonly detail?: string;
}

/**
 * Q50 P1 — «تلقائياً من مصدر منحدده», Q47 P2 — «موقع الليرة اليوم».
 *
 * Pulls the SYP/USD rate from a configured feed and publishes it. The pulling
 * is the easy half; the guards are the point.
 *
 * A published rate reprices the entire catalogue, because every product listed
 * in USD is charged in SYP at whatever rate is current. That makes a bad rate
 * far more damaging than a missing one, and a scraped feed returning a mangled
 * number is much likelier than a genuine overnight collapse. So:
 *
 * - **Bounds.** A figure outside plausible SYP-per-USD is not a rate, it is a
 *   parse error wearing a number.
 * - **Move limit.** Past a configured jump the rate is logged and dropped for
 *   a human to look at. A real devaluation that large deserves a person's
 *   attention anyway.
 * - **Never throws upward.** A feed being down must not take checkout with it;
 *   the last published rate simply stays in force, which is what `Order`
 *   freezing (Q46) already assumes.
 */
@Injectable()
export class ExchangeRateSyncService {
  private readonly logger = new Logger(ExchangeRateSyncService.name);

  constructor(
    private readonly config: ConfigService,
    private readonly rates: ExchangeRateService,
    @Optional()
    @Inject(RATE_AUDIT_HOOK)
    private readonly auditHook?: RateAuditHook,
  ) {}

  /**
   * Daily, early. The feed publishes a morning rate and the platform's own
   * quiet hours are 23:00–09:00 (Q88), so a repricing lands before sellers and
   * customers are active rather than in the middle of their day.
   */
  @Cron(CronExpression.EVERY_DAY_AT_6AM)
  async scheduled(): Promise<void> {
    const outcome = await this.syncNow();
    if (outcome.published) {
      this.logger.log(
        `FX rate published: ${outcome.rate} SYP/USD` +
          (outcome.previous ? ` (was ${outcome.previous})` : ''),
      );
      return;
    }
    if (outcome.reason === 'DISABLED' || outcome.reason === 'NOT_CONFIGURED') {
      return;
    }
    this.logger.warn(
      `FX rate not published — ${outcome.reason}: ${outcome.detail ?? ''}`,
    );
  }

  /**
   * Fetches and, if it survives the guards, publishes. Returns why not rather
   * than throwing, so both the cron and an admin trigger can report the same
   * outcome.
   */
  async syncNow(): Promise<SyncOutcome> {
    const fx = this.config.get<FxSyncConfig>('fx');
    if (!fx?.syncEnabled) return { published: false, reason: 'DISABLED' };
    if (!fx.sourceUrl) {
      return { published: false, reason: 'NOT_CONFIGURED' };
    }

    let fetched: Prisma.Decimal;
    try {
      fetched = await this.fetchRate(fx);
    } catch (error) {
      return {
        published: false,
        reason:
          (error as Error).message === 'UNPARSEABLE'
            ? 'UNPARSEABLE'
            : 'FETCH_FAILED',
        detail: (error as Error).message,
      };
    }

    const min = new Decimal(fx.minRate);
    const max = new Decimal(fx.maxRate);
    if (fetched.lessThan(min) || fetched.greaterThan(max)) {
      return {
        published: false,
        reason: 'OUT_OF_BOUNDS',
        rate: fetched.toString(),
        detail: `outside ${fx.minRate}–${fx.maxRate}`,
      };
    }

    const previous = await this.previousRate();
    if (previous) {
      const moveBps = this.moveInBps(previous, fetched);
      if (Math.abs(moveBps) > fx.maxMoveBps) {
        // A refused rate matters as much as an accepted one: a feed that keeps
        // being turned away is either broken or reporting a real collapse.
        await this.auditHook?.({
          published: false,
          previous: previous.toString(),
          rate: fetched.toString(),
          source: fx.sourceName,
          reason: `moved ${(moveBps / 100).toFixed(2)}%, limit ${(
            fx.maxMoveBps / 100
          ).toFixed(2)}%`,
        });
        return {
          published: false,
          reason: 'MOVED_TOO_FAR',
          rate: fetched.toString(),
          previous: previous.toString(),
          moveBps,
          detail: `moved ${(moveBps / 100).toFixed(2)}%, limit ${(
            fx.maxMoveBps / 100
          ).toFixed(2)}%`,
        };
      }

      // An unchanged rate is not worth a new row: the history is meant to show
      // when the rate moved, not how often it was checked.
      if (previous.equals(fetched)) {
        return {
          published: false,
          reason: undefined,
          rate: fetched.toString(),
          previous: previous.toString(),
          moveBps: 0,
          detail: 'unchanged',
        };
      }
    }

    await this.rates.publish({
      base: Currency.USD,
      quote: Currency.SYP,
      rate: fetched,
      source: fx.sourceName,
    });

    // Q65 — «تعديل سعر الصرف»: a new rate reprices every USD-listed product,
    // so the previous and new values both go on the record.
    await this.auditHook?.({
      published: true,
      previous: previous?.toString(),
      rate: fetched.toString(),
      source: fx.sourceName,
    });

    return {
      published: true,
      rate: fetched.toString(),
      previous: previous?.toString(),
      moveBps: previous ? this.moveInBps(previous, fetched) : undefined,
    };
  }

  // ── Internals ─────────────────────────────────────────────────────────

  private async fetchRate(fx: FxSyncConfig): Promise<Prisma.Decimal> {
    const controller = new AbortController();
    const timeout = setTimeout(() => controller.abort(), 10_000);

    try {
      const response = await fetch(fx.sourceUrl!, {
        signal: controller.signal,
        headers: { accept: 'application/json' },
      });
      if (!response.ok) {
        throw new Error(`HTTP ${response.status}`);
      }
      const body: unknown = await response.json();
      const raw = this.readPath(body, fx.sourcePath);
      if (raw === undefined || raw === null) {
        throw new Error('UNPARSEABLE');
      }

      // Feeds return `"15,250"` as often as `15250`, and a comma silently
      // truncates a Decimal parse.
      const cleaned = String(raw).replace(/[,\s]/g, '');
      const rate = new Decimal(cleaned);
      if (!rate.isFinite() || rate.lessThanOrEqualTo(0)) {
        throw new Error('UNPARSEABLE');
      }

      // Quantise to the precision the column actually stores. Feeds quote more
      // decimals than `ExchangeRate.rate` keeps, and comparing a full-precision
      // fetch against a truncated stored value never matches — which would
      // publish an identical rate every single run and fill the history with
      // rows that record nothing.
      return rate.toDecimalPlaces(STORED_RATE_DECIMALS);
    } finally {
      clearTimeout(timeout);
    }
  }

  /** Walks a dotted path, e.g. `usd.ask`, without evaluating anything. */
  private readPath(body: unknown, path: string): unknown {
    return path
      .split('.')
      .reduce<unknown>(
        (node, key) =>
          node && typeof node === 'object'
            ? (node as Record<string, unknown>)[key]
            : undefined,
        body,
      );
  }

  private async previousRate(): Promise<Prisma.Decimal | null> {
    try {
      const current = await this.rates.current(Currency.USD, Currency.SYP);
      return current.source === 'identity' ? null : current.rate;
    } catch {
      // Nothing published yet — the first rate has nothing to be compared to.
      return null;
    }
  }

  /** Signed move from [previous] to [next], in basis points. */
  private moveInBps(previous: Prisma.Decimal, next: Prisma.Decimal): number {
    if (previous.isZero()) return 0;
    return next
      .minus(previous)
      .dividedBy(previous)
      .times(10_000)
      .toDecimalPlaces(0)
      .toNumber();
  }
}
