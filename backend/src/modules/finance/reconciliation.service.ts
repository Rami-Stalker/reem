import { Injectable, Logger } from '@nestjs/common';
import { Cron, CronExpression } from '@nestjs/schedule';
import {
  Currency,
  LedgerAccountCode,
  LedgerAccountKind,
  Prisma,
} from '@prisma/client';

import { Money } from '../../common/money';
import { PrismaService } from '../../prisma/prisma.service';

type Tx = Prisma.TransactionClient;
import { LedgerService } from '../ledger/ledger.service';

export interface ReconciliationFinding {
  readonly kind:
    | 'TRIAL_BALANCE_OFF'
    | 'CACHED_BALANCE_DRIFT'
    | 'SUSPENSE_NOT_EMPTY'
    | 'NEGATIVE_LIABILITY';
  readonly detail: string;
  readonly accountId?: string;
}

export interface ReconciliationReport {
  readonly currency: Currency;
  readonly checkedAt: Date;
  readonly accountsChecked: number;
  readonly findings: ReconciliationFinding[];
  readonly healthy: boolean;
}

/**
 * The books checking themselves.
 *
 * Every invariant in `LedgerService` is enforced at write time, which is where
 * it belongs — but a system that only checks on the way in cannot tell you it
 * is still correct a month later, after a migration, a hand-run SQL fix, or a
 * bug in a caller. This runs the checks from the other end, on data at rest,
 * and says so loudly when they fail.
 *
 * Four things are looked for, in descending order of how alarming they are:
 *
 * 1. **The trial balance is off.** Debits and credits disagree in aggregate:
 *    money has been created or destroyed. This should be impossible.
 * 2. **A cached balance has drifted** from the sum of its own lines. Something
 *    wrote a balance outside `post`.
 * 3. **Suspense is not empty.** Something could not be classified and is
 *    sitting in the account of last resort.
 * 4. **A liability has gone negative** — we are "owed" money by an account
 *    that only ever holds what we owe. Usually an over-release.
 */
@Injectable()
export class ReconciliationService {
  private readonly logger = new Logger(ReconciliationService.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly ledger: LedgerService,
  ) {}

  /**
   * Q109 left the schedule to us. Nightly, well after the daily courier
   * settlement (Q56), so a day's movements are complete before they are
   * checked.
   */
  @Cron(CronExpression.EVERY_DAY_AT_3AM)
  async nightly(): Promise<void> {
    for (const currency of [Currency.SYP, Currency.USD]) {
      const report = await this.run(currency);
      if (report.healthy) {
        this.logger.log(
          `Ledger reconciliation ${currency}: clean (${report.accountsChecked} accounts)`,
        );
        continue;
      }
      // Loud on purpose. A finding here means the platform's own numbers
      // disagree with each other, and that is worth waking someone for.
      this.logger.error(
        `Ledger reconciliation ${currency}: ${report.findings.length} finding(s)`,
      );
      for (const finding of report.findings) {
        this.logger.error(`  [${finding.kind}] ${finding.detail}`);
      }
    }
  }

  /** Runs every check for one currency. Safe to call on demand. */
  async run(currency: Currency, tx?: Tx): Promise<ReconciliationReport> {
    const findings: ReconciliationFinding[] = [];

    const trialBalance = await this.ledger.trialBalance(currency, tx);
    if (!trialBalance.balanced) {
      findings.push({
        kind: 'TRIAL_BALANCE_OFF',
        detail:
          `debits ${trialBalance.totalDebit.toString()} vs credits ` +
          `${trialBalance.totalCredit.toString()} — the difference is ` +
          trialBalance.totalDebit.minus(trialBalance.totalCredit).toString(),
      });
    }

    for (const row of trialBalance.rows) {
      const check = await this.ledger.verifyAccount(row.accountId, tx);
      if (!check.agrees) {
        findings.push({
          kind: 'CACHED_BALANCE_DRIFT',
          accountId: row.accountId,
          detail:
            `${row.code}${row.ownerId ? ` (${row.ownerId})` : ''}: cached ` +
            `${check.cached.toString()} but its lines sum to ${check.derived.toString()}`,
        });
      }

      if (row.code === LedgerAccountCode.SUSPENSE && !row.balance.isZero()) {
        findings.push({
          kind: 'SUSPENSE_NOT_EMPTY',
          accountId: row.accountId,
          detail: `suspense holds ${row.balance.toString()} — something was posted without a home`,
        });
      }

      // A liability going negative means more was released than was ever
      // owed: an escrow released twice, a wallet refunded past its balance.
      if (
        row.kind === LedgerAccountKind.LIABILITY &&
        row.balance.isNegative()
      ) {
        findings.push({
          kind: 'NEGATIVE_LIABILITY',
          accountId: row.accountId,
          detail:
            `${row.code}${row.ownerId ? ` (${row.ownerId})` : ''} is ` +
            `${row.balance.toString()} — more has been released than was owed`,
        });
      }
    }

    return {
      currency,
      checkedAt: new Date(),
      accountsChecked: trialBalance.rows.length,
      findings,
      healthy: findings.length === 0,
    };
  }

  /**
   * Cross-checks the wallet cache against the ledger.
   *
   * `Wallet.balance` and the customer's `CUSTOMER_WALLET` ledger account are
   * two records of the same fact, written in one transaction. They should
   * never disagree — and if they do, the customer-facing number and the books
   * are telling different stories, which is the worst kind of wrong.
   */
  async verifyWallets(
    currency: Currency = Currency.SYP,
    tx?: Tx,
  ): Promise<ReconciliationFinding[]> {
    const wallets = await (tx ?? this.prisma).wallet.findMany({
      where: { currency },
      select: { id: true, userId: true, balance: true },
    });

    const findings: ReconciliationFinding[] = [];
    for (const wallet of wallets) {
      const ledgerBalance = await this.ledger.balanceOf(
        { code: LedgerAccountCode.CUSTOMER_WALLET, ownerId: wallet.userId },
        currency,
        tx,
      );
      const cached = Money.of(wallet.balance, currency);
      if (!cached.equals(ledgerBalance)) {
        findings.push({
          kind: 'CACHED_BALANCE_DRIFT',
          detail:
            `wallet ${wallet.id}: shows ${cached.toString()} to the customer ` +
            `but the ledger says ${ledgerBalance.toString()}`,
        });
      }
    }
    return findings;
  }
}
