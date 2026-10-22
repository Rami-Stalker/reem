import { Injectable, Logger, NotFoundException } from '@nestjs/common';
import {
  Currency,
  JournalEntryType,
  LedgerAccountCode,
  LedgerDirection,
  PaymentMethodType,
  PaymentStatus,
  Prisma,
  ReturnCostBearer,
  WalletTransactionSource,
} from '@prisma/client';

import { Money } from '../../common/money';
import { PrismaService } from '../../prisma/prisma.service';
import { OrderEventCopy } from '../../common/orders/order-event-copy';
import { LedgerService, PostingLine } from '../ledger/ledger.service';
import { WalletService } from '../ledger/wallet.service';
import { CommissionsService } from '../commissions/commissions.service';
import {
  CustomerRefundsService,
  RefundFunding,
} from '../finance/customer-refunds.service';
import {
  FinancialAction,
  FinancialAuditService,
} from '../finance/financial-audit.service';

type Tx = Prisma.TransactionClient;

/** One returned line, and what the customer actually paid for those units. */
export interface RefundLine {
  readonly orderItemId: string;
  readonly title: string;
  readonly quantity: number;
  readonly paid: Money;
}

export interface RefundBreakdown {
  readonly currency: Currency;
  readonly funding: RefundFunding;
  /** What the customer paid for the units coming back. */
  readonly goods: Money;
  /** The seller's share of that, given back out of escrow or payable. */
  readonly sellerShare: Money;
  /** The commission and platform fee the platform gives back. */
  readonly platformShare: Money;
  /** Q56 P1 — the cost of the return leg, and who Q67 puts it on. */
  readonly returnShippingFee: Money;
  readonly borneBy: ReturnCostBearer | null;
  /** What actually lands in her wallet: goods, less any fee she bears. */
  readonly customerRefund: Money;
  readonly lines: readonly RefundLine[];
  /** True when the whole parcel came back. */
  readonly isFullParcel: boolean;
}

/**
 * The money side of a return.
 *
 * A refund is not "a payment in reverse". The customer's money was split the
 * moment the parcel was delivered — the seller's net into escrow, the
 * commission into platform revenue — so giving it back means both parties
 * unwinding their share, in one balanced entry, in the proportion they took
 * it. Anything else silently moves value between the seller and the platform
 * under cover of a customer refund.
 *
 * The refund lands in the customer's wallet, which is what Q41 lists first
 * among the ways a wallet is funded («قيمة المرتجعات») and what Q42's
 * spend-only rule assumes.
 */
@Injectable()
export class ReturnRefundsService {
  private readonly logger = new Logger(ReturnRefundsService.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly ledger: LedgerService,
    private readonly wallets: WalletService,
    private readonly commissions: CommissionsService,
    private readonly financialAudit: FinancialAuditService,
    // Whose money this is, and which account is holding it, is the same
    // question a cancellation asks. It must not be answered twice.
    private readonly refunds: CustomerRefundsService,
  ) {}

  /**
   * What a return is worth, without moving anything.
   *
   * Shown to the customer before she commits and to the seller before she
   * approves, and re-computed at settlement rather than trusted from a stored
   * figure — a quote that silently ages into a different number is how support
   * arguments start.
   */
  async quote(returnId: string, tx?: Tx): Promise<RefundBreakdown> {
    const db = tx ?? this.prisma;
    const request = await db.returnRequest.findUnique({
      where: { id: returnId },
      include: {
        items: { include: { orderItem: true } },
        sellerOrder: {
          include: {
            items: { select: { id: true, lineTotal: true, quantity: true } },
            order: {
              select: {
                id: true,
                userId: true,
                payment: { select: { status: true, method: true } },
              },
            },
          },
        },
      },
    });
    if (!request) throw new NotFoundException('Return request not found');

    const funding = await this.refunds.fundingFor(request.sellerOrder, db);
    return this.compute(request, funding);
  }

  /**
   * Posts the refund and credits the wallet.
   *
   * Runs inside the caller's transaction: the return's status, the sub-order's
   * status and the money are one fact, and a refund that committed while the
   * status update rolled back would be paid again the next time someone
   * pressed the button. The ledger's idempotency on `reference` catches that
   * too — belt and braces, because this one is expensive to get wrong.
   */
  async settle(
    returnId: string,
    actorId: string | null,
    tx: Tx,
  ): Promise<RefundBreakdown> {
    const breakdown = await this.quote(returnId, tx);
    const request = await tx.returnRequest.findUniqueOrThrow({
      where: { id: returnId },
      include: {
        sellerOrder: {
          select: {
            id: true,
            number: true,
            sellerId: true,
            orderId: true,
            order: { select: { userId: true } },
          },
        },
      },
    });

    const { sellerOrder } = request;
    const customerId = sellerOrder.order.userId;

    if (breakdown.customerRefund.isZero() && breakdown.sellerShare.isZero()) {
      // A cash-on-delivery parcel refused at the door: nothing was ever
      // collected, so there is nothing to give back. Recorded rather than
      // silently skipped — "no money moved" is itself an answer support will
      // be asked for.
      this.logger.log(
        `Return ${request.number} settled with no movement (${breakdown.funding.kind})`,
      );
      await tx.returnRequest.update({
        where: { id: returnId },
        data: {
          currency: breakdown.currency,
          refundAmount: breakdown.customerRefund.toPrisma(),
        },
      });
      return breakdown;
    }

    if (!customerId) {
      // A guest order (Q46 P1) has no wallet to credit. Refusing is right: the
      // alternative is inventing a wallet for someone who never made an
      // account, and hiding a cash refund somebody has to hand over by hand.
      throw new NotFoundException(
        'This order has no registered customer — refund it manually',
      );
    }

    const lines = this.postingLines(breakdown, sellerOrder.sellerId, customerId);

    const entry = await this.ledger.post(
      {
        type: JournalEntryType.RETURN_SETTLED,
        reference: `return-refund:${returnId}`,
        description: OrderEventCopy.returnRefunded(
          request.number,
          sellerOrder.number,
        ),
        orderId: sellerOrder.orderId,
        sellerOrderId: sellerOrder.id,
        createdById: actorId,
        lines,
        metadata: {
          return_id: returnId,
          funding: breakdown.funding.kind,
          goods: breakdown.goods.toJSON(),
          seller_share: breakdown.sellerShare.toJSON(),
          platform_share: breakdown.platformShare.toJSON(),
          return_shipping_fee: breakdown.returnShippingFee.toJSON(),
          borne_by: breakdown.borneBy,
          is_full_parcel: breakdown.isFullParcel,
        } as Prisma.InputJsonValue,
      },
      tx,
    );

    if (!breakdown.customerRefund.isZero()) {
      await this.wallets.recordPostedCredit(
        {
          userId: customerId,
          amount: breakdown.customerRefund,
          source: WalletTransactionSource.RETURN_REFUND,
          reason: `قيمة مرتجع ${request.number}`,
          reference: `return-refund:${returnId}`,
          orderId: sellerOrder.orderId,
          journalEntryId: entry.id,
          createdById: actorId,
        },
        tx,
      );
    }

    await tx.returnRequest.update({
      where: { id: returnId },
      data: {
        currency: breakdown.currency,
        refundAmount: breakdown.customerRefund.toPrisma(),
      },
    });

    await this.warnIfOverdrawn(breakdown, sellerOrder.sellerId, tx);

    // Q65 — a refund moves money away from a seller and towards a customer.
    await this.financialAudit.record({
      action: FinancialAction.ReturnRefunded,
      actorId,
      subjectId: returnId,
      subjectType: 'return_request',
      after: breakdown.customerRefund,
      reason: `Return ${request.number}`,
      extra: {
        seller_order_id: sellerOrder.id,
        seller_id: sellerOrder.sellerId,
        seller_share: breakdown.sellerShare.toJSON(),
        platform_share: breakdown.platformShare.toJSON(),
        return_shipping_fee: breakdown.returnShippingFee.toJSON(),
        borne_by: breakdown.borneBy,
        funding: breakdown.funding.kind,
      },
    });

    return breakdown;
  }

  /**
   * The denormalised admin feed and the commission row have a whole-sub-order
   * shape, so they are reversed for a full return and left alone for a partial
   * one rather than being made to half-mean something. The journal entry is
   * the record either way.
   *
   * Called after the transaction commits: `CommissionsService` opens its own,
   * and nesting one inside another deadlocks on the rows this one holds.
   */
  async reverseCommissionIfWhole(
    breakdown: RefundBreakdown,
    sellerOrderId: string,
    returnNumber: string,
  ): Promise<void> {
    if (!breakdown.isFullParcel || breakdown.funding.kind !== 'SETTLED') return;
    await this.commissions.reverseSellerOrder(
      sellerOrderId,
      `Return ${returnNumber}`,
    );
  }

  // ── Internals ─────────────────────────────────────────────────────────

  /**
   * What the customer paid for the units coming back, and how that splits.
   *
   * Two subtleties decide the arithmetic:
   *
   * 1. **A coupon is not per line.** Checkout allocates the basket's discount
   *    across sub-orders, and the sub-order carries one `discountTotal` for
   *    all its lines. Refunding `lineTotal` would hand back list price for
   *    goods bought at a discount, so the discount is re-allocated across the
   *    lines by value and each line refunds what was paid for it.
   * 2. **Part of a line may come back.** The per-line amount is allocated
   *    across its own units before the returned ones are taken, so three units
   *    of an odd amount can never refund more in pieces than as a whole.
   *
   * `Money.allocate` is used for both, which is what makes the parts add back
   * up to the whole exactly — the remainder lands on the first shares rather
   * than evaporating into rounding.
   */
  private compute(
    request: {
      shippingBorneBy: ReturnCostBearer | null;
      items: Array<{
        quantity: number;
        orderItem: {
          id: string;
          titleSnapshot: string;
          quantity: number;
          lineTotal: Prisma.Decimal;
        };
      }>;
      sellerOrder: {
        currency: Currency;
        itemsSubtotal: Prisma.Decimal;
        discountTotal: Prisma.Decimal;
        shippingCost: Prisma.Decimal;
        sellerNet: Prisma.Decimal;
        items: Array<{ id: string; lineTotal: Prisma.Decimal; quantity: number }>;
      };
    },
    funding: RefundFunding,
  ): RefundBreakdown {
    const currency = request.sellerOrder.currency;
    const zero = Money.zero(currency);

    const parcelLines = request.sellerOrder.items;
    const discountShares = Money.of(
      request.sellerOrder.discountTotal,
      currency,
    ).allocate(parcelLines.map((line) => line.lineTotal));

    const paidByItemId = new Map<string, Money>();
    parcelLines.forEach((line, index) => {
      paidByItemId.set(
        line.id,
        Money.of(line.lineTotal, currency).minus(discountShares[index]),
      );
    });

    const lines: RefundLine[] = request.items.map((item) => {
      const paidForLine = paidByItemId.get(item.orderItem.id) ?? zero;
      const perUnit = paidForLine.allocate(
        Array.from({ length: item.orderItem.quantity }, () => 1),
      );
      const paid = Money.sum(perUnit.slice(0, item.quantity), currency);
      return {
        orderItemId: item.orderItem.id,
        title: item.orderItem.titleSnapshot,
        quantity: item.quantity,
        paid,
      };
    });

    const goods = Money.sum(
      lines.map((line) => line.paid),
      currency,
    );

    const isFullParcel = this.coversWholeParcel(request);

    // Nothing was collected, so nothing is given back — but the return itself
    // is still a real event with real goods moving.
    if (funding.kind === 'NOTHING_COLLECTED') {
      return {
        currency,
        funding,
        goods,
        sellerShare: zero,
        platformShare: zero,
        returnShippingFee: zero,
        borneBy: request.shippingBorneBy,
        customerRefund: zero,
        lines,
        isFullParcel,
      };
    }

    const { sellerShare, platformShare } = this.splitGoods(
      goods,
      request.sellerOrder,
      funding,
    );

    // Q56 P1 — the return leg costs what the outbound leg cost, since it is
    // the same route (Q53's per-governorate tiers price a journey, not a
    // direction). Whoever approves the return may say otherwise by writing a
    // different bearer, and an admin may waive it entirely.
    const fee = Money.of(request.sellerOrder.shippingCost, currency);
    const bearsIt = request.shippingBorneBy;
    const charged =
      bearsIt === ReturnCostBearer.CUSTOMER || bearsIt === ReturnCostBearer.SELLER
        ? fee
        : zero;

    // She cannot end up owing us for the privilege of returning: the fee is
    // recovered from the refund, never beyond it. A fee larger than the goods
    // is a case for a human, not for a negative wallet credit.
    const recovered =
      bearsIt === ReturnCostBearer.CUSTOMER ? charged.clampMax(goods) : charged;

    const customerRefund =
      bearsIt === ReturnCostBearer.CUSTOMER ? goods.minus(recovered) : goods;

    return {
      currency,
      funding,
      goods,
      sellerShare,
      platformShare,
      returnShippingFee: recovered,
      borneBy: bearsIt,
      customerRefund,
      lines,
      isFullParcel,
    };
  }

  /**
   * Splits the refunded goods between the two parties that received them.
   *
   * The weights are the settlement's own: the seller was credited her net and
   * the platform the rest, so each gives back in the proportion it took. For a
   * whole parcel with no coupon that is an exact reversal of the settle entry;
   * for anything smaller it is the only split that leaves neither party better
   * off than the other for having been refunded.
   */
  private splitGoods(
    goods: Money,
    sellerOrder: {
      currency: Currency;
      itemsSubtotal: Prisma.Decimal;
      sellerNet: Prisma.Decimal;
    },
    funding: RefundFunding,
  ): { sellerShare: Money; platformShare: Money } {
    const currency = sellerOrder.currency;

    // Never settled: the seller was credited nothing, so she gives back
    // nothing and the platform returns the cash it is still holding.
    if (funding.kind !== 'SETTLED') {
      return { sellerShare: Money.zero(currency), platformShare: goods };
    }

    const net = Money.of(sellerOrder.sellerNet, currency);
    const platform = Money.of(sellerOrder.itemsSubtotal, currency).minus(net);

    if (net.plus(platform).isZero()) {
      // A parcel worth nothing cannot be split by value, and has nothing to
      // give back either.
      return { sellerShare: Money.zero(currency), platformShare: goods };
    }

    const [sellerShare, platformShare] = goods.allocate([
      net.toPrisma(),
      platform.toPrisma(),
    ]);
    return { sellerShare, platformShare };
  }

  /** True when every unit of every line in the parcel is on this request. */
  private coversWholeParcel(request: {
    items: Array<{ quantity: number; orderItem: { id: string } }>;
    sellerOrder: { items: Array<{ id: string; quantity: number }> };
  }): boolean {
    const claimed = new Map<string, number>();
    for (const item of request.items) {
      claimed.set(
        item.orderItem.id,
        (claimed.get(item.orderItem.id) ?? 0) + item.quantity,
      );
    }
    return request.sellerOrder.items.every(
      (line) => (claimed.get(line.id) ?? 0) >= line.quantity,
    );
  }

  /** The journal entry: who gives the money back, and where it lands. */
  private postingLines(
    breakdown: RefundBreakdown,
    sellerId: string,
    customerId: string,
  ): PostingLine[] {
    const lines: PostingLine[] = [];

    if (breakdown.funding.kind === 'SETTLED') {
      if (!breakdown.sellerShare.isZero()) {
        lines.push({
          account: { code: breakdown.funding.sellerAccount, ownerId: sellerId },
          direction: LedgerDirection.DEBIT,
          amount: breakdown.sellerShare,
          memo: 'Seller net returned',
        });
      }
      if (!breakdown.platformShare.isZero()) {
        // Contra-revenue: the commission was earned on a sale that partly
        // un-happened, so the revenue account gives its share back. Booking a
        // new expense instead would leave the original commission standing in
        // the accounts for ever, and every revenue report would be wrong by
        // the value of everything ever returned.
        lines.push({
          account: { code: LedgerAccountCode.COMMISSION_REVENUE },
          direction: LedgerDirection.DEBIT,
          amount: breakdown.platformShare,
          memo: 'Commission on returned goods',
        });
      }
    } else if (
      breakdown.funding.kind === 'PREPAID_UNSETTLED' &&
      !breakdown.goods.isZero()
    ) {
      // Captured but never settled — refused at the door, say.
      //
      // A provider capture posts cash in against `GATEWAY_RECEIVABLE`, and
      // settlement is what would later have debited that receivable back out
      // into escrow and commission. Between the two, her money sits as a
      // credit balance there: cash we hold for goods nobody has received.
      // Wallet credit, spent straight into platform cash, sits in that
      // instead. Either way the refund debits the account the money actually
      // reached, which unwinds the payment exactly — and no cash leaves the
      // building, because Q42's credit is spendable here and never cashed
      // out.
      lines.push({
        account: { code: breakdown.funding.heldIn },
        direction: LedgerDirection.DEBIT,
        amount: breakdown.goods,
        memo: 'Prepayment returned before the sale settled',
      });
    }

    if (
      breakdown.borneBy === ReturnCostBearer.SELLER &&
      !breakdown.returnShippingFee.isZero()
    ) {
      // Q56 P1 — «إذا كان الخطأ من البائع، يتحمل البائع أجور الإرجاع». The
      // seller pays the platform for carrying the goods back: real revenue for
      // a real journey, not a reversal of anything.
      const sellerAccount =
        breakdown.funding.kind === 'SETTLED'
          ? breakdown.funding.sellerAccount
          : LedgerAccountCode.SELLER_PAYABLE;
      lines.push({
        account: { code: sellerAccount, ownerId: sellerId },
        direction: LedgerDirection.DEBIT,
        amount: breakdown.returnShippingFee,
        memo: 'Return shipping borne by the seller',
      });
    }

    if (!breakdown.customerRefund.isZero()) {
      lines.push({
        account: {
          code: LedgerAccountCode.CUSTOMER_WALLET,
          ownerId: customerId,
        },
        direction: LedgerDirection.CREDIT,
        amount: breakdown.customerRefund,
        memo: 'Refunded to wallet',
      });
    }

    if (
      !breakdown.returnShippingFee.isZero() &&
      breakdown.borneBy !== ReturnCostBearer.PLATFORM
    ) {
      lines.push({
        account: { code: LedgerAccountCode.SHIPPING_REVENUE },
        direction: LedgerDirection.CREDIT,
        amount: breakdown.returnShippingFee,
        memo: 'Return leg',
      });
    }

    // A platform-borne return leg posts nothing on purpose. Our own couriers
    // carry it, their wages are already an expense elsewhere, and a fee the
    // platform charges itself would inflate both sides of the accounts with a
    // journey nobody paid for.
    return lines;
  }

  /**
   * Refunding a seller who has already been paid drives her payable negative,
   * which is a real debt worked off against her next payout — but it also
   * trips the reconciliation job's negative-liability check, so it is logged
   * here with a name attached. A silent negative would be indistinguishable
   * from a bug in the ledger.
   */
  private async warnIfOverdrawn(
    breakdown: RefundBreakdown,
    sellerId: string,
    tx: Tx,
  ): Promise<void> {
    if (breakdown.funding.kind !== 'SETTLED') return;

    const balance = await this.ledger.balanceOf(
      { code: breakdown.funding.sellerAccount, ownerId: sellerId },
      breakdown.currency,
      tx,
    );
    if (balance.isNegative()) {
      this.logger.warn(
        `Seller ${sellerId} now owes ${balance.negated().toString()} on ` +
          `${breakdown.funding.sellerAccount} after a refund — recover it from ` +
          'the next payout',
      );
    }
  }
}
