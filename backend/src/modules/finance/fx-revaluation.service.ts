import { Injectable, Logger } from '@nestjs/common';
import { Cron, CronExpression } from '@nestjs/schedule';
import {
  Currency,
  LedgerAccountCode,
  LedgerAccountKind,
  Prisma,
  RoundingPolicy,
} from '@prisma/client';

import { Money } from '../../common/money';
import { PrismaService } from '../../prisma/prisma.service';
import { ExchangeRateService } from '../pricing/exchange-rate.service';
import { LedgerService } from '../ledger/ledger.service';

type Tx = Prisma.TransactionClient;

/** One foreign-currency balance, translated into the reporting currency. */
export interface TranslatedBalance {
  readonly code: LedgerAccountCode;
  readonly kind: LedgerAccountKind;
  readonly ownerId: string | null;
  readonly foreign: ReturnType<Money['toJSON']>;
  readonly reporting: ReturnType<Money['toJSON']>;
}

export interface FxExposureReport {
  readonly reportingCurrency: Currency;
  readonly foreignCurrency: Currency;
  readonly rate: string;
  readonly rateSource: string;
  readonly rateFrozenAt: Date;
  readonly assets: ReturnType<Money['toJSON']>;
  readonly liabilities: ReturnType<Money['toJSON']>;
  /** Assets minus liabilities: what a rate move actually moves. */
  readonly netExposure: ReturnType<Money['toJSON']>;
  readonly balances: TranslatedBalance[];
}

/**
 * What the platform's foreign-currency position is worth today.
 *
 * Q45 lets a seller price in USD and Q46 freezes the rate at order creation,
 * so an order carries no exposure once placed — checkout converts every line
 * into the order's currency there and then. What *does* carry exposure is the
 * platform's own standing position: cash it holds in one currency against
 * obligations it owes in another, and the residual left in `FX_ADJUSTMENT` by
 * every cross-currency settlement it has made.
 *
 * Two questions are answered here, and they are different questions:
 *
 * - **Exposure** — if the rate moves tomorrow, how much does that cost us?
 *   Unrealised, a forecast, never posted.
 * - **Result** — what have past conversions actually cost us? Realised,
 *   sitting in `FX_ADJUSTMENT`, and postable to close out a period.
 */
@Injectable()
export class FxRevaluationService {
  private readonly logger = new Logger(FxRevaluationService.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly ledger: LedgerService,
    private readonly rates: ExchangeRateService,
  ) {}

  /**
   * Every balance held in [foreign], translated into [reporting] at today's
   * rate.
   *
   * Nothing is written. A translation is an opinion about today's rate, and
   * an opinion does not belong in the book of record — only the conversions
   * that actually happened do.
   */
  async exposure(
    foreign: Currency = Currency.USD,
    reporting: Currency = Currency.SYP,
    tx?: Tx,
  ): Promise<FxExposureReport> {
    const rate = await this.rates.current(foreign, reporting);

    const accounts = await (tx ?? this.prisma).ledgerAccount.findMany({
      where: { currency: foreign, balance: { not: 0 } },
      orderBy: [{ code: 'asc' }],
    });

    const balances: TranslatedBalance[] = accounts.map((account) => {
      const foreignAmount = Money.of(account.balance, foreign);
      return {
        code: account.code,
        kind: account.kind,
        ownerId: account.ownerId ?? account.courierId,
        foreign: foreignAmount.toJSON(),
        reporting: foreignAmount
          .convertTo(reporting, rate.rate)
          .round(RoundingPolicyFor[reporting])
          .toJSON(),
      };
    });

    // Only real position counts. Revenue and expense accounts are a record of
    // what already happened, not something a future rate move can change.
    const assets = this.sumOf(
      accounts,
      LedgerAccountKind.ASSET,
      foreign,
      reporting,
      rate.rate,
    );
    const liabilities = this.sumOf(
      accounts,
      LedgerAccountKind.LIABILITY,
      foreign,
      reporting,
      rate.rate,
    );

    return {
      reportingCurrency: reporting,
      foreignCurrency: foreign,
      rate: rate.rate.toString(),
      rateSource: rate.source,
      rateFrozenAt: rate.frozenAt,
      assets: assets.toJSON(),
      liabilities: liabilities.toJSON(),
      netExposure: assets.minus(liabilities).toJSON(),
      balances,
    };
  }

  /**
   * The accumulated result of every conversion the platform has made.
   *
   * `postConversion` leaves both legs of a conversion in `FX_ADJUSTMENT`: a
   * negative foreign balance and a positive reporting one, or the reverse.
   * Translate the foreign leg at today's rate, add the reporting leg, and the
   * sum is what converting has cost or earned — a gain if positive.
   */
  async accumulatedResult(
    foreign: Currency = Currency.USD,
    reporting: Currency = Currency.SYP,
    tx?: Tx,
  ) {
    const rate = await this.rates.current(foreign, reporting);

    const [foreignLeg, reportingLeg] = await Promise.all([
      this.ledger.balanceOf(
        { code: LedgerAccountCode.FX_ADJUSTMENT },
        foreign,
        tx,
      ),
      this.ledger.balanceOf(
        { code: LedgerAccountCode.FX_ADJUSTMENT },
        reporting,
        tx,
      ),
    ]);

    // FX_ADJUSTMENT is debit-normal, so its balance is already signed the way
    // an expense is: positive means value went out.
    const translated = foreignLeg
      .convertTo(reporting, rate.rate)
      .round(RoundingPolicyFor[reporting]);

    // A positive combined balance means conversions cost more than the
    // obligations they settled — a loss. Reported as a gain, so the sign reads
    // the way a reader expects.
    const result = translated.plus(reportingLeg).negated();

    return {
      reporting_currency: reporting,
      foreign_currency: foreign,
      rate: rate.rate.toString(),
      foreign_leg: foreignLeg.toJSON(),
      reporting_leg: reportingLeg.toJSON(),
      /// Positive is a gain to the platform, negative a loss.
      net_result: result.toJSON(),
    };
  }

  /**
   * Logs the position nightly.
   *
   * Deliberately a log and not a posting. Recognising an unrealised
   * translation as a journal entry would mean writing an opinion about
   * today's rate into a book whose whole value is that it only contains
   * things that happened. When the client wants period-end recognition, it
   * belongs behind an explicit admin action with a stated closing rate.
   */
  @Cron(CronExpression.EVERY_DAY_AT_4AM)
  async nightly(): Promise<void> {
    try {
      const report = await this.exposure();
      const net = Money.of(report.netExposure.amount, Currency.SYP);
      if (net.isZero()) return;

      this.logger.log(
        `FX position: ${report.foreignCurrency} net ${report.netExposure.amount} ` +
          `${report.reportingCurrency} at ${report.rate} (${report.rateSource})`,
      );
    } catch (error) {
      // No rate published yet is the normal state on a fresh install, and is
      // not worth an error-level line every night.
      this.logger.debug(
        `FX position not computed: ${(error as Error).message}`,
      );
    }
  }

  private sumOf(
    accounts: Array<{ kind: LedgerAccountKind; balance: Prisma.Decimal }>,
    kind: LedgerAccountKind,
    foreign: Currency,
    reporting: Currency,
    rate: Prisma.Decimal,
  ): Money {
    return Money.sum(
      accounts
        .filter((account) => account.kind === kind)
        .map((account) =>
          Money.of(account.balance, foreign)
            .convertTo(reporting, rate)
            .round(RoundingPolicyFor[reporting]),
        ),
      reporting,
    );
  }
}

/** Q48 — SYP is reported to the nearest 1000, as it is charged. */
const RoundingPolicyFor: Readonly<Record<Currency, RoundingPolicy>> =
  Object.freeze({
    [Currency.SYP]: RoundingPolicy.NEAREST_1000,
    [Currency.USD]: RoundingPolicy.NONE,
  });
