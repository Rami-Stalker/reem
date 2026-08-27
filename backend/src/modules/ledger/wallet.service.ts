import {
  BadRequestException,
  ForbiddenException,
  Inject,
  Injectable,
  NotFoundException,
  Optional,
} from '@nestjs/common';
import {
  Currency,
  JournalEntryType,
  LedgerAccountCode,
  LedgerDirection,
  Prisma,
  Wallet,
  WalletTransaction,
  WalletTransactionSource,
} from '@prisma/client';

import { Money } from '../../common/money';
import { PrismaService } from '../../prisma/prisma.service';
import { AccountRef, LedgerService, PostingLine } from './ledger.service';

/**
 * Records a money movement in the audit trail. Injected as a callback rather
 * than a service so `LedgerModule` does not have to depend on the finance
 * layer that sits above it — the kernel stays underneath everything.
 */
export type WalletAuditHook = (event: {
  action: 'wallet.credited' | 'wallet.frozen';
  actorId?: string | null;
  walletId: string;
  userId: string;
  before: Money;
  after: Money;
  reason: string;
  source?: string;
}) => Promise<void>;

export const WALLET_AUDIT_HOOK = Symbol('WALLET_AUDIT_HOOK');

type Tx = Prisma.TransactionClient;

/** Which sources add credit, as opposed to spending it. */
const CREDIT_SOURCES: ReadonlySet<WalletTransactionSource> = new Set([
  WalletTransactionSource.RETURN_REFUND,
  WalletTransactionSource.POINTS_CONVERSION,
  WalletTransactionSource.ADMIN_COMPENSATION,
  WalletTransactionSource.CUSTOMER_TOPUP,
  WalletTransactionSource.CAMPAIGN_GIFT,
  WalletTransactionSource.PRICE_ADJUSTMENT,
  WalletTransactionSource.ORDER_REVERSAL,
]);

/**
 * Which platform account a wallet movement settles against, where that is
 * unambiguous.
 *
 * A wallet credit is a liability we take on, so something must give it value.
 * For a top-up the customer handed over cash; for a gift the platform books
 * marketing spend; converting points moves one liability into another.
 *
 * Refunds and price adjustments are deliberately absent. Who absorbs a refund
 * depends on fault — Q56 P1 puts it on the seller for a defect and on the
 * customer for a change of mind, and Q67 answers «حسب الحالة» — so the caller
 * that knows the ruling must name the account. Guessing here would produce an
 * entry that balances while describing the wrong business, which is worse than
 * refusing: a wrong book still adds up.
 */
const FUNDING_ACCOUNT: Readonly<
  Partial<Record<WalletTransactionSource, LedgerAccountCode>>
> = Object.freeze({
  // She paid us; we hold cash and owe her credit.
  [WalletTransactionSource.CUSTOMER_TOPUP]: LedgerAccountCode.PLATFORM_CASH,
  // Marketing and goodwill are platform expense.
  [WalletTransactionSource.ADMIN_COMPENSATION]:
    LedgerAccountCode.PLATFORM_PROMOTION_EXPENSE,
  [WalletTransactionSource.CAMPAIGN_GIFT]:
    LedgerAccountCode.PLATFORM_PROMOTION_EXPENSE,
  // Points becoming spendable moves one liability into another.
  [WalletTransactionSource.POINTS_CONVERSION]:
    LedgerAccountCode.LOYALTY_LIABILITY,
  // Spending credit settles against the cash the platform already holds.
  [WalletTransactionSource.ORDER_PAYMENT]: LedgerAccountCode.PLATFORM_CASH,
  [WalletTransactionSource.ORDER_REVERSAL]: LedgerAccountCode.PLATFORM_CASH,
});

export interface WalletMovementInput {
  readonly userId: string;
  readonly amount: Money;
  readonly source: WalletTransactionSource;
  readonly reason: string;
  readonly orderId?: string | null;
  /** Idempotency key for the causing event. */
  readonly reference?: string;
  /** The admin behind a manual credit (Q65). */
  readonly createdById?: string | null;
  /**
   * The account this movement settles against, overriding the default for the
   * source. Required for refunds and price adjustments, where only the caller
   * knows who absorbs the amount — typically the seller's payable when the
   * fault was theirs, or platform promotion expense as a goodwill gesture.
   */
  readonly fundedBy?: AccountRef;
}

/**
 * A credit the caller has already posted to the ledger itself, needing only
 * its customer-facing statement row. See `recordPostedCredit`.
 */
export interface PostedCreditInput {
  readonly userId: string;
  readonly amount: Money;
  readonly source: WalletTransactionSource;
  readonly reason: string;
  /** Idempotency key — normally the same one the journal entry carries. */
  readonly reference: string;
  readonly orderId?: string | null;
  /** The entry that moved the money, so the row points at its own proof. */
  readonly journalEntryId?: string | null;
  readonly createdById?: string | null;
}

export interface WalletStatement {
  wallet: Wallet;
  transactions: WalletTransaction[];
  total: number;
}

/**
 * The customer's store credit.
 *
 * Q42 settles the shape of this feature: the balance is spendable inside Reem
 * and **cannot be withdrawn as cash**. That is why this class has `credit` and
 * `spend` but no `withdraw` — the restriction is expressed by the absence of a
 * code path, not by a flag some future caller can pass.
 *
 * Every movement writes two things in one transaction: a `WalletTransaction`
 * row for the customer-facing statement Q41 asked for («سجل كامل لحركات
 * المحفظة»), and a balanced journal entry in the book of record. The wallet
 * balance is a liability of the platform, and the ledger says so.
 */
@Injectable()
export class WalletService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly ledger: LedgerService,
    @Optional()
    @Inject(WALLET_AUDIT_HOOK)
    private readonly auditHook?: WalletAuditHook,
  ) {}

  /** The wallet, created empty on first access. */
  async getOrCreate(
    userId: string,
    currency: Currency = Currency.SYP,
    tx?: Tx,
  ): Promise<Wallet> {
    const client = tx ?? this.prisma;
    return client.wallet.upsert({
      where: { userId_currency: { userId, currency } },
      update: {},
      create: { userId, currency },
    });
  }

  async balanceOf(
    userId: string,
    currency: Currency = Currency.SYP,
  ): Promise<Money> {
    const wallet = await this.prisma.wallet.findUnique({
      where: { userId_currency: { userId, currency } },
    });
    return Money.of(wallet?.balance ?? 0, currency);
  }

  /** Q41 — adds credit from one of the permitted sources. */
  async credit(
    input: WalletMovementInput,
    tx?: Tx,
  ): Promise<WalletTransaction> {
    if (!CREDIT_SOURCES.has(input.source)) {
      throw new BadRequestException(
        `${input.source} is a spend, not a credit — use spend()`,
      );
    }
    return this.move(input, 'CREDIT', tx);
  }

  /**
   * Spends credit at checkout.
   *
   * Refuses to overdraw: a wallet is money already owed to the customer, and
   * letting it go negative would silently turn it into an unapproved loan.
   */
  async spend(
    input: Omit<WalletMovementInput, 'source'> & {
      source?: WalletTransactionSource;
    },
    tx?: Tx,
  ): Promise<WalletTransaction> {
    return this.move(
      { ...input, source: input.source ?? WalletTransactionSource.ORDER_PAYMENT },
      'DEBIT',
      tx,
    );
  }

  /**
   * Q41 «أخرى» — the full movement history, newest first.
   *
   * Each row carries `balanceAfter`, so a statement prints without re-summing
   * the history and a customer can see exactly how a figure was reached.
   */
  async statement(
    userId: string,
    currency: Currency = Currency.SYP,
    { skip = 0, take = 50 }: { skip?: number; take?: number } = {},
  ): Promise<WalletStatement> {
    const wallet = await this.prisma.wallet.findUnique({
      where: { userId_currency: { userId, currency } },
    });
    if (!wallet) {
      throw new NotFoundException('Wallet not found');
    }

    const [transactions, total] = await Promise.all([
      this.prisma.walletTransaction.findMany({
        where: { walletId: wallet.id },
        orderBy: { createdAt: 'desc' },
        skip,
        take,
      }),
      this.prisma.walletTransaction.count({ where: { walletId: wallet.id } }),
    ]);

    return { wallet, transactions, total };
  }

  /**
   * Writes the statement row for a credit whose journal entry the caller has
   * already posted.
   *
   * `credit()` covers the ordinary case, where one funding account pays for
   * the whole amount. Some credits do not have one: a refund is funded partly
   * by the seller giving back her net and partly by the platform giving back
   * its commission, and a dispute award comes out of a held account — those
   * are single balanced entries with three or four lines, which `fundedBy`
   * (one account) cannot express.
   *
   * Rather than let each caller reinvent the balance update and risk one of
   * them forgetting the row lock, they post their own entry and hand it here.
   * The transaction is **required**, not optional: the entry and this row are
   * two halves of one fact, and a caller that could pass `undefined` would
   * eventually commit one without the other.
   */
  async recordPostedCredit(
    input: PostedCreditInput,
    tx: Tx,
  ): Promise<WalletTransaction> {
    if (input.amount.isNegative() || input.amount.isZero()) {
      throw new BadRequestException(
        'A wallet movement must be for a positive amount',
      );
    }
    if (!CREDIT_SOURCES.has(input.source)) {
      throw new BadRequestException(
        `${input.source} is a spend, not a credit`,
      );
    }

    const existing = await tx.walletTransaction.findUnique({
      where: { reference: input.reference },
    });
    if (existing) return existing;

    const currency = input.amount.currency;
    const wallet = await this.getOrCreate(input.userId, currency, tx);

    // Same lock as `move()` — the caller's entry did not touch this row, so
    // the read-modify-write below still has to serialise against other
    // movements on the same wallet.
    await tx.$queryRaw`SELECT id FROM wallets WHERE id = ${wallet.id}::uuid FOR UPDATE`;
    const current = await tx.wallet.findUniqueOrThrow({
      where: { id: wallet.id },
    });

    const before = Money.of(current.balance, currency);
    const after = before.plus(input.amount);

    await tx.wallet.update({
      where: { id: wallet.id },
      data: { balance: after.toPrisma() },
    });

    const movement = await tx.walletTransaction.create({
      data: {
        walletId: wallet.id,
        source: input.source,
        amount: input.amount.toPrisma(),
        currency,
        balanceAfter: after.toPrisma(),
        reason: input.reason,
        orderId: input.orderId ?? null,
        journalEntryId: input.journalEntryId ?? null,
        reference: input.reference,
        createdById: input.createdById ?? null,
      },
    });

    // Q65 — a wallet credit is a wallet credit however it was funded.
    await this.auditHook?.({
      action: 'wallet.credited',
      actorId: input.createdById,
      walletId: wallet.id,
      userId: input.userId,
      before,
      after,
      reason: input.reason,
      source: input.source,
    });

    return movement;
  }

  /** Admin freeze/unfreeze. Blocks spending; the balance is untouched. */
  async setFrozen(
    userId: string,
    currency: Currency,
    frozen: boolean,
    options: { actorId?: string | null; reason?: string } = {},
  ): Promise<Wallet> {
    const wallet = await this.getOrCreate(userId, currency);
    const updated = await this.prisma.wallet.update({
      where: { id: wallet.id },
      data: { frozen },
    });

    // Freezing does not move money, but it stops her spending her own — which
    // is exactly the kind of act Q65 wants attributable to a person.
    await this.auditHook?.({
      action: 'wallet.frozen',
      actorId: options.actorId,
      walletId: wallet.id,
      userId,
      before: Money.of(wallet.frozen ? 1 : 0, currency),
      after: Money.of(frozen ? 1 : 0, currency),
      reason: options.reason ?? (frozen ? 'Wallet frozen' : 'Wallet unfrozen'),
    });

    return updated;
  }

  // ── Internals ─────────────────────────────────────────────────────────

  /**
   * The one path that changes a balance.
   *
   * Both the statement row and the journal entry are written inside a single
   * transaction, and the wallet row is locked for the read-modify-write so two
   * concurrent spends cannot both see the same starting balance and overdraw
   * between them.
   */
  private async move(
    input: WalletMovementInput,
    kind: 'CREDIT' | 'DEBIT',
    tx?: Tx,
  ): Promise<WalletTransaction> {
    if (input.amount.isNegative() || input.amount.isZero()) {
      throw new BadRequestException(
        'A wallet movement must be for a positive amount',
      );
    }

    const run = async (inner: Tx): Promise<WalletTransaction> => {
      const currency = input.amount.currency;

      // Idempotency — a retried refund must not credit twice.
      if (input.reference) {
        const existing = await inner.walletTransaction.findUnique({
          where: { reference: input.reference },
        });
        if (existing) return existing;
      }

      const wallet = await this.getOrCreate(input.userId, currency, inner);

      // Serialise concurrent movements on this wallet. Without the lock two
      // checkouts could each read the same balance and both pass the funds
      // check below.
      await inner.$queryRaw`SELECT id FROM wallets WHERE id = ${wallet.id}::uuid FOR UPDATE`;

      const current = await inner.wallet.findUniqueOrThrow({
        where: { id: wallet.id },
      });
      const balance = Money.of(current.balance, currency);

      if (kind === 'DEBIT') {
        if (current.frozen) {
          throw new ForbiddenException('This wallet is frozen');
        }
        if (input.amount.greaterThan(balance)) {
          throw new BadRequestException(
            `Insufficient wallet balance: have ${balance.toString()}, need ${input.amount.toString()}`,
          );
        }
      }

      const delta =
        kind === 'CREDIT' ? input.amount : input.amount.negated();
      const balanceAfter = balance.plus(delta);

      const updated = await inner.wallet.update({
        where: { id: wallet.id },
        data: { balance: balanceAfter.toPrisma() },
      });

      const journal = await this.ledger.post(
        {
          type:
            kind === 'CREDIT'
              ? JournalEntryType.WALLET_TOPUP
              : JournalEntryType.WALLET_SPENT,
          reference:
            input.reference ??
            `wallet:${updated.id}:${Date.now()}:${kind.toLowerCase()}`,
          description: input.reason,
          orderId: input.orderId ?? null,
          createdById: input.createdById ?? null,
          lines: this.journalLines(input, kind),
          metadata: {
            wallet_id: wallet.id,
            source: input.source,
          } as Prisma.InputJsonValue,
        },
        inner,
      );

      const movement = await inner.walletTransaction.create({
        data: {
          walletId: wallet.id,
          source: input.source,
          amount: delta.toPrisma(),
          currency,
          balanceAfter: balanceAfter.toPrisma(),
          reason: input.reason,
          orderId: input.orderId ?? null,
          journalEntryId: journal.id,
          reference: input.reference ?? null,
          createdById: input.createdById ?? null,
        },
      });

      // Q65 — «إضافة/خصم رصيد من المحافظ» with the value before and after.
      await this.auditHook?.({
        action: 'wallet.credited',
        actorId: input.createdById,
        walletId: wallet.id,
        userId: input.userId,
        before: balance,
        after: balanceAfter,
        reason: input.reason,
        source: input.source,
      });

      return movement;
    };

    if (tx) return run(tx);
    return this.prisma.$transaction(run);
  }

  /**
   * The two sides of the movement.
   *
   * A credit raises the wallet liability and is funded by whatever
   * [FUNDING_ACCOUNT] says paid for it; a spend does the reverse — the
   * liability falls and the platform keeps the cash.
   */
  /**
   * Resolves the account the movement settles against: the caller's explicit
   * choice, or the default for the source. Sources with no safe default throw
   * rather than land somewhere plausible-looking.
   */
  private fundingAccount(input: WalletMovementInput): AccountRef {
    if (input.fundedBy) return input.fundedBy;

    const fallback = FUNDING_ACCOUNT[input.source];
    if (!fallback) {
      throw new BadRequestException(
        `${input.source} has no default funding account — pass fundedBy naming ` +
          'who absorbs this amount (Q56/Q67: seller on fault, customer on change of mind)',
      );
    }
    return { code: fallback };
  }

  private journalLines(
    input: WalletMovementInput,
    kind: 'CREDIT' | 'DEBIT',
  ): PostingLine[] {
    const walletAccount: AccountRef = {
      code: LedgerAccountCode.CUSTOMER_WALLET,
      ownerId: input.userId,
    };
    const funding = this.fundingAccount(input);

    if (kind === 'CREDIT') {
      return [
        // The platform gains value (cash) or books the cost (promotion).
        {
          account: funding,
          direction: LedgerDirection.DEBIT,
          amount: input.amount,
          memo: input.reason,
        },
        // …and owes the customer that much credit.
        {
          account: walletAccount,
          direction: LedgerDirection.CREDIT,
          amount: input.amount,
          memo: input.reason,
        },
      ];
    }

    return [
      // The obligation to the customer shrinks…
      {
        account: walletAccount,
        direction: LedgerDirection.DEBIT,
        amount: input.amount,
        memo: input.reason,
      },
      // …and the platform keeps the cash it already held.
      {
        account: funding,
        direction: LedgerDirection.CREDIT,
        amount: input.amount,
        memo: input.reason,
      },
    ];
  }
}
