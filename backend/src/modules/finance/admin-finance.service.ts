import { Injectable, Logger } from '@nestjs/common';
import {
  Currency,
  DisputeStatus,
  LedgerAccountCode,
  LedgerAccountKind,
  Prisma,
} from '@prisma/client';

import { Money } from '../../common/money';
import { PrismaService } from '../../prisma/prisma.service';
import { LedgerService } from '../ledger/ledger.service';
import { CourierSettlementService } from './courier-settlement.service';
import { FxRevaluationService } from './fx-revaluation.service';
import { ReconciliationService } from './reconciliation.service';

type Tx = Prisma.TransactionClient;

/**
 * The finance screen, assembled server-side.
 *
 * Deliberately one call returning finished figures rather than five calls the
 * client stitches together. Every total here is a sum of money, and money
 * arithmetic lives on the server where `Money` guarantees decimals — a Dart
 * client folding balances with `double` would reintroduce exactly the
 * rounding error the whole ledger is built to avoid.
 *
 * The headline is not revenue. A marketplace can read its takings off any
 * report; only a double-entry book can say whether the takings are *true*, so
 * `sound` leads and everything else follows it.
 */
@Injectable()
export class AdminFinanceService {
  private readonly logger = new Logger(AdminFinanceService.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly ledger: LedgerService,
    private readonly reconciliation: ReconciliationService,
    private readonly couriers: CourierSettlementService,
    private readonly fx: FxRevaluationService,
  ) {}

  async overview(currency: Currency = Currency.SYP, tx?: Tx) {
    const [trialBalance, report, walletFindings, courierCash, disputes] =
      await Promise.all([
        this.ledger.trialBalance(currency, tx),
        this.reconciliation.run(currency, tx),
        this.reconciliation.verifyWallets(currency, tx),
        this.couriers.outstanding(currency, tx),
        this.overdueDisputes(currency, tx),
      ]);

    const findings = [...report.findings, ...walletFindings];

    // FX is optional: a platform that has never published a rate has no
    // position, and that is not an error worth failing the screen for.
    const fx = await this.fxPosition(currency, tx);

    const rows = trialBalance.rows.map((row) => ({
      account_id: row.accountId,
      code: row.code,
      kind: row.kind,
      owner_id: row.ownerId,
      label: row.label,
      debit: row.debit.toJSON(),
      credit: row.credit.toJSON(),
      balance: row.balance.toJSON(),
    }));

    return {
      currency,

      // ── Is the book sound? ──────────────────────────────────────────
      balanced: trialBalance.balanced,
      sound: trialBalance.balanced && findings.length === 0,
      total_debit: trialBalance.totalDebit.toJSON(),
      total_credit: trialBalance.totalCredit.toJSON(),
      /// Non-zero means money has been created or destroyed.
      discrepancy: trialBalance.totalDebit
        .minus(trialBalance.totalCredit)
        .toJSON(),
      findings,

      // ── Where the money is ──────────────────────────────────────────
      positions: this.positions(trialBalance.rows, currency),

      // ── What needs a person ─────────────────────────────────────────
      courier_cash: courierCash,
      courier_cash_total: this.sumJson(
        courierCash.map((entry) => entry.outstanding),
        currency,
      ).toJSON(),
      overdue_disputes: disputes,

      fx,

      rows,
    };
  }

  /**
   * The standing balances an operator actually watches.
   *
   * Party accounts are summed across everyone — «كم ندين للبائعات» is one
   * number, not one per seller — while platform singletons stand alone.
   */
  private positions(
    rows: Array<{
      code: LedgerAccountCode;
      kind: LedgerAccountKind;
      balance: Money;
    }>,
    currency: Currency,
  ) {
    const totalFor = (code: LedgerAccountCode) =>
      Money.sum(
        rows.filter((row) => row.code === code).map((row) => row.balance),
        currency,
      );

    const platformCash = totalFor(LedgerAccountCode.PLATFORM_CASH);
    const sellerPayable = totalFor(LedgerAccountCode.SELLER_PAYABLE);
    const sellerEscrow = totalFor(LedgerAccountCode.SELLER_ESCROW);
    const customerWallets = totalFor(LedgerAccountCode.CUSTOMER_WALLET);
    const disputeHeld = totalFor(LedgerAccountCode.DISPUTE_HELD);
    const loyalty = totalFor(LedgerAccountCode.LOYALTY_LIABILITY);
    const gatewayReceivable = totalFor(LedgerAccountCode.GATEWAY_RECEIVABLE);
    const courierInTransit = totalFor(
      LedgerAccountCode.COURIER_CASH_IN_TRANSIT,
    );
    const commissionRevenue = totalFor(LedgerAccountCode.COMMISSION_REVENUE);

    // What the platform owes everyone, against what it holds to pay them with.
    const owed = Money.sum(
      [sellerPayable, sellerEscrow, customerWallets, disputeHeld, loyalty],
      currency,
    );
    const held = Money.sum(
      [platformCash, gatewayReceivable, courierInTransit],
      currency,
    );

    return {
      platform_cash: platformCash.toJSON(),
      gateway_receivable: gatewayReceivable.toJSON(),
      courier_in_transit: courierInTransit.toJSON(),
      seller_payable: sellerPayable.toJSON(),
      seller_escrow: sellerEscrow.toJSON(),
      customer_wallets: customerWallets.toJSON(),
      dispute_held: disputeHeld.toJSON(),
      loyalty_liability: loyalty.toJSON(),
      commission_revenue: commissionRevenue.toJSON(),

      total_owed: owed.toJSON(),
      total_held: held.toJSON(),
      /**
       * Held minus owed. Negative means the platform has taken on more
       * obligation than it is holding funds to meet — solvency, in one line.
       */
      coverage: held.minus(owed).toJSON(),
    };
  }

  /** Q107 — disputes past their 3/7 working-day clock. */
  private async overdueDisputes(
    currency: Currency,
    tx?: Tx,
    now = new Date(),
  ) {
    const disputes = await (tx ?? this.prisma).dispute.findMany({
      where: {
        currency,
        status: {
          in: [
            DisputeStatus.OPEN,
            DisputeStatus.UNDER_REVIEW,
            DisputeStatus.ESCALATED,
            DisputeStatus.APPEALED,
          ],
        },
        OR: [
          { extendedTo: null, dueAt: { lt: now } },
          { extendedTo: { lt: now } },
        ],
      },
      orderBy: { dueAt: 'asc' },
      take: 20,
    });

    return disputes.map((dispute) => ({
      id: dispute.id,
      number: dispute.number,
      subject: dispute.subject,
      status: dispute.status,
      frozen_amount: Money.of(dispute.frozenAmount, dispute.currency).toJSON(),
      due_at: dispute.extendedTo ?? dispute.dueAt,
    }));
  }

  /**
   * The FX block, or null when there is no rate to translate at.
   *
   * A fresh platform has published no rate, and a screen that fails because a
   * currency it does not yet use cannot be valued would be worse than useless.
   */
  private async fxPosition(reporting: Currency, tx?: Tx) {
    const foreign =
      reporting === Currency.SYP ? Currency.USD : Currency.SYP;
    try {
      const [exposure, result] = await Promise.all([
        this.fx.exposure(foreign, reporting, tx),
        this.fx.accumulatedResult(foreign, reporting, tx),
      ]);
      return {
        rate: exposure.rate,
        rate_source: exposure.rateSource,
        foreign_currency: foreign,
        assets: exposure.assets,
        liabilities: exposure.liabilities,
        net_exposure: exposure.netExposure,
        net_result: result.net_result,
      };
    } catch (error) {
      this.logger.debug(
        `FX block omitted: ${(error as Error).message}`,
      );
      return null;
    }
  }

  private sumJson(
    amounts: Array<{ amount: string; currency: Currency }>,
    currency: Currency,
  ): Money {
    return Money.sum(
      amounts.map((entry) => Money.of(entry.amount, entry.currency)),
      currency,
    );
  }
}
