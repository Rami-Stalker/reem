import {
  BadRequestException,
  ForbiddenException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import {
  CommissionStatus,
  Currency,
  Prisma,
  PayoutStatus,
  SellerPayout,
  UserRole,
} from '@prisma/client';

import { Money } from '../../common/money';
import { PrismaService } from '../../prisma/prisma.service';
import {
  FinancialAction,
  FinancialAuditService,
} from './financial-audit.service';

/** A payout nobody has released yet — still the seller's to withdraw. */
const OPEN_STATUSES = [PayoutStatus.PENDING, PayoutStatus.APPROVED] as const;

/**
 * Q69 P1 «كشف حساب **وطلب سحب** الأرباح» — the second half.
 *
 * The statement existed; the asking did not. A seller could watch a balance
 * marked «متاح للسحب» grow and had no way to ask for any of it, and the admin
 * console could only pay out money nobody had requested.
 *
 * This service deliberately invents no accounting. A request is a
 * `SellerPayout` in `PENDING` over the same released, unclaimed commission
 * ledgers the accountant's own `calculatePayout` would gather — so it enters
 * the existing approval flow unchanged, and every invariant that flow already
 * enforces still holds: only the general manager may approve or release it
 * (Q62), a payout freeze stops it, and the money moves through
 * `LedgerService.post` when it is marked paid, never here.
 */
@Injectable()
export class SellerPayoutsService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly audit: FinancialAuditService,
  ) {}

  /**
   * What she could ask for right now, and why she cannot when she cannot.
   *
   * Read before the button is drawn, so a disabled button carries a sentence
   * instead of being mysteriously grey.
   */
  async availability(sellerId: string, currency: Currency = Currency.SYP) {
    await this.assertSeller(sellerId);

    const [open, ledgers, freeze] = await Promise.all([
      this.prisma.sellerPayout.findFirst({
        where: { sellerId, currency, status: { in: [...OPEN_STATUSES] } },
        orderBy: { createdAt: 'desc' },
      }),
      this.claimableLedgers(sellerId, currency),
      this.freezeFor(sellerId),
    ]);

    const net = this.sumNet(ledgers, currency);

    return {
      currency,
      /// What a request made this second would be worth.
      claimable: net.toJSON(),
      orders_included: ledgers.length,
      can_request:
        freeze === null && open === null && ledgers.length > 0,
      /// Exactly one reason, in the order they actually block her.
      blocked_by: freeze !== null
        ? 'payout_frozen'
        : open !== null
          ? 'request_open'
          : ledgers.length === 0
            ? 'nothing_released'
            : null,
      frozen_until: freeze?.until.toISOString() ?? null,
      freeze_reason: freeze?.reason ?? null,
      open_request: open ? this.serialize(open) : null,
    };
  }

  /**
   * Asks for everything currently due.
   *
   * There is no partial amount on purpose. A payout is a set of commission
   * ledgers, each the settled record of one sale; paying half of one would
   * mean splitting a row that the order, the commission and the escrow release
   * all point at. She asks for what is released, or she waits.
   */
  async request(sellerId: string, currency: Currency = Currency.SYP) {
    await this.assertSeller(sellerId);

    // Refused here as well as at release. The freeze exists because a takeover
    // wants exactly this, and a queue of requests an approver must refuse one
    // by one is worse for everyone than a clear answer now.
    const freeze = await this.freezeFor(sellerId);
    if (freeze) {
      await this.audit.record({
        action: FinancialAction.PayoutStatusChanged,
        actorId: sellerId,
        subjectId: sellerId,
        subjectType: 'seller_payout_request',
        outcome: 'refused',
        reason: `payout frozen (${freeze.reason ?? 'security'})`,
      });
      throw new ForbiddenException(
        'Payouts are paused on this account for security. It lifts on its own.',
      );
    }

    const open = await this.prisma.sellerPayout.findFirst({
      where: { sellerId, currency, status: { in: [...OPEN_STATUSES] } },
    });
    if (open) {
      throw new BadRequestException(
        'You already have a withdrawal request waiting — it covers everything released so far.',
      );
    }

    const ledgers = await this.claimableLedgers(sellerId, currency);
    if (ledgers.length === 0) {
      throw new BadRequestException(
        'Nothing is available to withdraw yet. Earnings become available once a parcel is delivered and its return window closes.',
      );
    }

    const gross = this.sum(ledgers, 'gross', currency);
    const commission = this.sum(ledgers, 'commission', currency);
    const platformFees = this.sum(ledgers, 'platformFee', currency);
    const net = this.sumNet(ledgers, currency);

    // The period is what the money actually spans, not a range she picked: the
    // earliest sale still unpaid, through now.
    const periodStart = ledgers.reduce(
      (earliest, ledger) =>
        ledger.createdAt < earliest ? ledger.createdAt : earliest,
      ledgers[0].createdAt,
    );

    const payout = await this.prisma.sellerPayout.create({
      data: {
        sellerId,
        periodStart,
        periodEnd: new Date(),
        currency,
        gross: gross.toPrisma(),
        commission: commission.toPrisma(),
        platformFees: platformFees.toPrisma(),
        adjustments: Money.of(0, currency).toPrisma(),
        net: net.toPrisma(),
        ledgers: { create: ledgers.map((ledger) => ({ ledgerId: ledger.id })) },
      },
    });

    await this.audit.record({
      action: FinancialAction.PayoutStatusChanged,
      actorId: sellerId,
      subjectId: payout.id,
      subjectType: 'seller_payout',
      before: null,
      after: PayoutStatus.PENDING,
      reason: 'requested by the seller',
      extra: {
        seller_id: sellerId,
        net: net.toJSON(),
        ledger_count: ledgers.length,
      },
    });

    return this.serialize(payout);
  }

  /**
   * She changes her mind while it is still waiting.
   *
   * Only while `PENDING`: once the general manager has approved it the money
   * is on its way out, and unwinding that is his to do, not hers.
   */
  async cancel(sellerId: string, payoutId: string) {
    const payout = await this.prisma.sellerPayout.findUnique({
      where: { id: payoutId },
    });
    if (!payout || payout.sellerId !== sellerId) {
      throw new NotFoundException('Withdrawal request not found');
    }
    if (payout.status !== PayoutStatus.PENDING) {
      throw new BadRequestException(
        'This request has already been approved — ask support to stop it.',
      );
    }

    const updated = await this.prisma.$transaction(async (tx) => {
      // Releasing the claim is the point of cancelling. A payout that will
      // never pay must not keep holding its ledgers: they are selected by
      // `payoutItems: { none: {} }`, so leaving the links behind would strand
      // that money outside every future payout, permanently and silently.
      await tx.sellerPayoutLedger.deleteMany({ where: { payoutId } });
      return tx.sellerPayout.update({
        where: { id: payoutId },
        data: { status: PayoutStatus.CANCELLED },
      });
    });

    await this.audit.record({
      action: FinancialAction.PayoutStatusChanged,
      actorId: sellerId,
      subjectId: payoutId,
      subjectType: 'seller_payout',
      before: PayoutStatus.PENDING,
      after: PayoutStatus.CANCELLED,
      reason: 'withdrawn by the seller',
      extra: { seller_id: sellerId },
    });

    return this.serialize(updated);
  }

  /** Her withdrawal history, newest first. */
  async history(sellerId: string, currency?: Currency, take = 30) {
    await this.assertSeller(sellerId);
    const payouts = await this.prisma.sellerPayout.findMany({
      where: { sellerId, ...(currency ? { currency } : {}) },
      orderBy: { createdAt: 'desc' },
      take,
    });
    return payouts.map((payout) => this.serialize(payout));
  }

  // ── Internals ───────────────────────────────────────────────────────────

  /**
   * The sales she may be paid for.
   *
   * Three conditions, and each one is somebody's protection: `EARNED` means
   * the sale is settled and not reversed; `escrowReleased` means the return
   * window has closed, so the customer can no longer take it back (Q24 P1);
   * and `payoutItems: { none: {} }` means no other payout has claimed it —
   * which is what stops the same sale being paid twice.
   */
  private claimableLedgers(sellerId: string, currency: Currency) {
    return this.prisma.commissionLedger.findMany({
      where: {
        sellerId,
        currency,
        status: CommissionStatus.EARNED,
        payoutItems: { none: {} },
        sellerOrder: { escrowReleased: true },
      },
      orderBy: { createdAt: 'asc' },
    });
  }

  private async freezeFor(sellerId: string) {
    const seller = await this.prisma.user.findUnique({
      where: { id: sellerId },
      select: { payoutFrozenUntil: true, payoutFreezeReason: true },
    });
    const until = seller?.payoutFrozenUntil;
    if (!until || until <= new Date()) return null;
    return { until, reason: seller?.payoutFreezeReason ?? null };
  }

  private async assertSeller(sellerId: string) {
    const seller = await this.prisma.user.findUnique({
      where: { id: sellerId },
      select: { id: true, role: true },
    });
    if (!seller || seller.role !== UserRole.SELLER) {
      throw new NotFoundException('Seller not found');
    }
  }

  private sum(
    ledgers: { gross: Prisma.Decimal; commission: Prisma.Decimal; platformFee: Prisma.Decimal }[],
    field: 'gross' | 'commission' | 'platformFee',
    currency: Currency,
  ) {
    return Money.sum(
      ledgers.map((ledger) => Money.of(ledger[field], currency)),
      currency,
    );
  }

  private sumNet(ledgers: { net: Prisma.Decimal }[], currency: Currency) {
    return Money.sum(
      ledgers.map((ledger) => Money.of(ledger.net, currency)),
      currency,
    );
  }

  /** The same shape the seller's statement already publishes, plus the rest. */
  private serialize(payout: SellerPayout) {
    const money = (value: Prisma.Decimal) =>
      Money.of(value, payout.currency).toJSON();

    return {
      id: payout.id,
      status: payout.status,
      currency: payout.currency,
      gross: money(payout.gross),
      commission: money(payout.commission),
      platform_fees: money(payout.platformFees),
      net: money(payout.net),
      reference: payout.reference,
      period_start: payout.periodStart.toISOString(),
      period_end: payout.periodEnd.toISOString(),
      created_at: payout.createdAt.toISOString(),
      approved_at: payout.approvedAt?.toISOString() ?? null,
      paid_at: payout.paidAt?.toISOString() ?? null,
    };
  }
}
