import {
  BadRequestException,
  ConflictException,
  ForbiddenException,
  Injectable,
  Logger,
  NotFoundException,
  Optional,
} from '@nestjs/common';
import {
  CommissionLedger,
  CommissionRule,
  CommissionStatus,
  Currency,
  DisputeStatus,
  FinancialLedgerType,
  JournalEntryType,
  LedgerAccountCode,
  LedgerDirection,
  PaymentMethodType,
  PayoutStatus,
  Prisma,
  SellerPayout,
  UserRole,
} from '@prisma/client';
import { PrismaService } from '../../prisma/prisma.service';
import { Money, REVENUE_STATUSES } from '../../common/money';
import { LedgerService, PostingLine } from '../ledger/ledger.service';
import { LoyaltyService } from '../finance/loyalty.service';
import { PurchaseRewardsService } from '../rewards/purchase-rewards.service';
import {
  assertCommissionLedgerChange,
  assertPayoutTransition,
  lockSellerPayouts,
  payableHeadroom,
} from '../finance/payout-headroom';
import { LIVE_RETURN_STATUSES } from '../returns/return-policy';
import {
  FinancialAction,
  FinancialAuditService,
} from '../finance/financial-audit.service';
import {
  CommissionLedgerStatusDto,
  CommissionReportQueryDto,
  CommissionRuleDto,
  PayoutCalculationDto,
  PayoutStatusDto,
} from './dto/commission.dto';

const Decimal = Prisma.Decimal;

/**
 * How many parcels one escrow sweep will release.
 *
 * Large enough that a normal night clears in a single run, small enough that
 * the first run after a long outage does not hold every due parcel since
 * launch in memory while it posts to the ledger for each one. A backlog
 * drains over consecutive runs, which is safe because the sweep re-selects
 * from the database every time.
 */
const ESCROW_RELEASE_BATCH = 500;

/** Rulings after which a dispute no longer holds a parcel's escrow. */
const DECIDED_DISPUTE_STATUSES: readonly DisputeStatus[] = [
  DisputeStatus.RESOLVED_FOR_CUSTOMER,
  DisputeStatus.RESOLVED_FOR_SELLER,
  DisputeStatus.RESOLVED_SPLIT,
  DisputeStatus.CLOSED,
];

/**
 * Commission settlement and seller payouts.
 *
 * Settlement is now per SUB-ORDER, not per order: the commission was already
 * priced at checkout against that seller's post-discount total (Q50 P2), so
 * settling is a matter of recording it, not recomputing it. That removes the
 * old bug where an order's commission was derived by walking
 * `OrderItem → Product.sellerId`, which broke the moment a product changed
 * hands and double-counted multi-seller baskets.
 */
@Injectable()
export class CommissionsService {
  private readonly logger = new Logger(CommissionsService.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly ledger: LedgerService,
    private readonly loyalty: LoyaltyService,
    private readonly financialAudit: FinancialAuditService,
    @Optional()
    private readonly purchaseRewards?: PurchaseRewardsService,
  ) {}

  // ── Rules ───────────────────────────────────────────────────────────────

  async createRule(dto: CommissionRuleDto) {
    const currency = dto.currency ?? Currency.SYP;
    const rule = await this.prisma.commissionRule.create({
      data: {
        name: dto.name.trim(),
        rateBps: dto.rate_bps,
        platformFeeBps: dto.platform_fee_bps ?? 0,
        currency,
        fixedFee: new Decimal(dto.fixed_fee ?? 0),
        minCommission:
          dto.min_commission != null ? new Decimal(dto.min_commission) : null,
        maxCommission:
          dto.max_commission != null ? new Decimal(dto.max_commission) : null,
        category: dto.category?.toLowerCase().trim() || null,
        sellerTier: dto.seller_tier?.trim() || null,
        priority: dto.priority ?? 100,
      },
    });
    return this.serializeRule(rule);
  }

  async rules() {
    const rules = await this.prisma.commissionRule.findMany({
      orderBy: [{ active: 'desc' }, { priority: 'asc' }, { createdAt: 'desc' }],
    });
    return rules.map((rule) => this.serializeRule(rule));
  }

  // ── Settlement ──────────────────────────────────────────────────────────

  /** Settles every revenue-bearing sub-order of a parent order. */
  async settleOrder(orderId: string) {
    const sellerOrders = await this.prisma.sellerOrder.findMany({
      where: { orderId },
      select: { id: true, status: true },
    });
    if (sellerOrders.length === 0) {
      throw new NotFoundException('Order not found');
    }

    let settled = 0;
    for (const sellerOrder of sellerOrders) {
      if (!REVENUE_STATUSES.includes(sellerOrder.status)) continue;
      await this.settleSellerOrder(sellerOrder.id);
      settled += 1;
    }
    return {
      settled,
      ...(settled === 0
        ? { reason: 'No sub-order is revenue-bearing yet' }
        : {}),
    };
  }

  /**
   * Records one seller's commission. Idempotent: re-running never doubles a
   * ledger row, and never downgrades one that has already been paid out.
   */
  async settleSellerOrder(sellerOrderId: string) {
    const sellerOrder = await this.prisma.sellerOrder.findUnique({
      where: { id: sellerOrderId },
      include: {
        items: true,
        shipment: {
          select: {
            courierId: true,
            // What the carrier charged for this journey. Lives on the dispatch
            // because that is the row the adapter wrote after the carrier
            // answered; a parcel carried without a dispatch (a rider assigned
            // by hand) has no quoted fee and accrues nothing.
            dispatch: {
              select: { id: true, feeAmount: true, feeCurrency: true },
            },
          },
        },
        order: { select: { payment: { select: { method: true } } } },
      },
    });
    if (!sellerOrder) throw new NotFoundException('Sub-order not found');

    const currency = sellerOrder.currency;

    // What the customer actually handed over for these goods. The sub-order's
    // `itemsSubtotal` is the list price; a coupon lives in `discountTotal`.
    const customerPaid = Money.of(sellerOrder.itemsSubtotal, currency).minus(
      Money.of(sellerOrder.discountTotal, currency),
    );

    // The value the sale is measured by. For a seller-funded coupon this is
    // what the customer paid; for a platform-funded one (Q49 P2 — «يتحملها من
    // أنشأ الكوبون») checkout leaves the base at the list price, because the
    // seller sold at full price and the platform made up the difference.
    const gross = Money.of(sellerOrder.commissionBase, currency);

    // …which makes the platform's own contribution derivable rather than
    // stored: the base we charged commission on, less what the customer paid.
    // Zero whenever the seller funded the discount herself.
    const platformFundedDiscount = gross
      .minus(customerPaid)
      .clampMin(Money.zero(currency));

    // Q65 P1 — the customer pays shipping once for the basket; each parcel
    // carries its allocated share.
    const shipping = Money.of(sellerOrder.shippingCost, currency);

    const commission = Money.of(sellerOrder.commissionAmount, currency);
    const net = Money.of(sellerOrder.sellerNet, currency);
    const platformFee = gross.minus(commission).minus(net);

    const existing = await this.prisma.commissionLedger.findUnique({
      where: { sellerOrderId },
    });

    const soldLines = sellerOrder.items.map((item) => ({
      product_id: item.productId,
      offer_id: item.offerId,
      quantity: item.quantity,
      line_total: Money.of(item.lineTotal, item.currency).toJSON(),
    }));

    const ledger = await this.prisma.commissionLedger.upsert({
      where: { sellerOrderId },
      update: {
        currency,
        gross: gross.toPrisma(),
        commission: commission.toPrisma(),
        platformFee: platformFee.toPrisma(),
        net: net.toPrisma(),
        status:
          existing?.status === CommissionStatus.PAID
            ? CommissionStatus.PAID
            : CommissionStatus.EARNED,
        metadata: { lines: soldLines } as Prisma.InputJsonValue,
      },
      create: {
        sellerOrderId,
        sellerId: sellerOrder.sellerId,
        currency,
        gross: gross.toPrisma(),
        commission: commission.toPrisma(),
        platformFee: platformFee.toPrisma(),
        net: net.toPrisma(),
        status: CommissionStatus.EARNED,
        metadata: { lines: soldLines } as Prisma.InputJsonValue,
      },
    });

    // The book of record (Q52). Splitting the gross into what the seller is
    // owed and what the platform earned is the whole point of the settlement,
    // and this is the entry that says so in a form that has to balance.
    // Idempotent on the sub-order id, so re-settling never doubles anything.
    const lines: PostingLine[] = [
      // Where the money actually is right now, which is not the same as
      // "ours to spend": cash-on-delivery sits in the courier's pocket until
      // the daily settlement (Q56), and an e-payment sits with the provider
      // until it clears (Q140). Debiting platform cash for either would
      // report money we cannot yet touch.
      //
      // The figure is what the customer paid — goods after her discount, plus
      // the delivery fee. It used to be the list price, which meant the books
      // claimed we had collected money nobody ever handed over.
      {
        account: this.collectionAccount(sellerOrder),
        direction: LedgerDirection.DEBIT,
        amount: customerPaid.plus(shipping),
      },
      {
        account: {
          code: LedgerAccountCode.SELLER_ESCROW,
          ownerId: sellerOrder.sellerId,
        },
        direction: LedgerDirection.CREDIT,
        amount: net,
        memo: 'Seller net, held until the return window closes',
      },
      {
        account: { code: LedgerAccountCode.COMMISSION_REVENUE },
        direction: LedgerDirection.CREDIT,
        amount: commission.plus(platformFee),
        memo: 'Marketplace commission and platform fee',
      },
    ];

    // Q49 P2 — a platform-funded coupon is the platform's own marketing spend.
    // Without this line it was absorbed into commission revenue, which flatters
    // every revenue report by exactly the value of every discount ever given.
    if (!platformFundedDiscount.isZero()) {
      lines.push({
        account: { code: LedgerAccountCode.PLATFORM_PROMOTION_EXPENSE },
        direction: LedgerDirection.DEBIT,
        amount: platformFundedDiscount,
        memo: 'Platform-funded coupon',
      });
    }

    // The delivery fee is revenue for a journey the platform actually makes.
    // It was previously collected from the customer and booked nowhere at all.
    if (!shipping.isZero()) {
      lines.push({
        account: { code: LedgerAccountCode.SHIPPING_REVENUE },
        direction: LedgerDirection.CREDIT,
        amount: shipping,
        memo: 'Delivery fee',
      });
    }

    await this.ledger.post({
      type: JournalEntryType.COMMISSION_EARNED,
      reference: `settle:${sellerOrderId}`,
      description: `Sub-order settled — ${sellerOrder.number}`,
      orderId: sellerOrder.orderId,
      sellerOrderId,
      lines,
    });

    await this.accrueDeliveryCost(sellerOrder);

    if (!existing) {
      await this.prisma.financialLedgerEntry.createMany({
        data: [
          {
            type: FinancialLedgerType.ORDER_REVENUE,
            orderId: sellerOrder.orderId,
            sellerId: sellerOrder.sellerId,
            currency,
            amount: customerPaid.plus(shipping).toPrisma(),
            description: `Order revenue — ${sellerOrder.number}`,
            metadata: { ledger_id: ledger.id } as Prisma.InputJsonValue,
          },
          {
            type: FinancialLedgerType.COMMISSION,
            orderId: sellerOrder.orderId,
            sellerId: sellerOrder.sellerId,
            currency,
            amount: commission.plus(platformFee).toPrisma(),
            description: `Marketplace commission — ${sellerOrder.number}`,
            metadata: { ledger_id: ledger.id } as Prisma.InputJsonValue,
          },
        ],
      });
    }

    return this.serializeLedger(ledger);
  }

  /**
   * Reverses settlement for a whole order — used on a refund. Reversal is a
   * compensating entry, never a delete: the audit trail has to show that money
   * was recognised and then given back.
   */
  async reverseOrder(orderId: string, reason = 'Order refunded') {
    const ledgers = await this.prisma.commissionLedger.findMany({
      where: {
        sellerOrder: { orderId },
        status: { not: CommissionStatus.REVERSED },
      },
    });
    if (ledgers.length === 0) return { reversed: 0 };

    await this.prisma.$transaction(async (tx) => {
      for (const ledger of ledgers) {
        await tx.commissionLedger.update({
          where: { id: ledger.id },
          data: { status: CommissionStatus.REVERSED },
        });
        await tx.financialLedgerEntry.create({
          data: {
            type: FinancialLedgerType.REFUND,
            orderId,
            sellerId: ledger.sellerId,
            currency: ledger.currency,
            amount: Money.of(ledger.net, ledger.currency).negated().toPrisma(),
            description: reason,
            metadata: { ledger_id: ledger.id } as Prisma.InputJsonValue,
          },
        });
      }
    });
    return { reversed: ledgers.length };
  }

  /** Reverses one seller's parcel — the common case now that orders split. */
  async reverseSellerOrder(sellerOrderId: string, reason = 'Sub-order refunded') {
    const ledger = await this.prisma.commissionLedger.findUnique({
      where: { sellerOrderId },
      include: { sellerOrder: { select: { orderId: true } } },
    });
    if (!ledger || ledger.status === CommissionStatus.REVERSED) {
      return { reversed: 0 };
    }

    await this.prisma.$transaction(async (tx) => {
      await tx.commissionLedger.update({
        where: { id: ledger.id },
        data: { status: CommissionStatus.REVERSED },
      });
      await tx.financialLedgerEntry.create({
        data: {
          type: FinancialLedgerType.REFUND,
          orderId: ledger.sellerOrder?.orderId ?? null,
          sellerId: ledger.sellerId,
          currency: ledger.currency,
          amount: Money.of(ledger.net, ledger.currency).negated().toPrisma(),
          description: reason,
          metadata: { ledger_id: ledger.id } as Prisma.InputJsonValue,
        },
      });
    });
    return { reversed: 1 };
  }

  /**
   * Q24 P1 — releases escrow for sub-orders whose return window has closed and
   * that carry no open dispute.
   *
   * **This is the bridge between a completed sale and a payable one.**
   * `SellerPayoutsService.claimableLedgers` will only pay a ledger whose
   * sub-order has `escrowReleased: true`, so for as long as nothing calls
   * this, every payout request from every seller returns zero. It was written
   * and never scheduled; `CommissionsScheduler` is what runs it now.
   *
   * Bounded and fault-isolated, because it is a sweep over money:
   *
   * - `take` caps one run. A backlog drains over consecutive nights rather
   *   than loading every due parcel since launch into memory at once — and
   *   the sweep is idempotent, so draining across runs costs nothing.
   * - One parcel that will not settle must not strand the rest. Each is
   *   caught and counted; the flag stays unset on a failure, so tomorrow's
   *   run picks it up again instead of leaving the money released but
   *   unbooked.
   *
   * The flag is written **before** the postings, deliberately: `ledger.post`
   * is idempotent on its `reference`, so a retry after a partial failure
   * re-runs safely, while a flag written last could be lost after the money
   * had already moved.
   */
  async releaseDueEscrow(
    now = new Date(),
    options: { batchSize?: number } = {},
  ): Promise<{ released: number; failed: number }> {
    const due = await this.prisma.sellerOrder.findMany({
      where: {
        escrowReleased: false,
        escrowReleaseAt: { lte: now },
        status: { in: [...REVENUE_STATUSES] },
        // No dispute, or one that has been ruled on. A decided dispute has
        // already moved the money it froze, and the parcel is back in a
        // revenue state; requiring `dispute: null` here left every parcel that
        // was ever disputed in escrow for ever — the unfrozen rest of the
        // seller's net never released, and the sale never payable, even when
        // she won.
        OR: [
          { dispute: null },
          { dispute: { status: { in: [...DECIDED_DISPUTE_STATUSES] } } },
        ],
        // Only a return still in flight holds the money. A refused or
        // withdrawn one never claimed anything, and a settled one has already
        // taken its share out of escrow below — leaving either of them in the
        // filter would strand the remainder of a partially returned parcel in
        // escrow for ever.
        returns: { none: { status: { in: [...LIVE_RETURN_STATUSES] } } },
      },
      select: { id: true, orderId: true },
      // Oldest first: a seller who has been waiting longest is paid first.
      orderBy: { escrowReleaseAt: 'asc' },
      take: options.batchSize ?? ESCROW_RELEASE_BATCH,
    });

    let released = 0;
    let failed = 0;
    for (const sellerOrder of due) {
      try {
        await this.prisma.sellerOrder.update({
          where: { id: sellerOrder.id },
          data: { escrowReleased: true },
        });
        await this.settleSellerOrder(sellerOrder.id);
        await this.postEscrowRelease(sellerOrder.id);
        // Q43 — «مع احتساب النقاط بعد انتهاء مدة الاسترجاع». The sale is final
        // at exactly this moment, which is when the client said points count.
        await this.loyalty.accrueForSellerOrder(sellerOrder.id);
        released += 1;
        await this.grantPurchaseRewards(sellerOrder.orderId);
      } catch (error) {
        failed += 1;
        // Put the flag back. Leaving it set on a parcel whose postings did not
        // land would make the sale permanently invisible to this sweep — the
        // seller's money would sit in escrow with nothing left to release it.
        await this.prisma.sellerOrder
          .update({
            where: { id: sellerOrder.id },
            data: { escrowReleased: false },
          })
          .catch(() => undefined);
        this.logger.error(
          `Escrow release failed for sub-order ${sellerOrder.id}; the next ` +
            `sweep will retry: ${(error as Error).message}`,
        );
      }
    }
    return { released, failed };
  }

  /**
   * The order's purchase rewards, if this release was its last open parcel.
   *
   * After the release has landed and outside its error handling on purpose: a
   * reward that fails to grant must not put a seller's money back in escrow.
   * The rewards sweep picks up anything that fails here.
   */
  private async grantPurchaseRewards(orderId: string): Promise<void> {
    if (!this.purchaseRewards) return;
    try {
      await this.purchaseRewards.grantIfFinal(orderId);
    } catch (error) {
      this.logger.error(
        `Purchase rewards for order ${orderId} not granted; the sweep will ` +
          `retry: ${(error as Error).message}`,
      );
    }
  }

  /** The rewards sweep, run beside the escrow release. */
  async grantDuePurchaseRewards(): Promise<{ granted: number; failed: number }> {
    if (!this.purchaseRewards) return { granted: 0, failed: 0 };
    return this.purchaseRewards.sweep();
  }

  /**
   * Books what the carrier charged to carry this parcel.
   *
   * **The half of delivery the books never had.** `SHIPPING_REVENUE` records
   * the fee the customer paid; this records what the journey cost. Without it
   * `EconomicsService`'s contribution margin — which already reads
   * `SHIPPING_EXPENSE` — was revenue with no cost against it, so every margin
   * figure the platform reported was overstated by the entire delivery bill,
   * and a route that loses money on every parcel looked profitable.
   *
   * **The platform bears it in full.** The seller's net is computed on goods
   * alone (`sellerNet` never sees `shippingCost`), so the difference between
   * what the customer paid for delivery and what the carrier charged is the
   * platform's margin or the platform's loss. Nothing here touches
   * `SELLER_PAYABLE`.
   *
   * **A separate entry, not a line on the settlement.** Three reasons, and all
   * three are load-bearing:
   *
   * 1. A carrier may quote in a different currency from the order. A journal
   *    entry balances within one currency, so a foreign fee cannot be a line
   *    beside a Syrian-pound settlement.
   * 2. The carrier's fee arrives from the adapter and can arrive *late* — a
   *    webhook after delivery, a correction the next day. Its own `reference`
   *    lets it be posted when it is known rather than held up the settlement.
   * 3. Reversing a sale should not reverse a journey that physically
   *    happened. The carrier is owed for it either way.
   *
   * Silent when there is nothing to book: a parcel with no dispatch (a rider
   * assigned by hand), a carrier that quotes no fee, or a fee of zero.
   */
  private async accrueDeliveryCost(sellerOrder: {
    id: string;
    number: string;
    orderId: string;
    shipment: {
      courierId: string | null;
      dispatch: {
        id: string;
        feeAmount: Prisma.Decimal | null;
        feeCurrency: Currency | null;
      } | null;
    } | null;
  }): Promise<void> {
    const dispatch = sellerOrder.shipment?.dispatch;
    if (!dispatch?.feeAmount || !dispatch.feeCurrency) return;

    const fee = Money.of(dispatch.feeAmount, dispatch.feeCurrency);
    if (fee.isZero()) return;

    // Without a courier row there is no party to owe. That happens for an
    // external carrier the platform has not modelled as a `Courier`, and
    // booking the debt against nobody would make the liability unattributable
    // — worse than not booking it, because it would look settled.
    const courierId = sellerOrder.shipment?.courierId;
    if (!courierId) {
      this.logger.warn(
        `Parcel ${sellerOrder.number} was carried for ${fee.toString()} by a ` +
          `dispatch with no courier row; the cost is not booked. Attach a ` +
          `Courier to the provider account so the payable has an owner.`,
      );
      return;
    }

    await this.ledger.post({
      type: JournalEntryType.DELIVERY_COST_ACCRUED,
      // Keyed on the dispatch, not the sub-order: the dispatch is the thing
      // the carrier billed, and re-settling a parcel must not re-book it.
      reference: `delivery-cost:${dispatch.id}`,
      description: `Delivery cost — ${sellerOrder.number}`,
      orderId: sellerOrder.orderId,
      sellerOrderId: sellerOrder.id,
      lines: [
        {
          account: { code: LedgerAccountCode.SHIPPING_EXPENSE },
          direction: LedgerDirection.DEBIT,
          amount: fee,
          memo: 'Carrier fee for this parcel',
        },
        {
          account: {
            code: LedgerAccountCode.COURIER_PAYABLE,
            ownerId: courierId,
          },
          direction: LedgerDirection.CREDIT,
          amount: fee,
          memo: 'Owed to the carrier until the delivery bill is settled',
        },
      ],
      metadata: { dispatch_id: dispatch.id } as Prisma.InputJsonValue,
    });
  }

  /**
   * Which account holds the money the moment a sub-order settles.
   *
   * Falls back to platform cash when the payment method is unknown or the
   * order was paid from wallet credit — in the wallet case the cash was
   * already ours, and the wallet spend has credited it back out.
   */
  private collectionAccount(sellerOrder: {
    shipment: { courierId: string | null } | null;
    order: { payment: { method: PaymentMethodType } | null };
  }): { code: LedgerAccountCode; ownerId?: string | null } {
    const method = sellerOrder.order.payment?.method;

    if (
      method === PaymentMethodType.COD ||
      method === PaymentMethodType.COURIER_COLLECT
    ) {
      const courierId = sellerOrder.shipment?.courierId;
      // Without a courier there is nobody to hold the cash against, so it is
      // treated as already collected rather than attributed to no one.
      if (courierId) {
        return {
          code: LedgerAccountCode.COURIER_CASH_IN_TRANSIT,
          ownerId: courierId,
        };
      }
      return { code: LedgerAccountCode.PLATFORM_CASH };
    }

    if (
      method === PaymentMethodType.SYRIATEL_CASH ||
      method === PaymentMethodType.MTN_CASH ||
      method === PaymentMethodType.SHAM_CASH ||
      method === PaymentMethodType.BANK_CARD ||
      method === PaymentMethodType.BANK_TRANSFER ||
      method === PaymentMethodType.HAWALA
    ) {
      return { code: LedgerAccountCode.GATEWAY_RECEIVABLE };
    }

    return { code: LedgerAccountCode.PLATFORM_CASH };
  }

  /**
   * Q24 P1 — moves a seller's net out of escrow and into payable.
   *
   * Nothing enters or leaves the platform here: one liability becomes another,
   * and the money only becomes drainable by a payout run once it lands in
   * SELLER_PAYABLE. Keeping the two accounts apart is what lets an admin see,
   * at any moment, how much is genuinely due versus still inside a return
   * window.
   */
  private async postEscrowRelease(sellerOrderId: string) {
    const ledger = await this.prisma.commissionLedger.findUnique({
      where: { sellerOrderId },
      include: { sellerOrder: { select: { orderId: true, number: true } } },
    });
    if (!ledger) return;

    // What is left of the seller's net after anything already refunded out of
    // escrow for this parcel. A partial return takes its share the moment it
    // settles, so releasing the commission row's original net would move money
    // that is no longer there — the escrow account would go negative and the
    // seller would be paid for goods sitting back on her own shelf.
    const refunded = await this.ledger.movementFor({
      account: {
        code: LedgerAccountCode.SELLER_ESCROW,
        ownerId: ledger.sellerId,
      },
      currency: ledger.currency,
      direction: LedgerDirection.DEBIT,
      sellerOrderId,
      // A dispute freeze takes its amount out of escrow just as a return does,
      // and the ruling sends it on from the held account — never back here.
      types: [JournalEntryType.RETURN_SETTLED, JournalEntryType.DISPUTE_HELD],
    });

    const net = Money.of(ledger.net, ledger.currency)
      .minus(refunded)
      .clampMin(Money.zero(ledger.currency));
    if (net.isZero()) return;

    await this.ledger.post({
      type: JournalEntryType.ESCROW_RELEASED,
      reference: `escrow-release:${sellerOrderId}`,
      description: `Return window closed — ${ledger.sellerOrder?.number ?? sellerOrderId}`,
      orderId: ledger.sellerOrder?.orderId ?? null,
      sellerOrderId,
      lines: [
        {
          account: {
            code: LedgerAccountCode.SELLER_ESCROW,
            ownerId: ledger.sellerId,
          },
          direction: LedgerDirection.DEBIT,
          amount: net,
        },
        {
          account: {
            code: LedgerAccountCode.SELLER_PAYABLE,
            ownerId: ledger.sellerId,
          },
          direction: LedgerDirection.CREDIT,
          amount: net,
        },
      ],
    });
  }

  // ── Reporting ───────────────────────────────────────────────────────────

  async sellerEarnings(sellerId: string) {
    await this.ensureSeller(sellerId);
    const [byStatus, paidPayouts, pendingPayouts, recent] = await Promise.all([
      this.prisma.commissionLedger.groupBy({
        by: ['status', 'currency'],
        where: { sellerId },
        _sum: { gross: true, commission: true, platformFee: true, net: true },
        _count: { _all: true },
      }),
      this.prisma.sellerPayout.groupBy({
        by: ['currency'],
        where: { sellerId, status: PayoutStatus.PAID },
        _sum: { net: true },
      }),
      this.prisma.sellerPayout.findMany({
        where: {
          sellerId,
          status: { in: [PayoutStatus.PENDING, PayoutStatus.APPROVED] },
        },
        orderBy: { createdAt: 'desc' },
        take: 5,
      }),
      this.prisma.commissionLedger.findMany({
        where: { sellerId },
        orderBy: { createdAt: 'desc' },
        take: 12,
      }),
    ]);

    return {
      totals: this.statusTotals(byStatus),
      lifetime_paid: paidPayouts.map((row) =>
        Money.of(row._sum.net ?? 0, row.currency).toJSON(),
      ),
      pending_payouts: pendingPayouts.map((payout) =>
        this.serializePayout(payout),
      ),
      recent_transactions: recent.map((ledger) => this.serializeLedger(ledger)),
    };
  }

  async sellerTransactions(sellerId: string) {
    await this.ensureSeller(sellerId);
    const ledgers = await this.prisma.commissionLedger.findMany({
      where: { sellerId },
      orderBy: { createdAt: 'desc' },
      take: 100,
    });
    return ledgers.map((ledger) => this.serializeLedger(ledger));
  }

  async adminReport(query: CommissionReportQueryDto) {
    const range = this.range(query);
    const where: Prisma.CommissionLedgerWhereInput = {
      ...(query.seller_id ? { sellerId: query.seller_id } : {}),
      createdAt: { gte: range.start, lte: range.end },
    };

    const [byCurrency, byStatus, ledgers, payouts] = await Promise.all([
      // Amounts are only ever aggregated WITHIN a currency — summing SYP and
      // USD into one figure is exactly the bug this schema exists to prevent.
      this.prisma.commissionLedger.groupBy({
        by: ['currency'],
        where,
        _sum: { gross: true, commission: true, platformFee: true, net: true },
        _count: { _all: true },
      }),
      this.prisma.commissionLedger.groupBy({
        by: ['status', 'currency'],
        where,
        _sum: { net: true },
        _count: { _all: true },
      }),
      this.prisma.commissionLedger.findMany({
        where,
        orderBy: { createdAt: 'desc' },
        take: 100,
      }),
      this.prisma.sellerPayout.findMany({
        where: {
          ...(query.seller_id ? { sellerId: query.seller_id } : {}),
          createdAt: { gte: range.start, lte: range.end },
        },
        orderBy: { createdAt: 'desc' },
        take: 50,
      }),
    ]);

    return {
      range: {
        start: range.start.toISOString(),
        end: range.end.toISOString(),
      },
      totals_by_currency: byCurrency.map((row) => ({
        currency: row.currency,
        gross: Money.of(row._sum.gross ?? 0, row.currency).toJSON(),
        commission: Money.of(row._sum.commission ?? 0, row.currency).toJSON(),
        platform_fees: Money.of(
          row._sum.platformFee ?? 0,
          row.currency,
        ).toJSON(),
        seller_net: Money.of(row._sum.net ?? 0, row.currency).toJSON(),
        ledgers_count: row._count._all,
      })),
      by_status: byStatus.map((row) => ({
        status: row.status.toLowerCase(),
        currency: row.currency,
        net: Money.of(row._sum.net ?? 0, row.currency).toJSON(),
        count: row._count._all,
      })),
      ledgers: ledgers.map((ledger) => this.serializeLedger(ledger)),
      payouts: payouts.map((payout) => this.serializePayout(payout)),
    };
  }

  // ── Payouts ─────────────────────────────────────────────────────────────

  /**
   * Q25 P1 — weekly payouts. A payout covers ONE currency: a seller pricing in
   * both SYP and USD gets one payout per currency, because there is no correct
   * exchange rate to merge them at after the fact.
   */
  async calculatePayout(dto: PayoutCalculationDto) {
    await this.ensureSeller(dto.seller_id);
    const start = new Date(dto.period_start);
    const end = new Date(dto.period_end);
    if (end <= start) throw new BadRequestException('Invalid payout date range');

    const currency = dto.currency ?? Currency.SYP;
    // Under the seller's payout lock, so this and a request she makes in the
    // same instant cannot both claim the same sales — see
    // `lockSellerPayouts`.
    const payout = await this.prisma.$transaction(async (tx) => {
      await lockSellerPayouts(tx, dto.seller_id);

      const ledgers = await tx.commissionLedger.findMany({
        where: {
          sellerId: dto.seller_id,
          currency,
          status: CommissionStatus.EARNED,
          createdAt: { gte: start, lte: end },
          payoutItems: { none: {} },
          // Q24 P1 — nothing is paid out before its escrow has been released.
          sellerOrder: { escrowReleased: true },
        },
      });
      if (ledgers.length === 0) {
        throw new BadRequestException(
          'No released commission ledgers available for this period',
        );
      }

      const gross = Money.sum(
        ledgers.map((ledger) => Money.of(ledger.gross, currency)),
        currency,
      );
      const commission = Money.sum(
        ledgers.map((ledger) => Money.of(ledger.commission, currency)),
        currency,
      );
      const platformFees = Money.sum(
        ledgers.map((ledger) => Money.of(ledger.platformFee, currency)),
        currency,
      );
      const ledgerNet = Money.sum(
        ledgers.map((ledger) => Money.of(ledger.net, currency)),
        currency,
      );
      const requested = ledgerNet.plus(
        Money.of(dto.adjustments ?? 0, currency).quantize(),
      );

      // Never more than the books say is owed. A positive adjustment cannot
      // lift a payout past it either: money with no entry behind it is a bonus
      // the ledger has not heard of, and it belongs in the ledger first.
      const headroom = await payableHeadroom(tx, dto.seller_id, currency);
      const net = requested.greaterThan(headroom) ? headroom : requested;
      if (net.isZero() || net.isNegative()) {
        throw new BadRequestException({
          code: 'NOTHING_PAYABLE',
          message:
            `Nothing is payable: the seller's payable balance after open ` +
            `payouts is ${headroom.toString()}`,
        });
      }

      return tx.sellerPayout.create({
        data: {
          sellerId: dto.seller_id,
          periodStart: start,
          periodEnd: end,
          currency,
          gross: gross.toPrisma(),
          commission: commission.toPrisma(),
          platformFees: platformFees.toPrisma(),
          adjustments: net.minus(ledgerNet).toPrisma(),
          net: net.toPrisma(),
          ledgers: {
            create: ledgers.map((ledger) => ({ ledgerId: ledger.id })),
          },
        },
      });
    });
    return this.serializePayout(payout);
  }

  /**
   * [actorId] comes from the authenticated caller, never from the request
   * body — an audit record naming an actor the client chose would be worth
   * less than none.
   */
  async updatePayoutStatus(
    id: string,
    dto: PayoutStatusDto,
    actorId?: string | null,
    actorRole?: UserRole,
  ) {
    // Q62 — releasing money is the general manager's decision alone. The
    // accountant can calculate a payout and cancel one; approving it and
    // marking it paid are the two transitions that actually move funds.
    const releasing =
      dto.status === PayoutStatus.APPROVED || dto.status === PayoutStatus.PAID;
    if (releasing && actorRole && actorRole !== UserRole.SUPER_ADMIN) {
      await this.financialAudit.record({
        action: FinancialAction.PayoutStatusChanged,
        actorId: actorId ?? null,
        subjectId: id,
        subjectType: 'seller_payout',
        after: dto.status,
        outcome: 'refused',
        reason: 'Only the general manager may approve or release a payout',
      });
      throw new ForbiddenException(
        'Only the general manager may approve or release a payout',
      );
    }

    const payout = await this.prisma.sellerPayout.findUnique({
      where: { id },
      include: { ledgers: true },
    });
    if (!payout) throw new NotFoundException('Payout not found');

    // Re-sending the status a payout already has is answered, not refused —
    // a retried request must not turn into an error after the money moved.
    if (payout.status === dto.status) {
      return this.serializePayout(payout);
    }
    assertPayoutTransition(payout.status, dto.status);

    if (releasing) {
      await this.assertNotPayoutFrozen(payout.sellerId, dto.status);
    }

    const now = new Date();
    const updated = await this.prisma.$transaction(async (tx) => {
      await lockSellerPayouts(tx, payout.sellerId);

      // Claimed on the status it was read with: two operators acting on one
      // payout at once must not both get through.
      const claimed = await tx.sellerPayout.updateMany({
        where: { id, status: payout.status },
        data: { status: dto.status },
      });
      if (claimed.count === 0) {
        throw new ConflictException(
          'This payout was changed by someone else — reload it and try again',
        );
      }

      if (dto.status === PayoutStatus.PAID) {
        await this.assertPayable(tx, payout);
      }

      const record = await tx.sellerPayout.update({
        where: { id },
        data: {
          status: dto.status,
          reference: dto.reference ?? payout.reference,
          ...(dto.status === PayoutStatus.APPROVED && { approvedAt: now }),
          ...(dto.status === PayoutStatus.PAID && { paidAt: now }),
        },
      });

      // A payout that will never pay must let go of its ledgers. They are
      // gathered by `payoutItems: { none: {} }`, so a cancelled or failed
      // payout that kept its links would hold that money outside every future
      // payout — permanently, silently, and only noticed by a seller
      // wondering why a delivered order never became payable.
      if (
        dto.status === PayoutStatus.CANCELLED ||
        dto.status === PayoutStatus.FAILED
      ) {
        await tx.sellerPayoutLedger.deleteMany({ where: { payoutId: id } });
      }

      if (dto.status === PayoutStatus.PAID) {
        await tx.commissionLedger.updateMany({
          where: { id: { in: payout.ledgers.map((item) => item.ledgerId) } },
          data: { status: CommissionStatus.PAID, paidAt: now },
        });
        await tx.financialLedgerEntry.create({
          data: {
            type: FinancialLedgerType.PAYOUT,
            sellerId: payout.sellerId,
            currency: payout.currency,
            amount: Money.of(payout.net, payout.currency).negated().toPrisma(),
            description: `Seller payout ${dto.reference ?? payout.id}`,
            metadata: { payout_id: payout.id } as Prisma.InputJsonValue,
          },
        });

        // The money actually leaves: the obligation to the seller is
        // discharged and the platform's cash falls by the same amount. Posted
        // in this transaction, so a payout marked paid and the cash movement
        // that proves it can never come apart.
        await this.ledger.post(
          {
            type: JournalEntryType.PAYOUT_PAID,
            reference: `payout-paid:${payout.id}`,
            description: `Seller payout ${dto.reference ?? payout.id}`,
            lines: [
              {
                account: {
                  code: LedgerAccountCode.SELLER_PAYABLE,
                  ownerId: payout.sellerId,
                },
                direction: LedgerDirection.DEBIT,
                amount: Money.of(payout.net, payout.currency),
              },
              {
                account: { code: LedgerAccountCode.PLATFORM_CASH },
                direction: LedgerDirection.CREDIT,
                amount: Money.of(payout.net, payout.currency),
              },
            ],
            metadata: { payout_id: payout.id } as Prisma.InputJsonValue,
          },
          tx,
        );
      }
      return record;
    });

    // Q65 — «صرف أرباح» is top of the list of what the log must carry, with
    // the status before and after and who moved it.
    await this.financialAudit.record({
      action: FinancialAction.PayoutStatusChanged,
      actorId: actorId ?? null,
      subjectId: payout.id,
      subjectType: 'seller_payout',
      before: payout.status,
      after: dto.status,
      reason: dto.reference ?? null,
      extra: {
        seller_id: payout.sellerId,
        net: Money.of(payout.net, payout.currency).toJSON(),
      },
    });

    return this.serializePayout(updated);
  }

  async updateLedgerStatus(id: string, dto: CommissionLedgerStatusDto) {
    const current = await this.prisma.commissionLedger.findUnique({
      where: { id },
      select: { status: true },
    });
    if (!current) throw new NotFoundException('Commission entry not found');
    await assertCommissionLedgerChange(this.prisma, id, current.status, dto.status);

    const ledger = await this.prisma.commissionLedger.update({
      where: { id },
      data: {
        status: dto.status,
        ...(dto.status === CommissionStatus.PAID && { paidAt: new Date() }),
      },
    });
    return this.serializeLedger(ledger);
  }

  // ── helpers ─────────────────────────────────────────────────────────────

  private async ensureSeller(sellerId: string) {
    const seller = await this.prisma.user.findUnique({
      where: { id: sellerId },
      select: { id: true, role: true },
    });
    if (!seller || seller.role !== UserRole.SELLER) {
      throw new NotFoundException('Seller not found');
    }
  }

  /**
   * The last check before cash leaves: what this payout carries must still be
   * owed, and every sale it covers must still be unpaid.
   *
   * The payout was sized when it was created. Between then and now a refund
   * may have reached her payable, or a sale may have been settled some other
   * way — and the cash goes out on the figure frozen on the payout, not on
   * whatever is true today. So the ledger is asked again here.
   */
  private async assertPayable(
    tx: Prisma.TransactionClient,
    payout: SellerPayout & { ledgers: { ledgerId: string }[] },
  ): Promise<void> {
    const net = Money.of(payout.net, payout.currency);
    if (net.isZero() || net.isNegative()) {
      throw new BadRequestException('This payout carries nothing to pay');
    }

    const settled = await tx.commissionLedger.count({
      where: {
        id: { in: payout.ledgers.map((item) => item.ledgerId) },
        status: { not: CommissionStatus.EARNED },
      },
    });
    if (settled > 0) {
      throw new ConflictException({
        code: 'PAYOUT_SALES_ALREADY_SETTLED',
        message: `${settled} sale(s) in this payout were already paid or reversed`,
      });
    }

    const headroom = await payableHeadroom(
      tx,
      payout.sellerId,
      payout.currency,
      payout.id,
    );
    if (net.greaterThan(headroom)) {
      throw new ConflictException({
        code: 'PAYOUT_EXCEEDS_PAYABLE',
        message:
          `This payout is for ${net.toString()} but the seller is owed ` +
          `${headroom.toString()} — recalculate it before paying`,
      });
    }
  }

  /**
   * Refuses to release money while the account is inside a security freeze.
   *
   * A freeze is stamped by exactly two events, and both are shaped like a
   * takeover: the account moved to a different phone number, or it was handed
   * over through support-mediated recovery. In the honest case the seller waits
   * a week for money that was never at risk; in the dishonest one the attacker
   * gets nothing, and the real owner — who will notice she cannot sign in long
   * before seven days are out — still has an account with a balance in it.
   *
   * Checked at *release*, not at calculation: a frozen seller's earnings keep
   * accruing and her statements keep working. It is the moment funds would
   * actually leave that stops.
   */
  private async assertNotPayoutFrozen(sellerId: string, action: string) {
    const seller = await this.prisma.user.findUnique({
      where: { id: sellerId },
      select: { payoutFrozenUntil: true, payoutFreezeReason: true },
    });
    const until = seller?.payoutFrozenUntil;
    if (!until || until <= new Date()) return;

    await this.financialAudit.record({
      action: FinancialAction.PayoutStatusChanged,
      actorId: null,
      subjectId: sellerId,
      subjectType: 'seller_payout',
      after: action,
      outcome: 'refused',
      reason: `Payouts frozen until ${until.toISOString()} (${seller?.payoutFreezeReason ?? 'security'})`,
    });
    throw new ForbiddenException({
      code: 'PAYOUTS_FROZEN',
      message:
        'تم تجميد التحويلات المالية لهذا الحساب مؤقتًا بعد تغيير أمني حديث.',
      frozen_until: until.toISOString(),
      reason: seller?.payoutFreezeReason ?? 'security',
    });
  }

  private range(query: CommissionReportQueryDto) {
    const end = query.end ? new Date(query.end) : new Date();
    const start = query.start
      ? new Date(query.start)
      : new Date(end.getTime() - 30 * 24 * 60 * 60 * 1000);
    return { start, end };
  }

  private statusTotals(
    rows: {
      status: CommissionStatus;
      currency: Currency;
      _sum: {
        gross: Prisma.Decimal | null;
        commission: Prisma.Decimal | null;
        platformFee: Prisma.Decimal | null;
        net: Prisma.Decimal | null;
      };
      _count: { _all: number };
    }[],
  ) {
    return rows.map((row) => ({
      status: row.status.toLowerCase(),
      currency: row.currency,
      gross: Money.of(row._sum.gross ?? 0, row.currency).toJSON(),
      commission: Money.of(row._sum.commission ?? 0, row.currency).toJSON(),
      platform_fees: Money.of(row._sum.platformFee ?? 0, row.currency).toJSON(),
      net: Money.of(row._sum.net ?? 0, row.currency).toJSON(),
      count: row._count._all,
    }));
  }

  private serializeRule(rule: CommissionRule) {
    return {
      id: rule.id,
      name: rule.name,
      rate_bps: rule.rateBps,
      platform_fee_bps: rule.platformFeeBps,
      currency: rule.currency,
      fixed_fee: Money.of(rule.fixedFee, rule.currency).toJSON(),
      min_commission: rule.minCommission
        ? Money.of(rule.minCommission, rule.currency).toJSON()
        : null,
      max_commission: rule.maxCommission
        ? Money.of(rule.maxCommission, rule.currency).toJSON()
        : null,
      category: rule.category,
      seller_tier: rule.sellerTier,
      priority: rule.priority,
      active: rule.active,
      starts_at: rule.startsAt.toISOString(),
      ends_at: rule.endsAt?.toISOString() ?? null,
    };
  }

  private serializeLedger(ledger: CommissionLedger) {
    return {
      id: ledger.id,
      seller_order_id: ledger.sellerOrderId,
      seller_id: ledger.sellerId,
      currency: ledger.currency,
      gross: Money.of(ledger.gross, ledger.currency).toJSON(),
      commission: Money.of(ledger.commission, ledger.currency).toJSON(),
      platform_fee: Money.of(ledger.platformFee, ledger.currency).toJSON(),
      net: Money.of(ledger.net, ledger.currency).toJSON(),
      status: ledger.status.toLowerCase(),
      created_at: ledger.createdAt.toISOString(),
      paid_at: ledger.paidAt?.toISOString() ?? null,
    };
  }

  private serializePayout(payout: SellerPayout) {
    return {
      id: payout.id,
      seller_id: payout.sellerId,
      period_start: payout.periodStart.toISOString(),
      period_end: payout.periodEnd.toISOString(),
      currency: payout.currency,
      gross: Money.of(payout.gross, payout.currency).toJSON(),
      commission: Money.of(payout.commission, payout.currency).toJSON(),
      platform_fees: Money.of(payout.platformFees, payout.currency).toJSON(),
      adjustments: Money.of(payout.adjustments, payout.currency).toJSON(),
      net: Money.of(payout.net, payout.currency).toJSON(),
      status: payout.status.toLowerCase(),
      reference: payout.reference,
      created_at: payout.createdAt.toISOString(),
      approved_at: payout.approvedAt?.toISOString() ?? null,
      paid_at: payout.paidAt?.toISOString() ?? null,
    };
  }
}
