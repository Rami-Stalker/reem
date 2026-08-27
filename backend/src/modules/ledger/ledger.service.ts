import { BadRequestException, Injectable, Logger } from '@nestjs/common';
import {
  Currency,
  JournalEntry,
  JournalEntryType,
  LedgerAccount,
  LedgerAccountCode,
  LedgerDirection,
  Prisma,
} from '@prisma/client';

import { Money } from '../../common/money';
import { PrismaService } from '../../prisma/prisma.service';
import { definitionOf, isDebitNormal } from './chart-of-accounts';

const Decimal = Prisma.Decimal;

/** Stands in for "no owner" in the uniqueness key of platform accounts. */
export const PLATFORM_OWNER_KEY = 'platform';

/**
 * How far a converted amount may sit from the arithmetic, per currency.
 *
 * SYP is charged rounded to the nearest 1000 (Q48), so half a step either way
 * is the most an honest conversion can differ by. USD carries cents, so its
 * tolerance is one.
 */
const DEFAULT_CONVERSION_TOLERANCE: Readonly<Record<Currency, string>> =
  Object.freeze({
    [Currency.SYP]: '500',
    [Currency.USD]: '0.01',
  });

/** Identifies one account: its code plus, for per-owner codes, whose it is. */
export interface AccountRef {
  readonly code: LedgerAccountCode;
  readonly ownerId?: string | null;
}

/** One side of a posting. */
export interface PostingLine {
  readonly account: AccountRef;
  readonly direction: LedgerDirection;
  readonly amount: Money;
  readonly memo?: string;
}

export interface PostJournalInput {
  readonly type: JournalEntryType;
  /**
   * Idempotency key for the business event. Re-posting the same reference is a
   * no-op that returns the original entry — safe under retries, webhook
   * redelivery, and a worker that crashed mid-run.
   */
  readonly reference: string;
  readonly description: string;
  readonly lines: readonly PostingLine[];
  readonly orderId?: string | null;
  readonly sellerOrderId?: string | null;
  readonly createdById?: string | null;
  readonly metadata?: Prisma.InputJsonValue;
  readonly occurredAt?: Date;
}

/** One side of a currency conversion. */
export interface ConversionSide {
  readonly account: AccountRef;
  readonly amount: Money;
  readonly memo?: string;
}

export interface PostConversionInput {
  readonly type: JournalEntryType;
  readonly reference: string;
  readonly description: string;
  /** The obligation being discharged, in its own currency. */
  readonly debit: ConversionSide;
  /** What funds it, in the other currency. */
  readonly credit: ConversionSide;
  /** Units of the credit currency per unit of the debit currency. */
  readonly rate: Prisma.Decimal;
  /**
   * How far the converted amount may sit from `debit × rate` before the entry
   * is rejected. Defaults to enough room for Q48's rounding to the nearest
   * 1000 SYP; a caller converting into a currency with a coarser rounding
   * policy must widen it deliberately.
   */
  readonly tolerance?: Money;
  readonly orderId?: string | null;
  readonly sellerOrderId?: string | null;
  readonly createdById?: string | null;
  readonly metadata?: Prisma.InputJsonValue;
  readonly occurredAt?: Date;
}

/** A Prisma transaction client, so callers can post inside their own tx. */
type Tx = Prisma.TransactionClient;

export type JournalEntryWithLines = JournalEntry & {
  lines: Array<Prisma.JournalLineGetPayload<{ include: { account: true } }>>;
};

/**
 * The book of record.
 *
 * Every movement of money on the platform is a balanced journal entry: total
 * debits equal total credits, per currency, or nothing is written at all. That
 * is what makes Q52's «كل قرش من وين إجا ولوين راح» answerable — for any sum
 * you can name both the account it left and the account it reached.
 *
 * Three rules hold everywhere and are enforced here rather than trusted to
 * callers:
 *
 * 1. **Entries balance.** An unbalanced posting throws before any write.
 * 2. **Nothing is mutated.** Corrections go through `reverse`, which posts a
 *    mirror entry and links it to the original. History stays intact, which is
 *    what an audit (Q65) and a dispute (Q107) both need.
 * 3. **Cached balances move with their lines.** `LedgerAccount.balance` is
 *    updated in the same transaction as the lines that caused it, so it can
 *    never drift; `verifyAccount` re-derives it from the lines to prove so.
 */
@Injectable()
export class LedgerService {
  private readonly logger = new Logger(LedgerService.name);

  constructor(private readonly prisma: PrismaService) {}

  // ── Posting ───────────────────────────────────────────────────────────

  /**
   * Posts a balanced entry. Runs in [tx] when given one, so a caller can make
   * the ledger movement atomic with the business rows that caused it.
   */
  async post(
    input: PostJournalInput,
    tx?: Tx,
  ): Promise<JournalEntryWithLines> {
    this.assertBalanced(input);

    if (tx) return this.postWithin(tx, input);
    return this.prisma.$transaction((inner) => this.postWithin(inner, input));
  }

  private async postWithin(
    tx: Tx,
    input: PostJournalInput,
  ): Promise<JournalEntryWithLines> {
    // Idempotency: the same business event, posted twice, must not double the
    // money. Checked inside the transaction, and backed by the unique index on
    // `reference` for the case where two workers race past this read.
    const existing = await tx.journalEntry.findUnique({
      where: { reference: input.reference },
      include: { lines: { include: { account: true } } },
    });
    if (existing) {
      this.logger.debug(
        `Journal entry ${input.reference} already posted — returning original`,
      );
      return existing as JournalEntryWithLines;
    }

    const accounts = new Map<string, LedgerAccount>();
    for (const line of input.lines) {
      const key = this.accountKey(line.account, line.amount.currency);
      if (!accounts.has(key)) {
        accounts.set(
          key,
          await this.resolveAccount(tx, line.account, line.amount.currency),
        );
      }
    }

    const entry = await tx.journalEntry.create({
      data: {
        type: input.type,
        reference: input.reference,
        description: input.description,
        orderId: input.orderId ?? null,
        sellerOrderId: input.sellerOrderId ?? null,
        createdById: input.createdById ?? null,
        metadata: input.metadata,
        occurredAt: input.occurredAt ?? new Date(),
        lines: {
          create: input.lines.map((line) => ({
            accountId: accounts.get(
              this.accountKey(line.account, line.amount.currency),
            )!.id,
            direction: line.direction,
            amount: line.amount.toPrisma(),
            currency: line.amount.currency,
            memo: line.memo ?? null,
          })),
        },
      },
      include: { lines: { include: { account: true } } },
    });

    // Move the cached balances in the same transaction as the lines.
    for (const line of input.lines) {
      const account = accounts.get(
        this.accountKey(line.account, line.amount.currency),
      )!;
      const delta = this.signedDelta(account, line.direction, line.amount);
      await tx.ledgerAccount.update({
        where: { id: account.id },
        data: { balance: { increment: delta.toPrisma() } },
      });
    }

    return entry as JournalEntryWithLines;
  }

  /**
   * Moves value between two currencies.
   *
   * Ordinary entries balance per currency, which is what stops a conversion
   * being smuggled in as a rounding difference — but it also means a genuine
   * conversion cannot be written as one two-line entry. Settling a seller who
   * priced in USD with cash the platform holds in SYP is a real thing that has
   * to be recordable, so it gets its own shape:
   *
   * ```
   *   DEBIT   seller payable        100 USD
   *   CREDIT  fx adjustment         100 USD     ← USD leg balances
   *   DEBIT   fx adjustment   1,600,000 SYP
   *   CREDIT  platform cash   1,600,000 SYP     ← SYP leg balances
   * ```
   *
   * Both currencies balance against `FX_ADJUSTMENT`, which ends up holding the
   * two legs. Its residual value once the foreign leg is translated at today's
   * rate *is* the platform's accumulated FX gain or loss — see
   * `FxRevaluationService`.
   *
   * The two amounts are checked against the rate before anything is written: a
   * pair that does not reconcile is value being created or destroyed under
   * cover of a conversion, which is the one thing this shape could otherwise
   * hide.
   */
  async postConversion(
    input: PostConversionInput,
    tx?: Tx,
  ): Promise<JournalEntryWithLines> {
    const { debit, credit, rate } = input;

    if (debit.amount.currency === credit.amount.currency) {
      throw new BadRequestException(
        'A conversion needs two different currencies — use post() instead',
      );
    }
    this.assertRateReconciles(debit.amount, credit.amount, rate, input.tolerance);

    const bridge: AccountRef = { code: LedgerAccountCode.FX_ADJUSTMENT };

    return this.post(
      {
        type: input.type,
        reference: input.reference,
        description: input.description,
        orderId: input.orderId,
        sellerOrderId: input.sellerOrderId,
        createdById: input.createdById,
        occurredAt: input.occurredAt,
        metadata: {
          ...(typeof input.metadata === 'object' && input.metadata !== null
            ? (input.metadata as Record<string, unknown>)
            : {}),
          fx_rate: rate.toString(),
          fx_from: debit.amount.toJSON(),
          fx_to: credit.amount.toJSON(),
        } as Prisma.InputJsonValue,
        lines: [
          {
            account: debit.account,
            direction: LedgerDirection.DEBIT,
            amount: debit.amount,
            memo: debit.memo,
          },
          {
            account: bridge,
            direction: LedgerDirection.CREDIT,
            amount: debit.amount,
            memo: `Converted at ${rate.toString()}`,
          },
          {
            account: bridge,
            direction: LedgerDirection.DEBIT,
            amount: credit.amount,
            memo: `Converted at ${rate.toString()}`,
          },
          {
            account: credit.account,
            direction: LedgerDirection.CREDIT,
            amount: credit.amount,
            memo: credit.memo,
          },
        ],
      },
      tx,
    );
  }

  /**
   * Posts the mirror image of an existing entry.
   *
   * Money is never un-spent by deleting a row: the original stays, and a
   * second entry moves the same amounts the other way. A ledger that can be
   * edited is not evidence, and disputes (Q107) turn on exactly this.
   */
  async reverse(
    entryId: string,
    reason: string,
    options: { createdById?: string | null; reference?: string } = {},
    tx?: Tx,
  ): Promise<JournalEntryWithLines> {
    const run = async (inner: Tx) => {
      const original = await inner.journalEntry.findUnique({
        where: { id: entryId },
        include: { lines: { include: { account: true } }, reversedBy: true },
      });
      if (!original) {
        throw new BadRequestException(`Journal entry ${entryId} not found`);
      }
      if (original.reversedBy) {
        throw new BadRequestException(
          `Journal entry ${entryId} was already reversed`,
        );
      }

      const mirrored: PostingLine[] = original.lines.map((line) => ({
        account: {
          code: line.account.code,
          // Whichever foreign key holds this account's owner.
          ownerId: line.account.ownerId ?? line.account.courierId,
        },
        direction:
          line.direction === LedgerDirection.DEBIT
            ? LedgerDirection.CREDIT
            : LedgerDirection.DEBIT,
        amount: Money.of(line.amount, line.currency),
        memo: line.memo ?? undefined,
      }));

      const entry = await this.postWithin(inner, {
        type: JournalEntryType.REVERSAL,
        reference: options.reference ?? `reversal:${entryId}`,
        description: reason,
        lines: mirrored,
        orderId: original.orderId,
        sellerOrderId: original.sellerOrderId,
        createdById: options.createdById ?? null,
        metadata: { reverses: entryId } as Prisma.InputJsonValue,
      });

      await inner.journalEntry.update({
        where: { id: entry.id },
        data: { reversesId: original.id },
      });

      return entry;
    };

    if (tx) return run(tx);
    return this.prisma.$transaction(run);
  }

  // ── Reading ───────────────────────────────────────────────────────────

  /**
   * Current cached balance, in the account's natural direction.
   *
   * Takes an optional transaction so a caller reading balances as part of a
   * larger unit of work sees its own uncommitted writes — without it, a
   * summary built inside a transaction would report the world as it was
   * before that transaction started.
   */
  async balanceOf(
    ref: AccountRef,
    currency: Currency,
    tx?: Tx,
  ): Promise<Money> {
    const account = await (tx ?? this.prisma).ledgerAccount.findUnique({
      where: {
        code_ownerKey_currency: {
          code: ref.code,
          ownerKey: this.ownerKey(ref),
          currency,
        },
      },
    });
    return Money.of(account?.balance ?? 0, currency);
  }

  /**
   * How much has moved through one account, in one direction, for one
   * business subject.
   *
   * A cached balance answers "how much is there now"; this answers "how much
   * of it came from *that*". Escrow release needs exactly that distinction: a
   * seller's escrow account holds the money of every open order she has, so
   * the only way to know how much of one sub-order has already been refunded
   * out of it is to read the lines that took it.
   *
   * Deliberately reads the lines rather than any cached total — the point of
   * the question is to be independent of caches.
   */
  async movementFor(
    query: {
      readonly account: AccountRef;
      readonly currency: Currency;
      readonly direction: LedgerDirection;
      readonly sellerOrderId?: string;
      readonly orderId?: string;
      readonly types?: readonly JournalEntryType[];
    },
    tx?: Tx,
  ): Promise<Money> {
    const db = tx ?? this.prisma;
    const sum = await db.journalLine.aggregate({
      _sum: { amount: true },
      where: {
        direction: query.direction,
        currency: query.currency,
        account: {
          code: query.account.code,
          ownerKey: this.ownerKey(query.account),
          currency: query.currency,
        },
        entry: {
          ...(query.sellerOrderId ? { sellerOrderId: query.sellerOrderId } : {}),
          ...(query.orderId ? { orderId: query.orderId } : {}),
          ...(query.types ? { type: { in: [...query.types] } } : {}),
          // A reversed entry and the mirror that cancels it net to nothing,
          // so neither is counted: summing one without the other would report
          // movement that no longer stands, and summing both would report it
          // twice in opposite directions.
          reversedBy: null,
          reversesId: null,
        },
      },
    });
    return Money.of(sum._sum.amount ?? 0, query.currency);
  }

  /**
   * Re-derives an account's balance from its lines and compares it with the
   * cached value. Used by the reconciliation job and by tests — a mismatch
   * means something wrote a balance outside `post`, which is a bug.
   */
  async verifyAccount(
    accountId: string,
    tx?: Tx,
  ): Promise<{ cached: Money; derived: Money; agrees: boolean }> {
    const db = tx ?? this.prisma;
    const account = await db.ledgerAccount.findUniqueOrThrow({
      where: { id: accountId },
    });

    const sums = await db.journalLine.groupBy({
      by: ['direction'],
      where: { accountId },
      _sum: { amount: true },
    });

    const debit = Money.of(
      sums.find((s) => s.direction === LedgerDirection.DEBIT)?._sum.amount ?? 0,
      account.currency,
    );
    const credit = Money.of(
      sums.find((s) => s.direction === LedgerDirection.CREDIT)?._sum.amount ?? 0,
      account.currency,
    );

    const derived = isDebitNormal(account.kind)
      ? debit.minus(credit)
      : credit.minus(debit);
    const cached = Money.of(account.balance, account.currency);

    return { cached, derived, agrees: cached.equals(derived) };
  }

  /**
   * The trial balance: every account with its debit and credit totals.
   *
   * In a correct double-entry book the two grand totals are equal. If they are
   * not, money has been created or destroyed and the discrepancy is real.
   */
  async trialBalance(currency: Currency, tx?: Tx): Promise<TrialBalance> {
    const db = tx ?? this.prisma;
    const accounts = await db.ledgerAccount.findMany({
      where: { currency },
      orderBy: [{ code: 'asc' }, { ownerId: 'asc' }],
    });

    const sums = await db.journalLine.groupBy({
      by: ['accountId', 'direction'],
      where: { currency },
      _sum: { amount: true },
    });

    const rows: TrialBalanceRow[] = accounts.map((account) => {
      const debit = Money.of(
        sums.find(
          (s) =>
            s.accountId === account.id && s.direction === LedgerDirection.DEBIT,
        )?._sum.amount ?? 0,
        currency,
      );
      const credit = Money.of(
        sums.find(
          (s) =>
            s.accountId === account.id && s.direction === LedgerDirection.CREDIT,
        )?._sum.amount ?? 0,
        currency,
      );
      return {
        accountId: account.id,
        code: account.code,
        kind: account.kind,
        ownerId: account.ownerId,
        label: definitionOf(account.code).label,
        debit,
        credit,
        balance: Money.of(account.balance, currency),
      };
    });

    const totalDebit = Money.sum(
      rows.map((r) => r.debit),
      currency,
    );
    const totalCredit = Money.sum(
      rows.map((r) => r.credit),
      currency,
    );

    return {
      currency,
      rows,
      totalDebit,
      totalCredit,
      balanced: totalDebit.equals(totalCredit),
    };
  }

  // ── Internals ─────────────────────────────────────────────────────────

  /**
   * Rejects a posting that does not balance, before anything is written.
   *
   * Balance is checked *per currency*: a single entry may touch both SYP and
   * USD accounts (an FX revaluation does), but each currency must settle
   * against itself. Cross-currency netting inside one entry would hide a
   * conversion that belongs on `FX_ADJUSTMENT`.
   */
  private assertBalanced(input: PostJournalInput): void {
    if (input.lines.length < 2) {
      throw new BadRequestException(
        'A journal entry needs at least two lines — money always moves between two accounts',
      );
    }

    const byCurrency = new Map<Currency, { debit: Money; credit: Money }>();

    for (const line of input.lines) {
      if (line.amount.isNegative()) {
        throw new BadRequestException(
          'Journal line amounts are unsigned; use direction to express the sign',
        );
      }
      if (line.amount.isZero()) {
        throw new BadRequestException('A journal line cannot be for zero');
      }

      const currency = line.amount.currency;
      const totals =
        byCurrency.get(currency) ??
        { debit: Money.zero(currency), credit: Money.zero(currency) };

      if (line.direction === LedgerDirection.DEBIT) {
        totals.debit = totals.debit.plus(line.amount);
      } else {
        totals.credit = totals.credit.plus(line.amount);
      }
      byCurrency.set(currency, totals);
    }

    for (const [currency, totals] of byCurrency) {
      if (!totals.debit.equals(totals.credit)) {
        throw new BadRequestException(
          `Journal entry "${input.reference}" does not balance in ${currency}: ` +
            `debits ${totals.debit.toString()} vs credits ${totals.credit.toString()}`,
        );
      }
    }
  }

  /**
   * Rejects a conversion whose two amounts do not agree with its own rate.
   *
   * Without this the four-line shape would be a hole in the ledger: both
   * currencies would still balance against the bridge while the amounts said
   * one thing and the rate another, and the difference would appear as an FX
   * result nobody could explain.
   *
   * A tolerance is unavoidable — Q48 rounds SYP to the nearest 1000, so an
   * exactly-converted figure is almost never the figure actually charged. The
   * default admits that rounding and nothing more.
   */
  private assertRateReconciles(
    from: Money,
    to: Money,
    rate: Prisma.Decimal,
    tolerance?: Money,
  ): void {
    if (rate.lessThanOrEqualTo(0)) {
      throw new BadRequestException('A conversion rate must be positive');
    }
    if (from.isZero() || to.isZero()) {
      throw new BadRequestException('A conversion cannot be for zero');
    }

    const expected = from.times(rate).amount;
    const difference = expected.minus(to.amount).abs();

    const allowed =
      tolerance?.amount ?? new Decimal(DEFAULT_CONVERSION_TOLERANCE[to.currency]);

    if (difference.greaterThan(allowed)) {
      throw new BadRequestException(
        `Conversion does not reconcile: ${from.toString()} at ${rate.toString()} ` +
          `is ${expected.toString()}, but the entry says ${to.toString()} ` +
          `(difference ${difference.toString()}, tolerance ${allowed.toString()})`,
      );
    }
  }

  /**
   * Finds the account, creating it on first use.
   *
   * Accounts are created lazily rather than seeded for every user: a customer
   * who never receives a refund never needs a wallet account row, and a chart
   * pre-populated for a hundred thousand users is a hundred thousand rows of
   * zeroes to scan.
   */
  private async resolveAccount(
    tx: Tx,
    ref: AccountRef,
    currency: Currency,
  ): Promise<LedgerAccount> {
    const definition = definitionOf(ref.code);
    const ownerId = this.ownerFor(ref);

    if (definition.perOwner && !ownerId) {
      throw new BadRequestException(
        `Account ${ref.code} is per-owner and requires an ownerId`,
      );
    }
    if (!definition.perOwner && ownerId) {
      throw new BadRequestException(
        `Account ${ref.code} is a platform account and must not carry an ownerId`,
      );
    }

    // Ownership is polymorphic: the chart says which foreign key this code's
    // owner lives behind, so a courier's cash account does not try to point at
    // the users table.
    const isCourierOwned = definition.ownerType === 'COURIER';

    return tx.ledgerAccount.upsert({
      where: {
        code_ownerKey_currency: {
          code: ref.code,
          ownerKey: this.ownerKey(ref),
          currency,
        },
      },
      update: {},
      create: {
        code: ref.code,
        kind: definition.kind,
        ownerId: isCourierOwned ? null : ownerId,
        courierId: isCourierOwned ? ownerId : null,
        ownerKey: this.ownerKey(ref),
        currency,
      },
    });
  }

  /**
   * The change this posting makes to the account's natural balance.
   *
   * A debit raises a debit-normal account and lowers a credit-normal one —
   * this is the only place that rule is applied.
   */
  private signedDelta(
    account: LedgerAccount,
    direction: LedgerDirection,
    amount: Money,
  ): Money {
    const raises =
      direction === LedgerDirection.DEBIT
        ? isDebitNormal(account.kind)
        : !isDebitNormal(account.kind);
    return raises ? amount : amount.negated();
  }

  /**
   * Prisma treats `null` and `undefined` differently in a compound unique
   * lookup; normalising to `null` keeps platform singletons addressable.
   */
  private ownerFor(ref: AccountRef): string | null {
    return ref.ownerId ?? null;
  }

  /**
   * The non-null uniqueness key for an account. Platform singletons share the
   * literal `platform`; party accounts use the owner's uuid. See the comment
   * on `LedgerAccount.ownerKey` for why a plain nullable column will not do.
   */
  private ownerKey(ref: AccountRef): string {
    return this.ownerFor(ref) ?? PLATFORM_OWNER_KEY;
  }

  private accountKey(ref: AccountRef, currency: Currency): string {
    return `${ref.code}:${this.ownerFor(ref) ?? '-'}:${currency}`;
  }
}

export interface TrialBalanceRow {
  accountId: string;
  code: LedgerAccountCode;
  kind: LedgerAccount['kind'];
  ownerId: string | null;
  label: string;
  debit: Money;
  credit: Money;
  balance: Money;
}

export interface TrialBalance {
  currency: Currency;
  rows: TrialBalanceRow[];
  totalDebit: Money;
  totalCredit: Money;
  balanced: boolean;
}

export { Decimal };
