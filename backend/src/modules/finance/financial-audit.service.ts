import { Injectable } from '@nestjs/common';
import { AuditSeverity, Currency, Prisma } from '@prisma/client';

import { Money } from '../../common/money';
import { AuditService } from '../auth/audit.service';
import { RequestContext } from '../auth/interfaces/request-context.interface';

/** The money actions Q65 names explicitly, plus the ones implied by them. */
export const FinancialAction = {
  /** «صرف أرباح» */
  PayoutStatusChanged: 'payout.status_changed',
  /** «إضافة/خصم رصيد من المحافظ» */
  WalletCredited: 'wallet.credited',
  WalletFrozen: 'wallet.frozen',
  /** «تعديل سعر الصرف» */
  ExchangeRatePublished: 'fx.rate_published',
  ExchangeRateRejected: 'fx.rate_rejected',
  /** A dispute ruling moves frozen money — Q107 and Q65 both want it recorded. */
  DisputeDecided: 'dispute.decided',
  DisputeOpened: 'dispute.opened',
  /** Q38 P2 — money given back for a parcel cancelled before it shipped. */
  CancellationRefunded: 'order.cancellation_refunded',
  /** Q56 P1 — money given back to a customer for goods returned. */
  ReturnRefunded: 'return.refunded',
  /** Recording what a courier actually handed over (Q56). */
  CourierCashSettled: 'courier.cash_settled',
  /** Finance matched a bank transfer or hawala and marked it paid (Q51). */
  TransferConfirmed: 'payment.transfer_confirmed',
  /** Finance could not match the reference she gave. */
  TransferRejected: 'payment.transfer_rejected',
  /** Anything posted to the ledger by hand. */
  ManualLedgerEntry: 'ledger.manual_entry',
  /** «تعديل العمولات أو الباقات» */
  CommissionRuleChanged: 'commission.rule_changed',
} as const;

export type FinancialActionName =
  (typeof FinancialAction)[keyof typeof FinancialAction];

export interface FinancialAuditInput {
  readonly action: FinancialActionName;
  readonly actorId?: string | null;
  /** What the action was performed on — a payout id, a wallet, a rate pair. */
  readonly subjectId?: string | null;
  readonly subjectType?: string;

  /**
   * The value before and after. Q65: «القيمة قبل وبعد».
   *
   * Either may be absent — a first wallet credit has no "before", a rejected
   * rate has no "after" — but when a value changed, both belong here.
   */
  readonly before?: Money | string | null;
  readonly after?: Money | string | null;

  /** Q65: «والسبب إن كانت العملية حساسة». */
  readonly reason?: string | null;

  readonly outcome?: 'success' | 'refused' | 'failed';
  readonly severity?: AuditSeverity;
  readonly extra?: Record<string, unknown>;
  readonly context?: RequestContext;
}

/**
 * The audit trail for money.
 *
 * Q65 lists what has to be recorded — «صرف أرباح، إضافة/خصم رصيد من المحافظ،
 * تعديل سعر الصرف، تعديل العمولات» — and, more demandingly, *what each record
 * must contain*: «من قام بالعملية، ماذا غيّر، القيمة قبل وبعد، التاريخ والوقت،
 * والسبب إن كانت العملية حساسة».
 *
 * The generic `AuditService` takes a free-form metadata blob, which is enough
 * to store all of that and not enough to guarantee any of it. This wrapper
 * fixes the shape: every financial record carries actor, subject, before,
 * after and reason in the same fields, so a year of them can be read as one
 * table rather than as a hundred differently-shaped JSON objects.
 *
 * The ledger already proves *what the money did*. This proves *who told it
 * to* — the two answer different questions, and an audit needs both.
 */
@Injectable()
export class FinancialAuditService {
  /** Every financial record shares one category, so the log is filterable. */
  static readonly CATEGORY = 'finance';

  constructor(private readonly audit: AuditService) {}

  async record(input: FinancialAuditInput): Promise<void> {
    const metadata: Record<string, unknown> = {
      subject_id: input.subjectId ?? null,
      subject_type: input.subjectType ?? null,
      before: this.serialise(input.before),
      after: this.serialise(input.after),
      reason: input.reason ?? null,
      ...(input.extra ?? {}),
    };

    await this.audit.record({
      actorId: input.actorId ?? null,
      action: input.action,
      category: FinancialAuditService.CATEGORY,
      outcome: input.outcome ?? 'success',
      // Money moving is never routine background noise; a refused or failed
      // action is louder still, since that is the shape of both a bug and an
      // attempt at something that should not have been allowed.
      severity:
        input.severity ??
        (input.outcome && input.outcome !== 'success'
          ? AuditSeverity.WARNING
          : AuditSeverity.INFO),
      metadata: metadata as Prisma.InputJsonValue,
      context: input.context,
    });
  }

  /** Convenience for the commonest shape: a balance that moved. */
  async recordBalanceChange(
    action: FinancialActionName,
    options: {
      actorId?: string | null;
      subjectId: string;
      subjectType: string;
      before: Money;
      after: Money;
      reason?: string | null;
      extra?: Record<string, unknown>;
      context?: RequestContext;
    },
  ): Promise<void> {
    await this.record({
      action,
      actorId: options.actorId,
      subjectId: options.subjectId,
      subjectType: options.subjectType,
      before: options.before,
      after: options.after,
      reason: options.reason,
      extra: {
        ...(options.extra ?? {}),
        delta: options.after.minus(options.before).toJSON(),
      },
      context: options.context,
    });
  }

  /**
   * Renders a value for storage.
   *
   * `Money` becomes `{amount, currency}` rather than a bare number, because an
   * amount without its currency is not a value — and a log read three years
   * later has no other way to find out which one it was.
   */
  private serialise(
    value: Money | string | null | undefined,
  ): { amount: string; currency: Currency } | string | null {
    if (value === null || value === undefined) return null;
    return value instanceof Money ? value.toJSON() : value;
  }
}
