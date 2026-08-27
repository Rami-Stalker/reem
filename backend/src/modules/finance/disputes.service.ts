import {
  BadRequestException,
  ForbiddenException,
  Injectable,
  Logger,
  NotFoundException,
} from '@nestjs/common';
import {
  Currency,
  Dispute,
  DisputeStatus,
  JournalEntryType,
  LedgerAccountCode,
  LedgerDirection,
  Prisma,
  UserRole,
  WalletTransactionSource,
} from '@prisma/client';

import { AuthUser } from '../../common/decorators/current-user.decorator';
import { Money } from '../../common/money';
import { PrismaService } from '../../prisma/prisma.service';
import { LedgerService, PostingLine } from '../ledger/ledger.service';
import { WalletService } from '../ledger/wallet.service';
import {
  FinancialAction,
  FinancialAuditService,
} from './financial-audit.service';

type Tx = Prisma.TransactionClient;

/** Q107 — «القرار خلال 3 أيام عمل، ويمكن تمديدها إلى 7 أيام». */
const DECISION_DAYS = 3;
const EXTENDED_DECISION_DAYS = 7;

export interface OpenDisputeInput {
  readonly sellerOrderId: string;
  readonly openedById: string;
  readonly subject: string;
  /**
   * A partial freeze, as a decimal string. Deliberately not a `Money`: the
   * currency is the sub-order's, which only this service has read, and asking
   * a caller to guess it invites a USD sub-order being frozen in SYP.
   * Omitted, the whole sub-order net is held.
   */
  readonly amount?: string;
}

export type DisputeRuling =
  | { readonly outcome: 'CUSTOMER'; readonly note?: string }
  | { readonly outcome: 'SELLER'; readonly note?: string }
  | {
      readonly outcome: 'SPLIT';
      /**
       * The customer's share as a decimal string; the remainder returns to the
       * seller. A string for the same reason as `OpenDisputeInput.amount` —
       * the currency belongs to the dispute, not to the caller.
       */
      readonly customerShare: string;
      readonly note?: string;
    };

/**
 * Disputes, and the money they freeze.
 *
 * Q107 is specific: «يُجمّد المبلغ المتنازع عليه حتى انتهاء المراجعة» — the
 * disputed amount is frozen until the review ends, decided within 3 working
 * days, extendable to 7, with one appeal.
 *
 * "Frozen" here is not a flag on a row that a payout query has to remember to
 * check. The money is *moved*, out of the seller's balance and into a
 * `DISPUTE_HELD` account in their name. A payout run drains `SELLER_PAYABLE`,
 * so once an amount is in `DISPUTE_HELD` it is structurally unpayable — no
 * query anywhere needs to know disputes exist for the freeze to hold. Where
 * it comes from depends on when the dispute is raised: inside the return
 * window the money is still in escrow, after it, in payable.
 */
@Injectable()
export class DisputesService {
  private readonly logger = new Logger(DisputesService.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly ledger: LedgerService,
    private readonly wallets: WalletService,
    private readonly financialAudit: FinancialAuditService,
  ) {}

  // ── Opening ───────────────────────────────────────────────────────────

  /**
   * Opens a dispute and freezes the amount under review.
   *
   * Accepts a caller's transaction so a dispute raised as part of a larger
   * flow — a return being rejected, say — commits atomically with it.
   */
  async open(input: OpenDisputeInput, tx?: Tx): Promise<Dispute> {
    const db = tx ?? this.prisma;
    const sellerOrder = await db.sellerOrder.findUnique({
      where: { id: input.sellerOrderId },
      include: { dispute: true },
    });
    if (!sellerOrder) throw new NotFoundException('Sub-order not found');
    if (sellerOrder.dispute) {
      throw new BadRequestException(
        'A dispute is already open on this sub-order',
      );
    }

    const currency = sellerOrder.currency;
    const frozen =
      input.amount === undefined
        ? Money.of(sellerOrder.sellerNet, currency)
        : Money.of(input.amount, currency);
    if (frozen.isZero() || frozen.isNegative()) {
      throw new BadRequestException('Nothing to freeze on this sub-order');
    }

    const net = Money.of(sellerOrder.sellerNet, currency);
    if (frozen.greaterThan(net)) {
      throw new BadRequestException(
        `Cannot freeze ${frozen.toString()} — the sub-order is only worth ${net.toString()}`,
      );
    }

    const run = async (inner: Tx): Promise<Dispute> => {
      const dispute = await inner.dispute.create({
        data: {
          number: await this.nextNumber(inner),
          sellerOrderId: sellerOrder.id,
          openedById: input.openedById,
          subject: input.subject,
          currency,
          frozenAmount: frozen.toPrisma(),
          dueAt: this.workingDaysFromNow(DECISION_DAYS),
        },
      });

      // Take the money out of wherever it currently sits. Before the return
      // window closes it is still in escrow; after, it has moved to payable.
      const source = sellerOrder.escrowReleased
        ? LedgerAccountCode.SELLER_PAYABLE
        : LedgerAccountCode.SELLER_ESCROW;

      await this.ledger.post(
        {
          type: JournalEntryType.DISPUTE_HELD,
          reference: `dispute-freeze:${dispute.id}`,
          description: `Dispute ${dispute.number} opened — funds frozen`,
          orderId: sellerOrder.orderId,
          sellerOrderId: sellerOrder.id,
          lines: [
            {
              account: { code: source, ownerId: sellerOrder.sellerId },
              direction: LedgerDirection.DEBIT,
              amount: frozen,
            },
            {
              account: {
                code: LedgerAccountCode.DISPUTE_HELD,
                ownerId: sellerOrder.sellerId,
              },
              direction: LedgerDirection.CREDIT,
              amount: frozen,
              memo: `Held pending dispute ${dispute.number}`,
            },
          ],
          metadata: {
            dispute_id: dispute.id,
            frozen_from: source,
          } as Prisma.InputJsonValue,
        },
        inner,
      );

      return dispute;
    };

    const dispute = tx ? await run(tx) : await this.prisma.$transaction(run);

    // Freezing a seller's money is a financial act with a victim if it is
    // wrong, so it is on the record with who asked for it (Q65).
    await this.financialAudit.record({
      action: FinancialAction.DisputeOpened,
      actorId: input.openedById,
      subjectId: dispute.id,
      subjectType: 'dispute',
      after: frozen,
      reason: input.subject,
      extra: {
        seller_order_id: sellerOrder.id,
        seller_id: sellerOrder.sellerId,
        number: dispute.number,
      },
    });

    return dispute;
  }

  // ── Deciding ──────────────────────────────────────────────────────────

  /**
   * Rules on a dispute and releases the frozen amount accordingly.
   *
   * Q107 gives three shapes of outcome, and each moves the held money to a
   * different place: back to the seller, to the customer as wallet credit, or
   * split. The held account nets to zero either way — a dispute that has been
   * decided leaves nothing behind.
   */
  async decide(
    disputeId: string,
    ruling: DisputeRuling,
    decidedById: string,
    tx?: Tx,
  ): Promise<Dispute> {
    const db = tx ?? this.prisma;
    const dispute = await db.dispute.findUnique({
      where: { id: disputeId },
      include: {
        sellerOrder: {
          select: {
            id: true,
            orderId: true,
            sellerId: true,
            order: { select: { userId: true } },
          },
        },
      },
    });
    if (!dispute) throw new NotFoundException('Dispute not found');
    if (this.isDecided(dispute.status)) {
      throw new BadRequestException('This dispute has already been decided');
    }

    const currency = dispute.currency;
    const held = Money.of(dispute.frozenAmount, currency);
    const sellerId = dispute.sellerOrder.sellerId;
    const customerId = dispute.sellerOrder.order.userId;

    const { toCustomer, toSeller, status } = this.split(ruling, held, currency);

    if (toCustomer.greaterThan(Money.zero(currency)) && !customerId) {
      throw new BadRequestException(
        'This order has no registered customer to refund — settle it manually',
      );
    }

    const run = async (inner: Tx): Promise<Dispute> => {
      const lines: PostingLine[] = [
        {
          account: {
            code: LedgerAccountCode.DISPUTE_HELD,
            ownerId: sellerId,
          },
          direction: LedgerDirection.DEBIT,
          amount: held,
          memo: `Dispute ${dispute.number} decided`,
        },
      ];

      // The seller's share goes back to payable, immediately drainable.
      if (!toSeller.isZero()) {
        lines.push({
          account: {
            code: LedgerAccountCode.SELLER_PAYABLE,
            ownerId: sellerId,
          },
          direction: LedgerDirection.CREDIT,
          amount: toSeller,
          memo: 'Released to seller',
        });
      }

      // The customer's share becomes wallet credit. Q42 keeps it spendable
      // on the platform rather than withdrawable.
      if (!toCustomer.isZero()) {
        lines.push({
          account: {
            code: LedgerAccountCode.CUSTOMER_WALLET,
            ownerId: customerId!,
          },
          direction: LedgerDirection.CREDIT,
          amount: toCustomer,
          memo: 'Awarded to customer',
        });
      }

      const entry = await this.ledger.post(
        {
          type: JournalEntryType.DISPUTE_RELEASED,
          reference: `dispute-release:${dispute.id}`,
          description: `Dispute ${dispute.number} decided`,
          orderId: dispute.sellerOrder.orderId,
          sellerOrderId: dispute.sellerOrder.id,
          createdById: decidedById,
          lines,
          metadata: {
            dispute_id: dispute.id,
            to_customer: toCustomer.toJSON(),
            to_seller: toSeller.toJSON(),
          } as Prisma.InputJsonValue,
        },
        inner,
      );

      // Mirror the customer's share into her wallet statement. The ledger
      // above already moved it; this writes the row she reads (Q41), so the
      // two stay in step because they share one transaction.
      if (!toCustomer.isZero()) {
        await this.recordWalletStatementRow(
          inner,
          customerId!,
          toCustomer,
          dispute,
          entry.id,
        );
      }

      return inner.dispute.update({
        where: { id: dispute.id },
        data: {
          status,
          decidedById,
          decidedAt: new Date(),
          decisionNote: ruling.note ?? null,
        },
      });
    };

    const decided = tx ? await run(tx) : await this.prisma.$transaction(run);

    // Q65 — a ruling releases frozen money in a direction someone chose.
    await this.financialAudit.record({
      action: FinancialAction.DisputeDecided,
      actorId: decidedById,
      subjectId: dispute.id,
      subjectType: 'dispute',
      before: dispute.status,
      after: status,
      reason: ruling.note ?? null,
      extra: {
        number: dispute.number,
        held: held.toJSON(),
        to_customer: toCustomer.toJSON(),
        to_seller: toSeller.toJSON(),
        seller_id: sellerId,
      },
    });

    return decided;
  }

  /**
   * Q107 — «مع إمكانية الاستئناف مرة واحدة».
   *
   * Re-opens a decided dispute for one more review and extends the deadline to
   * seven days. The money is *not* re-frozen: it was already released by the
   * ruling being appealed, and taking it back automatically could overdraw a
   * seller who has since been paid. A successful appeal is settled as a fresh
   * adjustment by whoever decides it.
   */
  async appeal(disputeId: string, note?: string, tx?: Tx): Promise<Dispute> {
    const db = tx ?? this.prisma;
    const dispute = await db.dispute.findUnique({
      where: { id: disputeId },
    });
    if (!dispute) throw new NotFoundException('Dispute not found');
    if (!this.isDecided(dispute.status)) {
      throw new BadRequestException('Only a decided dispute can be appealed');
    }
    if (dispute.appealUsed) {
      throw new BadRequestException('This dispute has already been appealed');
    }

    return db.dispute.update({
      where: { id: dispute.id },
      data: {
        status: DisputeStatus.APPEALED,
        appealUsed: true,
        extendedTo: this.workingDaysFromNow(EXTENDED_DECISION_DAYS),
        decisionNote: note ?? dispute.decisionNote,
      },
    });
  }

  // ── Evidence (Q107) ───────────────────────────────────────────────────

  /**
   * Adds a message, and with it whatever photographs make the case.
   *
   * Q107 asks for «طلب أدلة من الطرفين» — evidence from both sides — and until
   * now a dispute could be opened and decided without either of them being
   * able to say a word. The seller's money is frozen for up to seven working
   * days by that process; the least it can offer her is somewhere to explain.
   *
   * `isInternal` is support talking to itself: a note about a caller, a
   * suspicion, a link to another case. Only staff may write one and only staff
   * ever read one, which is why the visibility is decided here rather than
   * trusted to whatever screen happens to be rendering.
   */
  async addMessage(
    disputeId: string,
    author: AuthUser,
    input: { body: string; evidence?: readonly string[]; isInternal?: boolean },
    tx?: Tx,
  ) {
    const db = tx ?? this.prisma;
    const dispute = await this.loadForParticipant(disputeId, author, db);

    if (dispute.status === DisputeStatus.CLOSED) {
      throw new BadRequestException('This dispute is closed');
    }

    const isStaff = this.isStaff(author.role);
    if (input.isInternal && !isStaff) {
      throw new ForbiddenException('Only support can leave an internal note');
    }

    const message = await db.disputeMessage.create({
      data: {
        disputeId,
        authorId: author.id,
        body: input.body,
        evidence: input.evidence?.length
          ? ({ photos: [...input.evidence] } as Prisma.InputJsonValue)
          : undefined,
        isInternal: input.isInternal ?? false,
      },
    });

    // A dispute that someone is still arguing is a dispute under review, not
    // one nobody has looked at. The clock (Q107) is untouched: answering does
    // not buy the platform more time to decide.
    if (dispute.status === DisputeStatus.OPEN && isStaff) {
      await db.dispute.update({
        where: { id: disputeId },
        data: { status: DisputeStatus.UNDER_REVIEW },
      });
    }

    return this.serializeMessage(message, author.id);
  }

  /**
   * The thread, from the reader's own side of it.
   *
   * Internal notes are filtered out for the parties rather than marked hidden:
   * a message she can see the existence of is a message she will ask about.
   */
  async messages(disputeId: string, viewer: AuthUser, tx?: Tx) {
    const db = tx ?? this.prisma;
    await this.loadForParticipant(disputeId, viewer, db);
    const isStaff = this.isStaff(viewer.role);

    const rows = await db.disputeMessage.findMany({
      where: {
        disputeId,
        ...(isStaff ? {} : { isInternal: false }),
      },
      orderBy: { createdAt: 'asc' },
    });

    return rows.map((row) => this.serializeMessage(row, viewer.id));
  }

  /** Her disputes, or his — whichever side of the sale the reader is on. */
  async listFor(user: AuthUser, tx?: Tx) {
    const disputes = await (tx ?? this.prisma).dispute.findMany({
      where: this.isStaff(user.role)
        ? {}
        : {
            OR: [
              { sellerOrder: { sellerId: user.id } },
              { sellerOrder: { order: { userId: user.id } } },
            ],
          },
      orderBy: { createdAt: 'desc' },
      take: 50,
      include: {
        sellerOrder: { select: { number: true, sellerId: true } },
        _count: { select: { messages: true } },
      },
    });

    return disputes.map((dispute) => ({
      id: dispute.id,
      number: dispute.number,
      status: dispute.status,
      subject: dispute.subject,
      order_number: dispute.sellerOrder.number,
      frozen_amount: Money.of(
        dispute.frozenAmount,
        dispute.currency,
      ).toJSON(),
      due_at: dispute.extendedTo ?? dispute.dueAt,
      appeal_used: dispute.appealUsed,
      decided_at: dispute.decidedAt,
      messages_count: dispute._count.messages,
      created_at: dispute.createdAt,
    }));
  }

  /**
   * Loads a dispute the reader is actually part of.
   *
   * Not a 403 for a stranger: a dispute number is a number, and confirming
   * that one exists tells whoever guessed it something about a sale that is
   * none of their business.
   */
  private async loadForParticipant(
    disputeId: string,
    user: AuthUser,
    db: Tx | PrismaService = this.prisma,
  ) {
    const dispute = await db.dispute.findUnique({
      where: { id: disputeId },
      include: {
        sellerOrder: {
          select: { sellerId: true, order: { select: { userId: true } } },
        },
      },
    });
    if (!dispute) throw new NotFoundException('Dispute not found');

    const isParty =
      dispute.sellerOrder.sellerId === user.id ||
      dispute.sellerOrder.order.userId === user.id;
    if (!isParty && !this.isStaff(user.role)) {
      throw new NotFoundException('Dispute not found');
    }

    return dispute;
  }

  private isStaff(role: UserRole): boolean {
    return (
      role === UserRole.SUPER_ADMIN ||
      role === UserRole.SUPPORT_ADMIN ||
      role === UserRole.OPERATIONS_ADMIN ||
      role === UserRole.FINANCE_ADMIN ||
      role === UserRole.SUPPORT ||
      role === UserRole.ADMIN
    );
  }

  private serializeMessage(
    message: {
      id: string;
      authorId: string;
      body: string;
      evidence: Prisma.JsonValue;
      isInternal: boolean;
      createdAt: Date;
    },
    viewerId: string,
  ) {
    return {
      id: message.id,
      body: message.body,
      evidence:
        (message.evidence as { photos?: string[] } | null)?.photos ?? [],
      is_internal: message.isInternal,
      is_mine: message.authorId === viewerId,
      created_at: message.createdAt,
    };
  }

  // ── Reading ───────────────────────────────────────────────────────────

  /** How much of a seller's money is frozen right now. */
  async heldFor(sellerId: string, currency = Currency.SYP): Promise<Money> {
    return this.ledger.balanceOf(
      { code: LedgerAccountCode.DISPUTE_HELD, ownerId: sellerId },
      currency,
    );
  }

  /** Disputes past their decision deadline — Q107's 3/7 working-day clock. */
  async overdue(now = new Date()) {
    return this.prisma.dispute.findMany({
      where: {
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
    });
  }

  // ── Internals ─────────────────────────────────────────────────────────

  /** Splits the held amount according to the ruling. */
  private split(
    ruling: DisputeRuling,
    held: Money,
    currency: Currency,
  ): { toCustomer: Money; toSeller: Money; status: DisputeStatus } {
    switch (ruling.outcome) {
      case 'CUSTOMER':
        return {
          toCustomer: held,
          toSeller: Money.zero(currency),
          status: DisputeStatus.RESOLVED_FOR_CUSTOMER,
        };
      case 'SELLER':
        return {
          toCustomer: Money.zero(currency),
          toSeller: held,
          status: DisputeStatus.RESOLVED_FOR_SELLER,
        };
      case 'SPLIT': {
        const toCustomer = Money.of(ruling.customerShare, currency);
        if (toCustomer.isNegative() || toCustomer.greaterThan(held)) {
          throw new BadRequestException(
            `The customer's share must be between zero and the frozen ${held.toString()}`,
          );
        }
        return {
          toCustomer,
          toSeller: held.minus(toCustomer),
          status: DisputeStatus.RESOLVED_SPLIT,
        };
      }
    }
  }

  private isDecided(status: DisputeStatus): boolean {
    return (
      status === DisputeStatus.RESOLVED_FOR_CUSTOMER ||
      status === DisputeStatus.RESOLVED_FOR_SELLER ||
      status === DisputeStatus.RESOLVED_SPLIT ||
      status === DisputeStatus.CLOSED
    );
  }

  /**
   * Writes the customer's wallet statement row for an award.
   *
   * The ledger movement was already posted as part of the release entry, so
   * this deliberately does not go through `WalletService.credit` — that would
   * post a second journal entry and double the credit. `recordPostedCredit`
   * is the wallet's own path for exactly that case: it updates the cached
   * balance under the row lock and appends the statement row the customer
   * reads, inside the transaction that posted the entry.
   */
  private async recordWalletStatementRow(
    tx: Tx,
    customerId: string,
    amount: Money,
    dispute: Dispute,
    journalEntryId?: string,
  ): Promise<void> {
    await this.wallets.recordPostedCredit(
      {
        userId: customerId,
        amount,
        source: WalletTransactionSource.RETURN_REFUND,
        reason: `تسوية نزاع ${dispute.number}`,
        reference: `dispute-award:${dispute.id}`,
        journalEntryId,
      },
      tx,
    );
  }

  /**
   * Q107 counts in *working* days. Friday is the weekend in Syria, and Q88
   * puts the platform's own working hours at 09:00–23:00, so Fridays are
   * skipped when counting the deadline forward.
   */
  private workingDaysFromNow(days: number, from = new Date()): Date {
    const due = new Date(from);
    let remaining = days;
    while (remaining > 0) {
      due.setDate(due.getDate() + 1);
      if (due.getDay() !== 5) remaining -= 1;
    }
    return due;
  }

  /** `DSP-000123` — human-quotable in a support conversation. */
  private async nextNumber(tx: Tx): Promise<string> {
    const count = await tx.dispute.count();
    return `DSP-${String(count + 1).padStart(6, '0')}`;
  }
}
