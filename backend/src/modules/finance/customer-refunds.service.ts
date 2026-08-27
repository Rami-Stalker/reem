import { Injectable, Logger, NotFoundException } from '@nestjs/common';
import { Cron, CronExpression } from '@nestjs/schedule';
import {
  Currency,
  JournalEntryType,
  LedgerAccountCode,
  LedgerDirection,
  PaymentMethodType,
  PaymentStatus,
  Prisma,
  SellerOrderStatus,
  WalletTransactionSource,
} from '@prisma/client';

import { CANCELLED_STATUSES, Money } from '../../common/money';
import { PrismaService } from '../../prisma/prisma.service';
import { LedgerService, PostingLine } from '../ledger/ledger.service';
import { WalletService } from '../ledger/wallet.service';
import {
  SYSTEM_ACTOR,
  SellerOrderWorkflowService,
  WorkflowActor,
} from '../orders/workflow/seller-order-workflow.service';
import {
  FinancialAction,
  FinancialAuditService,
} from './financial-audit.service';

type Tx = Prisma.TransactionClient;

/**
 * The endings that can still owe a customer money.
 *
 * `REFUND_PENDING` is in the list because a refund interrupted between its
 * entry and its status change has to be finishable; the entry's idempotency
 * makes running it again free.
 */
const REFUNDABLE_ENDINGS: readonly SellerOrderStatus[] = [
  SellerOrderStatus.CANCELLED_BY_CUSTOMER,
  SellerOrderStatus.CANCELLED_BY_SELLER,
  SellerOrderStatus.REJECTED_ON_DELIVERY,
  SellerOrderStatus.REFUND_PENDING,
];

/**
 * Where a customer's money currently sits, and therefore where a refund of it
 * has to come from.
 *
 * Not a preference — a fact about how far the sale had got. A delivered and
 * settled parcel has already split her money between the seller and the
 * platform, and both give their share back. A parcel that was paid for but
 * never settled is still whole, wherever the rail it arrived on left it. One
 * that was never paid for has nothing to give back, and inventing an entry for
 * it would create money.
 */
export type RefundFunding =
  | {
      readonly kind: 'SETTLED';
      /** Escrow while the return window is open, payable once released. */
      readonly sellerAccount:
        | typeof LedgerAccountCode.SELLER_ESCROW
        | typeof LedgerAccountCode.SELLER_PAYABLE;
    }
  | {
      readonly kind: 'PREPAID_UNSETTLED';
      /**
       * A provider payment is a credit balance on the receivable until
       * settlement discharges it; wallet credit was spent straight into
       * platform cash.
       */
      readonly heldIn:
        | typeof LedgerAccountCode.GATEWAY_RECEIVABLE
        | typeof LedgerAccountCode.PLATFORM_CASH;
    }
  | { readonly kind: 'NOTHING_COLLECTED' };

/** The shape `fundingFor` needs to have been read about a parcel. */
export interface FundingSubject {
  readonly id: string;
  readonly escrowReleased: boolean;
  readonly order: {
    readonly payment: {
      readonly status: PaymentStatus;
      readonly method: PaymentMethodType;
    } | null;
  };
}

/**
 * Money going back to a customer for a sale that did not happen.
 *
 * Returns have their own service, because goods coming back raise questions
 * this one never has to ask — who was at fault, who pays the return leg, how
 * much of the parcel came back. What the two share is the question *underneath*
 * both: whose money is this now, and which account is holding it. That lives
 * here, and `ReturnRefundsService` asks this service rather than deciding
 * twice.
 *
 * The other half is the case nobody had built at all: a parcel cancelled
 * before it shipped. Cancelling used to move it to `REFUND_PENDING` and stop —
 * a status promising a refund that no code path could pay. Since a cancelled
 * parcel is never delivered, and delivery is what settles a sale, the money is
 * always still whole; the refund is a single unwinding of her payment, with no
 * seller to unwind and no commission to give back.
 */
@Injectable()
export class CustomerRefundsService {
  private readonly logger = new Logger(CustomerRefundsService.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly ledger: LedgerService,
    private readonly wallets: WalletService,
    private readonly workflow: SellerOrderWorkflowService,
    private readonly financialAudit: FinancialAuditService,
  ) {}

  /**
   * How far the money got before the sale came undone.
   *
   * Read from the ledger, not from a status: the settle entry either exists or
   * it does not, and a status can be wrong in ways an entry cannot.
   */
  async fundingFor(
    sellerOrder: FundingSubject,
    db: Tx | PrismaService = this.prisma,
  ): Promise<RefundFunding> {
    const settled = await db.journalEntry.findUnique({
      where: { reference: `settle:${sellerOrder.id}` },
      select: { id: true },
    });

    if (settled) {
      return {
        kind: 'SETTLED',
        sellerAccount: sellerOrder.escrowReleased
          ? LedgerAccountCode.SELLER_PAYABLE
          : LedgerAccountCode.SELLER_ESCROW,
      };
    }

    const payment = sellerOrder.order.payment;
    if (payment?.status !== PaymentStatus.PAID) {
      return { kind: 'NOTHING_COLLECTED' };
    }

    switch (payment.method) {
      case PaymentMethodType.PLATFORM_WALLET:
        // The wallet spend already moved her credit into platform cash, so
        // that is where it goes back from.
        return {
          kind: 'PREPAID_UNSETTLED',
          heldIn: LedgerAccountCode.PLATFORM_CASH,
        };

      case PaymentMethodType.COD:
      case PaymentMethodType.COURIER_COLLECT:
        // Cash at the door is only ever booked *by* settlement. Paid but
        // unsettled means the collection never reached the books — there is
        // nothing to un-book, and inventing an entry would create money.
        this.logger.warn(
          `Sub-order ${sellerOrder.id} is marked paid by ${payment.method} but ` +
            'was never settled — the collection is missing from the ledger and ' +
            'needs reconciling before any refund of it means anything',
        );
        return { kind: 'NOTHING_COLLECTED' };

      default:
        return {
          kind: 'PREPAID_UNSETTLED',
          heldIn: LedgerAccountCode.GATEWAY_RECEIVABLE,
        };
    }
  }

  // ── Cancellations ─────────────────────────────────────────────────────

  /**
   * Pays back a parcel that will never be delivered.
   *
   * Two things end a sale this way and they differ in one figure: a
   * cancellation happens before the van goes out, a refusal at the door
   * happens after it already did (Q37 keeps them as separate states for
   * exactly this reason). So the delivery fee comes back for the first and
   * not the second — she cannot be charged for a journey nobody made, and the
   * platform cannot eat one it did.
   *
   * The distinction is read from the parcel's own status rather than passed
   * in: a caller that has to remember which kind of ending this was is a
   * caller that will eventually refund the wrong amount.
   *
   * Idempotent through the entry's reference and through the status check, so
   * the sweep below and a hand-triggered call cannot pay twice.
   */
  async refundUndeliveredParcel(
    sellerOrderId: string,
    actorId: string | null,
  ): Promise<{ refunded: Money }> {
    const parcel = await this.prisma.sellerOrder.findUnique({
      where: { id: sellerOrderId },
      include: {
        order: {
          select: {
            id: true,
            userId: true,
            shippingTotal: true,
            payment: { select: { status: true, method: true } },
          },
        },
      },
    });
    if (!parcel) throw new NotFoundException('Sub-order not found');

    const currency = parcel.currency;
    const zero = Money.zero(currency);

    if (!REFUNDABLE_ENDINGS.includes(parcel.status)) {
      // Nothing owed, or already paid. Either way this is not an error: the
      // sweep runs over everything and the answer for most of it is "no".
      return { refunded: zero };
    }

    // The van went out for a refusal, so its fee stays earned.
    const wasRefused =
      parcel.status === SellerOrderStatus.REJECTED_ON_DELIVERY;

    const funding = await this.fundingFor(parcel);
    const goods = Money.of(parcel.itemsSubtotal, currency).minus(
      Money.of(parcel.discountTotal, currency),
    );
    const shipping = wasRefused
      ? zero
      : await this.refundableShipping(parcel, currency);
    const refund = goods.plus(shipping);

    if (funding.kind === 'NOTHING_COLLECTED' || refund.isZero()) {
      // A cash-on-delivery parcel nobody paid for — cancelled before anyone
      // knocked, or turned away at the door. There is nothing to give back,
      // and the parcel is deliberately *not* walked on to `REFUNDED`: that
      // status claims money went back to her, while «ملغي» and «مرفوض عند
      // الاستلام» are already the true and final description of what happened.
      this.logger.log(
        `No refund owed on ${parcel.number} (${parcel.status}, ${funding.kind})`,
      );
      return { refunded: zero };
    }

    const customerId = parcel.order.userId;
    if (!customerId) {
      // Q46 P1 lets guests buy; a guest has no wallet to credit, and inventing
      // one for a woman who never made an account would hide a cash refund
      // somebody has to hand over by hand.
      throw new NotFoundException(
        'This order has no registered customer — refund it manually',
      );
    }

    await this.prisma.$transaction(async (tx) => {
      const entry = await this.ledger.post(
        {
          type: JournalEntryType.REFUND_ISSUED,
          reference: `cancellation-refund:${sellerOrderId}`,
          description: `Cancelled parcel refunded — ${parcel.number}`,
          orderId: parcel.orderId,
          sellerOrderId,
          createdById: actorId,
          lines: this.cancellationLines(
            funding,
            parcel.sellerId,
            customerId,
            refund,
            Money.of(parcel.sellerNet, currency),
            Money.of(parcel.commissionBase, currency),
          ),
          metadata: {
            seller_order_id: sellerOrderId,
            funding: funding.kind,
            goods: goods.toJSON(),
            shipping: shipping.toJSON(),
          } as Prisma.InputJsonValue,
        },
        tx,
      );

      await this.wallets.recordPostedCredit(
        {
          userId: customerId,
          amount: refund,
          source: WalletTransactionSource.ORDER_REVERSAL,
          reason: `إلغاء الطلب ${parcel.number}`,
          reference: `cancellation-refund:${sellerOrderId}`,
          orderId: parcel.orderId,
          journalEntryId: entry.id,
          createdById: actorId,
        },
        tx,
      );

      await this.close(tx, sellerOrderId, refund, actorId);
    });

    // Q65 — money moving towards a customer, with a name against it.
    await this.financialAudit.record({
      action: FinancialAction.CancellationRefunded,
      actorId,
      subjectId: sellerOrderId,
      subjectType: 'seller_order',
      after: refund,
      reason: parcel.cancellationReason ?? 'Order cancelled',
      extra: {
        number: parcel.number,
        funding: funding.kind,
        goods: goods.toJSON(),
        shipping: shipping.toJSON(),
      },
    });

    return { refunded: refund };
  }

  /**
   * Pays out every parcel that ended without a delivery and still owes money.
   *
   * Neither the cancel nor the courier's screen depends on the refund
   * succeeding — a woman pressing cancel must not be told "no" because the
   * ledger was busy, and a courier must be able to record a refusal at a
   * doorstep with no signal to spare — so the parcel is left in its ending
   * state and picked up here. Hourly, next to the returns sweep.
   */
  @Cron(CronExpression.EVERY_HOUR)
  async settleUndeliveredRefunds(): Promise<{
    settled: number;
    failed: number;
  }> {
    const due = await this.prisma.sellerOrder.findMany({
      where: {
        status: { in: [...REFUNDABLE_ENDINGS] },
        // Only money that was actually taken. A cash-on-delivery parcel
        // refused at the door was never paid for, and the service answers
        // "nothing owed" for it anyway — this just keeps the sweep small.
        order: { payment: { status: PaymentStatus.PAID } },
        // A parcel that ended this way through a return belongs to the returns
        // sweep, which knows what came back and who bears the leg.
        returns: { none: {} },
      },
      select: { id: true, number: true },
    });

    let settled = 0;
    let failed = 0;
    for (const parcel of due) {
      try {
        await this.refundUndeliveredParcel(parcel.id, null);
        settled += 1;
      } catch (error) {
        failed += 1;
        this.logger.error(
          `Could not refund cancelled parcel ${parcel.number}: ${(error as Error).message}`,
        );
      }
    }
    if (settled || failed) {
      this.logger.log(`Undelivered refunds: ${settled} paid, ${failed} failed`);
    }
    return { settled, failed };
  }

  // ── Internals ─────────────────────────────────────────────────────────

  /**
   * The delivery fee comes back only when the whole basket falls through.
   *
   * She pays shipping once for the order (Q65 P1), so cancelling one parcel of
   * three does not make the van cheaper — refunding a third of the fee would
   * be a gift. It is returned in full, on the last parcel to close, and only
   * if nothing in the order was ever delivered.
   */
  private async refundableShipping(
    parcel: { orderId: string; id: string; order: { shippingTotal: Prisma.Decimal } },
    currency: Currency,
  ): Promise<Money> {
    const siblings = await this.prisma.sellerOrder.findMany({
      where: { orderId: parcel.orderId, id: { not: parcel.id } },
      select: { status: true, deliveredAt: true },
    });

    const anythingDelivered = siblings.some(
      (sibling) => sibling.deliveredAt !== null,
    );
    if (anythingDelivered) return Money.zero(currency);

    const stillLive = siblings.some(
      (sibling) =>
        !CANCELLED_STATUSES.includes(sibling.status) &&
        sibling.status !== SellerOrderStatus.REFUNDED &&
        sibling.status !== SellerOrderStatus.REFUND_PENDING,
    );
    if (stillLive) return Money.zero(currency);

    return Money.of(parcel.order.shippingTotal, currency);
  }

  /** Who gives the money back, and where it lands. */
  private cancellationLines(
    funding: RefundFunding,
    sellerId: string,
    customerId: string,
    refund: Money,
    sellerNet: Money,
    commissionBase: Money,
  ): PostingLine[] {
    const lines: PostingLine[] = [
      {
        account: {
          code: LedgerAccountCode.CUSTOMER_WALLET,
          ownerId: customerId,
        },
        direction: LedgerDirection.CREDIT,
        amount: refund,
        memo: 'Refunded to wallet',
      },
    ];

    if (funding.kind === 'PREPAID_UNSETTLED') {
      lines.push({
        account: { code: funding.heldIn },
        direction: LedgerDirection.DEBIT,
        amount: refund,
        memo: 'Payment returned for a cancelled parcel',
      });
      return lines;
    }

    // A settled parcel should be unreachable here — the lifecycle table has no
    // edge from `DELIVERED` to either cancellation — but a sale that somehow
    // both settled and cancelled is unwound the way any settled sale is: each
    // party gives back what it took.
    if (funding.kind === 'SETTLED') {
      const platformShare = commissionBase.minus(sellerNet);
      if (!sellerNet.isZero()) {
        lines.push({
          account: { code: funding.sellerAccount, ownerId: sellerId },
          direction: LedgerDirection.DEBIT,
          amount: sellerNet,
          memo: 'Seller net returned',
        });
      }
      if (!platformShare.isZero()) {
        lines.push({
          account: { code: LedgerAccountCode.COMMISSION_REVENUE },
          direction: LedgerDirection.DEBIT,
          amount: platformShare,
          memo: 'Commission on a cancelled sale',
        });
      }

      // Whatever the two shares do not cover is the delivery fee, which the
      // platform took as revenue and now gives back.
      const covered = sellerNet.plus(platformShare);
      const shipping = refund.minus(covered);
      if (!shipping.isZero() && !shipping.isNegative()) {
        lines.push({
          account: { code: LedgerAccountCode.SHIPPING_REVENUE },
          direction: LedgerDirection.DEBIT,
          amount: shipping,
          memo: 'Delivery fee returned',
        });
      }
    }

    return lines;
  }

  /**
   * Closes the parcel, whether or not any money moved.
   *
   * `REFUND_PENDING` is walked through rather than skipped: it is a real state
   * in Q37's list, and a timeline that jumps from cancelled straight to
   * refunded hides the moment the money was actually owed. The caller sets the
   * parcel down in a cancelled or refused state and this walks it the rest of
   * the way, which is what keeps the two ends of a refund — the entry and the
   * status — impossible to separate.
   */
  private async close(
    tx: Tx,
    sellerOrderId: string,
    refund: Money,
    actorId: string | null,
  ): Promise<void> {
    const actor: WorkflowActor = actorId
      ? { id: actorId, role: 'ADMIN' }
      : SYSTEM_ACTOR;

    const current = await tx.sellerOrder.findUniqueOrThrow({
      where: { id: sellerOrderId },
      select: { status: true },
    });

    if (current.status !== SellerOrderStatus.REFUND_PENDING) {
      await this.workflow.move(
        tx,
        sellerOrderId,
        SellerOrderStatus.REFUND_PENDING,
        actor,
        {
          title: 'Refund pending',
          description: refund.isZero()
            ? 'Nothing had been collected for this parcel'
            : refund.toString(),
        },
      );
    }

    await this.workflow.move(
      tx,
      sellerOrderId,
      SellerOrderStatus.REFUNDED,
      actor,
      {
        title: 'Refunded',
        description: refund.isZero()
          ? 'Nothing had been collected for this parcel'
          : refund.toString(),
      },
    );
  }
}
