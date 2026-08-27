import {
  BadRequestException,
  Injectable,
  Logger,
  NotFoundException,
} from '@nestjs/common';
import {
  CashSettlement,
  Currency,
  JournalEntryType,
  LedgerAccountCode,
  LedgerDirection,
  Prisma,
  ShipmentStatus,
} from '@prisma/client';

import { Money } from '../../common/money';
import { PrismaService } from '../../prisma/prisma.service';
import { LedgerService, PostingLine } from '../ledger/ledger.service';
import {
  FinancialAction,
  FinancialAuditService,
} from './financial-audit.service';

type Tx = Prisma.TransactionClient;

/**
 * Cash-on-delivery money between the doorstep and the platform's account.
 *
 * Q57 P1 says couriers are ours, Q55 has them recording what they collected,
 * and Q56 settles that cash **daily**. Between those two moments the money is
 * real, it is ours, and it is in someone else's pocket — so it is an asset of
 * the platform held in a `COURIER_CASH_IN_TRANSIT` account *in that courier's
 * name*. That per-courier split is the point: when a day's settlement comes up
 * short, the shortfall is already attributed to a person rather than being a
 * single unexplained platform-wide number.
 */
@Injectable()
export class CourierSettlementService {
  private readonly logger = new Logger(CourierSettlementService.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly ledger: LedgerService,
    private readonly financialAudit: FinancialAuditService,
  ) {}

  /**
   * What a courier is expected to hand over for one day: everything they
   * marked delivered and collected on it.
   */
  async expectedFor(
    courierId: string,
    date: Date,
    currency: Currency = Currency.SYP,
    tx?: Tx,
  ): Promise<Money> {
    const { start, end } = this.dayBounds(date);

    const shipments = await (tx ?? this.prisma).shipment.findMany({
      where: {
        courierId,
        status: ShipmentStatus.DELIVERED,
        deliveredAt: { gte: start, lt: end },
      },
      select: { collectedAmount: true, currency: true },
    });

    return Money.sum(
      shipments
        .filter((s) => s.currency === currency)
        .map((s) => Money.of(s.collectedAmount ?? 0, currency)),
      currency,
    );
  }

  /**
   * Records a day's settlement and moves the cash onto the platform's books.
   *
   * A variance is not an error to be rejected — it is the finding, and it has
   * to land somewhere the accounts can see. A shortfall stays in the courier's
   * in-transit account as an outstanding balance they owe; only what actually
   * arrived is debited to platform cash. Nothing is written off silently.
   */
  async settle(
    input: {
      courierId: string;
      date: Date;
      collected: Money;
      settledById: string;
      note?: string;
    },
    tx?: Tx,
  ): Promise<CashSettlement> {
    const db = tx ?? this.prisma;
    const courier = await db.courier.findUnique({
      where: { id: input.courierId },
    });
    if (!courier) throw new NotFoundException('Courier not found');

    if (input.collected.isNegative()) {
      throw new BadRequestException('Collected cash cannot be negative');
    }

    const currency = input.collected.currency;
    const periodDate = this.dayBounds(input.date).start;
    const expected = await this.expectedFor(
      input.courierId,
      input.date,
      currency,
      tx,
    );
    const variance = input.collected.minus(expected);

    const existing = await db.cashSettlement.findUnique({
      where: {
        courierId_periodDate: { courierId: input.courierId, periodDate },
      },
    });
    if (existing?.settledAt) {
      throw new BadRequestException(
        'This courier day has already been settled',
      );
    }

    const run = async (inner: Tx): Promise<CashSettlement> => {
      const settlement = await inner.cashSettlement.upsert({
        where: {
          courierId_periodDate: { courierId: input.courierId, periodDate },
        },
        update: {
          currency,
          expected: expected.toPrisma(),
          collected: input.collected.toPrisma(),
          variance: variance.toPrisma(),
          settledAt: new Date(),
          settledById: input.settledById,
          note: input.note ?? null,
        },
        create: {
          courierId: input.courierId,
          periodDate,
          currency,
          expected: expected.toPrisma(),
          collected: input.collected.toPrisma(),
          variance: variance.toPrisma(),
          settledAt: new Date(),
          settledById: input.settledById,
          note: input.note ?? null,
        },
      });

      // Only a positive hand-over is a movement worth posting. A day where
      // nothing was collected is a settled day with no entry.
      if (!input.collected.isZero()) {
        await this.ledger.post(
          {
            type: JournalEntryType.COURIER_CASH_SETTLED,
            reference: `courier-settle:${settlement.id}`,
            description: `Courier cash settled — ${courier.displayName} ${this.isoDate(periodDate)}`,
            lines: [
              {
                account: { code: LedgerAccountCode.PLATFORM_CASH },
                direction: LedgerDirection.DEBIT,
                amount: input.collected,
              },
              {
                account: {
                  code: LedgerAccountCode.COURIER_CASH_IN_TRANSIT,
                  ownerId: input.courierId,
                },
                direction: LedgerDirection.CREDIT,
                amount: input.collected,
                memo: variance.isZero()
                  ? undefined
                  : `Variance ${variance.toString()} against expected ${expected.toString()}`,
              },
            ],
            metadata: {
              settlement_id: settlement.id,
              expected: expected.toJSON(),
              collected: input.collected.toJSON(),
              variance: variance.toJSON(),
            } as Prisma.InputJsonValue,
          },
          inner,
        );
      }

      if (!variance.isZero()) {
        this.logger.warn(
          `Courier ${courier.displayName} settled ${this.isoDate(periodDate)} with a ` +
            `variance of ${variance.toString()} — remains outstanding in their in-transit account`,
        );
      }

      return settlement;
    };

    const settlement = tx ? await run(tx) : await this.prisma.$transaction(run);

    // Q65 — someone wrote down what a courier handed over, and a variance is
    // an accusation as much as a number. Both go on the record.
    await this.financialAudit.record({
      action: FinancialAction.CourierCashSettled,
      actorId: input.settledById,
      subjectId: settlement.id,
      subjectType: 'cash_settlement',
      before: expected,
      after: input.collected,
      reason: input.note ?? null,
      outcome: variance.isZero() ? 'success' : 'failed',
      extra: {
        courier_id: input.courierId,
        courier_name: courier.displayName,
        variance: variance.toJSON(),
      },
    });

    return settlement;
  }

  /**
   * What each courier still owes: the balance left in their in-transit
   * account after every settlement so far. A number that only grows is a
   * courier who is not handing cash over.
   */
  async outstanding(currency: Currency = Currency.SYP, tx?: Tx) {
    const db = tx ?? this.prisma;
    const accounts = await db.ledgerAccount.findMany({
      where: {
        code: LedgerAccountCode.COURIER_CASH_IN_TRANSIT,
        currency,
        balance: { not: 0 },
      },
      orderBy: { balance: 'desc' },
    });

    const couriers = await db.courier.findMany({
      where: { id: { in: accounts.map((a) => a.courierId!).filter(Boolean) } },
      select: { id: true, displayName: true, phone: true },
    });
    const byId = new Map(couriers.map((c) => [c.id, c]));

    return accounts.map((account) => ({
      courier: byId.get(account.courierId!) ?? null,
      outstanding: Money.of(account.balance, currency).toJSON(),
    }));
  }

  /**
   * The counter-entry a COD delivery needs: the courier now holds our cash.
   *
   * Exposed so the delivery flow can call it at the moment a shipment is
   * marked delivered, which is when the money genuinely changes hands.
   */
  collectionLines(courierId: string, amount: Money): PostingLine[] {
    return [
      {
        account: {
          code: LedgerAccountCode.COURIER_CASH_IN_TRANSIT,
          ownerId: courierId,
        },
        direction: LedgerDirection.DEBIT,
        amount,
        memo: 'Cash collected on delivery',
      },
    ];
  }

  // ── Internals ─────────────────────────────────────────────────────────

  /** Midnight-to-midnight in the server's zone; `period_date` is a DATE. */
  private dayBounds(date: Date): { start: Date; end: Date } {
    const start = new Date(date);
    start.setHours(0, 0, 0, 0);
    const end = new Date(start);
    end.setDate(end.getDate() + 1);
    return { start, end };
  }

  private isoDate(date: Date): string {
    return date.toISOString().slice(0, 10);
  }
}
