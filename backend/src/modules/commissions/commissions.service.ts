import {
  BadRequestException,
  ForbiddenException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import {
  CommissionLedger,
  CommissionRule,
  CommissionStatus,
  Currency,
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
  constructor(
    private readonly prisma: PrismaService,
    private readonly ledger: LedgerService,
    private readonly loyalty: LoyaltyService,
    private readonly financialAudit: FinancialAuditService,
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
        shipment: { select: { courierId: true } },
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
   * that carry no open dispute. Run on a schedule.
   */
  async releaseDueEscrow(now = new Date()) {
    const due = await this.prisma.sellerOrder.findMany({
      where: {
        escrowReleased: false,
        escrowReleaseAt: { lte: now },
        status: { in: [...REVENUE_STATUSES] },
        dispute: null,
        // Only a return still in flight holds the money. A refused or
        // withdrawn one never claimed anything, and a settled one has already
        // taken its share out of escrow below — leaving either of them in the
        // filter would strand the remainder of a partially returned parcel in
        // escrow for ever.
        returns: { none: { status: { in: [...LIVE_RETURN_STATUSES] } } },
      },
      select: { id: true },
    });

    for (const sellerOrder of due) {
      await this.prisma.sellerOrder.update({
        where: { id: sellerOrder.id },
        data: { escrowReleased: true },
      });
      await this.settleSellerOrder(sellerOrder.id);
      await this.postEscrowRelease(sellerOrder.id);
      // Q43 — «مع احتساب النقاط بعد انتهاء مدة الاسترجاع». The sale is final
      // at exactly this moment, which is when the client said points count.
      await this.loyalty.accrueForSellerOrder(sellerOrder.id);
    }
    return { released: due.length };
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
      types: [JournalEntryType.RETURN_SETTLED],
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
    const ledgers = await this.prisma.commissionLedger.findMany({
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
    const adjustments = Money.of(dto.adjustments ?? 0, currency);
    const net = Money.sum(
      ledgers.map((ledger) => Money.of(ledger.net, currency)),
      currency,
    ).plus(adjustments);

    const payout = await this.prisma.sellerPayout.create({
      data: {
        sellerId: dto.seller_id,
        periodStart: start,
        periodEnd: end,
        currency,
        gross: gross.toPrisma(),
        commission: commission.toPrisma(),
        platformFees: platformFees.toPrisma(),
        adjustments: adjustments.toPrisma(),
        net: net.toPrisma(),
        ledgers: {
          create: ledgers.map((ledger) => ({ ledgerId: ledger.id })),
        },
      },
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

    if (releasing) {
      await this.assertNotPayoutFrozen(payout.sellerId, dto.status);
    }

    const now = new Date();
    const updated = await this.prisma.$transaction(async (tx) => {
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
