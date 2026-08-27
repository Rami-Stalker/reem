import { Injectable, NotFoundException } from '@nestjs/common';
import {
  CommissionStatus,
  Currency,
  Prisma,
  JournalEntryType,
  LedgerAccountCode,
  LedgerDirection,
  PayoutStatus,
  UserRole,
} from '@prisma/client';

import { Money } from '../../common/money';
import { PrismaService } from '../../prisma/prisma.service';
import { LedgerService } from '../ledger/ledger.service';

type Tx = Prisma.TransactionClient;

/** The journal entry types a seller has any business seeing. */
const SELLER_VISIBLE_TYPES = [
  JournalEntryType.COMMISSION_EARNED,
  JournalEntryType.ESCROW_RELEASED,
  JournalEntryType.PAYOUT_PAID,
  JournalEntryType.DISPUTE_HELD,
  JournalEntryType.DISPUTE_RELEASED,
  JournalEntryType.REFUND_ISSUED,
  JournalEntryType.RETURN_SETTLED,
  JournalEntryType.REVERSAL,
] as const;

/**
 * The seller's statement — Q69 P1 «كشف حساب وطلب سحب الأرباح», Q98 «الأرباح
 * والكشوفات».
 *
 * Read from the ledger rather than from the commission table, because only
 * the ledger can separate the three things a seller actually needs to tell
 * apart:
 *
 * - **held** — earned, but still inside the return window (Q24). Not hers yet.
 * - **available** — released and drainable by the next payout run (Q25).
 * - **frozen** — under dispute (Q107). Hers, but not while it is contested.
 *
 * A single "balance" figure hides exactly the distinction a seller argues
 * about, so this reports all three and never sums them into one headline.
 */
@Injectable()
export class SellerEarningsService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly ledger: LedgerService,
  ) {}

  async summaryFor(
    sellerId: string,
    currency: Currency = Currency.SYP,
    tx?: Tx,
  ) {
    const db = tx ?? this.prisma;
    await this.ensureSeller(sellerId, db);

    const [held, available, frozen] = await Promise.all([
      this.ledger.balanceOf(
        { code: LedgerAccountCode.SELLER_ESCROW, ownerId: sellerId },
        currency,
        tx,
      ),
      this.ledger.balanceOf(
        { code: LedgerAccountCode.SELLER_PAYABLE, ownerId: sellerId },
        currency,
        tx,
      ),
      this.ledger.balanceOf(
        { code: LedgerAccountCode.DISPUTE_HELD, ownerId: sellerId },
        currency,
        tx,
      ),
    ]);

    const [lifetime, pendingPayouts, movements] = await Promise.all([
      this.lifetimeTotals(sellerId, currency, db),
      db.sellerPayout.findMany({
        where: {
          sellerId,
          currency,
          status: { in: [PayoutStatus.PENDING, PayoutStatus.APPROVED] },
        },
        orderBy: { createdAt: 'desc' },
        take: 5,
      }),
      this.recentMovements(sellerId, currency, db),
    ]);

    return {
      currency,
      // Deliberately three figures, not one total.
      held_in_escrow: held.toJSON(),
      available_for_payout: available.toJSON(),
      frozen_in_disputes: frozen.toJSON(),

      lifetime_paid: lifetime.paid.toJSON(),
      lifetime_commission: lifetime.commission.toJSON(),
      lifetime_gross: lifetime.gross.toJSON(),

      pending_payouts: pendingPayouts.map((payout) => ({
        id: payout.id,
        status: payout.status,
        net: Money.of(payout.net, payout.currency).toJSON(),
        period_start: payout.periodStart,
        period_end: payout.periodEnd,
        created_at: payout.createdAt,
      })),

      movements,
    };
  }

  /**
   * Everything the seller has ever grossed, been charged, and been paid.
   *
   * Gross and commission come from the commission ledger because that is
   * where a sale's own breakdown lives; paid comes from payouts, because a
   * payout is the moment money actually left.
   */
  private async lifetimeTotals(
    sellerId: string,
    currency: Currency,
    db: Tx | PrismaService,
  ) {
    const [ledgers, payouts] = await Promise.all([
      db.commissionLedger.aggregate({
        where: {
          sellerId,
          currency,
          // A reversed sale never happened as far as earnings go.
          status: { not: CommissionStatus.REVERSED },
        },
        _sum: { gross: true, commission: true, platformFee: true },
      }),
      db.sellerPayout.aggregate({
        where: { sellerId, currency, status: PayoutStatus.PAID },
        _sum: { net: true },
      }),
    ]);

    return {
      gross: Money.of(ledgers._sum.gross ?? 0, currency),
      commission: Money.of(ledgers._sum.commission ?? 0, currency).plus(
        Money.of(ledgers._sum.platformFee ?? 0, currency),
      ),
      paid: Money.of(payouts._sum.net ?? 0, currency),
    };
  }

  /**
   * The seller's own view of the ledger.
   *
   * Only lines touching one of *her* accounts are returned, and each is
   * signed from her point of view: a credit to her payable is money coming to
   * her, a debit is money leaving. The platform's side of each entry is not
   * her business and is not sent.
   */
  private async recentMovements(
    sellerId: string,
    currency: Currency,
    db: Tx | PrismaService,
    take = 25,
  ) {
    const lines = await db.journalLine.findMany({
      where: {
        currency,
        account: {
          ownerKey: sellerId,
          code: {
            in: [
              LedgerAccountCode.SELLER_ESCROW,
              LedgerAccountCode.SELLER_PAYABLE,
              LedgerAccountCode.DISPUTE_HELD,
            ],
          },
        },
        entry: { type: { in: [...SELLER_VISIBLE_TYPES] } },
      },
      include: {
        account: { select: { code: true } },
        entry: {
          select: {
            id: true,
            type: true,
            description: true,
            occurredAt: true,
            sellerOrderId: true,
          },
        },
      },
      orderBy: { createdAt: 'desc' },
      take,
    });

    // Group by entry, because an entry that moves money *between two of her
    // own accounts* — escrow to payable when the return window closes, escrow
    // to held when a dispute opens — produces two lines here. Reporting both
    // would show a release as −500,000 followed by +500,000 and read as money
    // moving twice. One movement per entry, described by where it landed.
    const byEntry = new Map<string, typeof lines>();
    for (const line of lines) {
      const bucket = byEntry.get(line.entry.id) ?? [];
      bucket.push(line);
      byEntry.set(line.entry.id, bucket);
    }

    return [...byEntry.values()].map((group) => {
      const isTransfer = group.length > 1;

      // For a transfer, the credit side names the destination — «تحرير من
      // الضمان» lands in payable, a freeze lands in held.
      const representative =
        group.find((line) => line.direction === LedgerDirection.CREDIT) ??
        group[0];

      const amount = Money.of(
        representative.amount,
        representative.currency,
      );

      // Her accounts are liabilities of the platform, so a CREDIT is money
      // owed *to* her and a DEBIT is money leaving her balance. A transfer is
      // neither, and carries no sign at all.
      const signed = isTransfer
        ? amount
        : representative.direction === LedgerDirection.CREDIT
          ? amount
          : amount.negated();

      return {
        id: representative.id,
        entry_id: representative.entry.id,
        type: representative.entry.type,
        account: representative.account.code,
        description: representative.memo ?? representative.entry.description,
        amount: signed.toJSON(),
        /// True when the money only moved between the seller's own accounts.
        is_transfer: isTransfer,
        seller_order_id: representative.entry.sellerOrderId,
        occurred_at: representative.entry.occurredAt,
      };
    });
  }

  private async ensureSeller(sellerId: string, db: Tx | PrismaService) {
    const seller = await db.user.findUnique({
      where: { id: sellerId },
      select: { id: true, role: true },
    });
    if (!seller || seller.role !== UserRole.SELLER) {
      throw new NotFoundException('Seller not found');
    }
  }
}
