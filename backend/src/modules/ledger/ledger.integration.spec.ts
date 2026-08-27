import assert from 'node:assert/strict';
import test from 'node:test';
import {
  Currency,
  JournalEntryType,
  LedgerAccountCode,
  LedgerDirection,
  Prisma,
  PrismaClient,
  WalletTransactionSource,
} from '@prisma/client';

import { Money } from '../../common/money';
import { PrismaService } from '../../prisma/prisma.service';
import { LedgerService } from './ledger.service';
import { WalletService } from './wallet.service';

/**
 * End-to-end checks against the real database.
 *
 * Every case runs inside a transaction that is deliberately rolled back, so
 * the suite proves the behaviour against real Postgres — the FOR UPDATE lock,
 * the unique indexes, Decimal arithmetic in the column type — while leaving
 * the database exactly as it found it.
 *
 * Skipped automatically when no database is reachable, so `npm test` still
 * runs on a machine without one.
 */
const prisma = new PrismaClient();
const ledger = new LedgerService(prisma as unknown as PrismaService);
const wallets = new WalletService(
  prisma as unknown as PrismaService,
  ledger,
);

let reachable = false;

test.before(async () => {
  try {
    await prisma.$queryRaw`SELECT 1`;
    reachable = true;
  } catch {
    reachable = false;
  }
});

/**
 * A test that needs the database. Skips itself, rather than failing, when
 * none is reachable — so `npm test` still passes on a machine without one.
 */
function dbTest(name: string, body: () => Promise<void>): void {
  test(name, async (t) => {
    if (!reachable) {
      t.skip('no database reachable');
      return;
    }
    await body();
  });
}

/** A sentinel thrown to roll the transaction back once assertions have run. */
class Rollback extends Error {}

/**
 * Runs [body] inside a transaction that always rolls back. Assertion failures
 * propagate; the rollback happens either way.
 */
async function inRolledBackTx(
  body: (tx: Parameters<Parameters<typeof prisma.$transaction>[0]>[0]) => Promise<void>,
): Promise<void> {
  let failure: unknown;
  try {
    await prisma.$transaction(async (tx) => {
      try {
        await body(tx);
      } catch (error) {
        failure = error;
      }
      throw new Rollback();
    });
  } catch (error) {
    if (!(error instanceof Rollback)) throw error;
  }
  if (failure) throw failure;
}

/** A real user row is needed for the per-owner account FKs. */
async function makeUser(
  tx: Parameters<Parameters<typeof prisma.$transaction>[0]>[0],
  suffix: string,
) {
  const unique = `${Date.now()}${Math.floor(Math.random() * 1e6)}${suffix}`;
  return tx.user.create({
    data: {
      name: `ledger-test-${suffix}`,
      username: `ledger_test_${unique}`,
      phone: `+9639${unique.slice(-8)}`,
      passwordHash: 'x',
    },
  });
}

const syp = (value: string) => Money.of(value, Currency.SYP);

// ── Posting ───────────────────────────────────────────────────────────────

dbTest('a sale splits into seller escrow and commission revenue, and balances', async () => {
  await inRolledBackTx(async (tx) => {
    const seller = await makeUser(tx, 's');

    // Platform accounts are singletons shared with every other order the
    // system has ever settled, so this measures the movement rather than an
    // absolute — an absolute assertion here would only pass on an empty
    // database, which is not the state worth testing against.
    const revenueBefore = await ledger.balanceOf(
      { code: LedgerAccountCode.COMMISSION_REVENUE },
      Currency.SYP,
      tx,
    );

    const entry = await ledger.post(
      {
        type: JournalEntryType.COMMISSION_EARNED,
        reference: `test:sale:${seller.id}`,
        description: 'Sale settled',
        lines: [
          {
            account: { code: LedgerAccountCode.PLATFORM_CASH },
            direction: LedgerDirection.DEBIT,
            amount: syp('1000000'),
          },
          {
            account: {
              code: LedgerAccountCode.SELLER_ESCROW,
              ownerId: seller.id,
            },
            direction: LedgerDirection.CREDIT,
            amount: syp('850000'),
          },
          {
            account: { code: LedgerAccountCode.COMMISSION_REVENUE },
            direction: LedgerDirection.CREDIT,
            amount: syp('150000'),
          },
        ],
      },
      tx,
    );

    assert.equal(entry.lines.length, 3);

    // The seller is owed their share…
    const escrow = await tx.ledgerAccount.findFirstOrThrow({
      where: {
        code: LedgerAccountCode.SELLER_ESCROW,
        ownerKey: seller.id,
        currency: Currency.SYP,
      },
    });
    assert.equal(escrow.balance.toString(), '850000');

    // …and the platform booked its commission on top of whatever it already
    // had.
    const revenueAfter = await ledger.balanceOf(
      { code: LedgerAccountCode.COMMISSION_REVENUE },
      Currency.SYP,
      tx,
    );
    assert.equal(
      revenueAfter.minus(revenueBefore).toJSON().amount,
      '150000.0000',
    );
  });
});

dbTest('posting the same reference twice does not double the money', async () => {
  await inRolledBackTx(async (tx) => {
    const seller = await makeUser(tx, 'i');
    const reference = `test:idem:${seller.id}`;

    const input = {
      type: JournalEntryType.COMMISSION_EARNED,
      reference,
      description: 'Retried settlement',
      lines: [
        {
          account: { code: LedgerAccountCode.PLATFORM_CASH },
          direction: LedgerDirection.DEBIT,
          amount: syp('500000'),
        },
        {
          account: {
            code: LedgerAccountCode.SELLER_PAYABLE,
            ownerId: seller.id,
          },
          direction: LedgerDirection.CREDIT,
          amount: syp('500000'),
        },
      ],
    };

    const first = await ledger.post(input, tx);
    const second = await ledger.post(input, tx);

    assert.equal(second.id, first.id, 'retry must return the original entry');

    const payable = await tx.ledgerAccount.findFirstOrThrow({
      where: {
        code: LedgerAccountCode.SELLER_PAYABLE,
        ownerKey: seller.id,
      },
    });
    assert.equal(
      payable.balance.toString(),
      '500000',
      'balance must reflect one posting, not two',
    );
  });
});

dbTest('an unbalanced posting writes nothing at all', async () => {
  await inRolledBackTx(async (tx) => {
    const seller = await makeUser(tx, 'u');
    const reference = `test:bad:${seller.id}`;

    await assert.rejects(
      ledger.post(
        {
          type: JournalEntryType.MANUAL_ADJUSTMENT,
          reference,
          description: 'Broken',
          lines: [
            {
              account: { code: LedgerAccountCode.PLATFORM_CASH },
              direction: LedgerDirection.DEBIT,
              amount: syp('100'),
            },
            {
              account: {
                code: LedgerAccountCode.SELLER_PAYABLE,
                ownerId: seller.id,
              },
              direction: LedgerDirection.CREDIT,
              amount: syp('99'),
            },
          ],
        },
        tx,
      ),
      /does not balance/,
    );

    const entry = await tx.journalEntry.findUnique({ where: { reference } });
    assert.equal(entry, null, 'no entry may survive a rejected posting');
  });
});

// ── Reversal ──────────────────────────────────────────────────────────────

dbTest('reversing an entry restores the balances and keeps both records', async () => {
  await inRolledBackTx(async (tx) => {
    const seller = await makeUser(tx, 'r');

    const original = await ledger.post(
      {
        type: JournalEntryType.COMMISSION_EARNED,
        reference: `test:rev:${seller.id}`,
        description: 'Settled',
        lines: [
          {
            account: { code: LedgerAccountCode.PLATFORM_CASH },
            direction: LedgerDirection.DEBIT,
            amount: syp('300000'),
          },
          {
            account: {
              code: LedgerAccountCode.SELLER_PAYABLE,
              ownerId: seller.id,
            },
            direction: LedgerDirection.CREDIT,
            amount: syp('300000'),
          },
        ],
      },
      tx,
    );

    await ledger.reverse(
      original.id,
      'Order refunded',
      { reference: `test:rev:${seller.id}:back` },
      tx,
    );

    const payable = await tx.ledgerAccount.findFirstOrThrow({
      where: {
        code: LedgerAccountCode.SELLER_PAYABLE,
        ownerKey: seller.id,
      },
    });
    assert.equal(payable.balance.toString(), '0', 'reversal must net to zero');

    // The original is still there — a ledger you can edit is not evidence.
    const kept = await tx.journalEntry.findUnique({
      where: { id: original.id },
    });
    assert.ok(kept, 'the original entry must survive its reversal');
  });
});

dbTest('an entry cannot be reversed twice', async () => {
  await inRolledBackTx(async (tx) => {
    const seller = await makeUser(tx, 'd');

    const original = await ledger.post(
      {
        type: JournalEntryType.COMMISSION_EARNED,
        reference: `test:dbl:${seller.id}`,
        description: 'Settled',
        lines: [
          {
            account: { code: LedgerAccountCode.PLATFORM_CASH },
            direction: LedgerDirection.DEBIT,
            amount: syp('100000'),
          },
          {
            account: {
              code: LedgerAccountCode.SELLER_PAYABLE,
              ownerId: seller.id,
            },
            direction: LedgerDirection.CREDIT,
            amount: syp('100000'),
          },
        ],
      },
      tx,
    );

    await ledger.reverse(
      original.id,
      'first',
      { reference: `test:dbl:${seller.id}:1` },
      tx,
    );

    await assert.rejects(
      ledger.reverse(
        original.id,
        'second',
        { reference: `test:dbl:${seller.id}:2` },
        tx,
      ),
      /already reversed/,
    );
  });
});

// ── Wallet ────────────────────────────────────────────────────────────────

dbTest('a wallet credit raises the balance and writes a statement row', async () => {
  await inRolledBackTx(async (tx) => {
    const customer = await makeUser(tx, 'w');

    const movement = await wallets.credit(
      {
        userId: customer.id,
        amount: syp('50000'),
        source: WalletTransactionSource.CAMPAIGN_GIFT,
        reason: 'هدية ترحيبية',
        reference: `test:wallet:${customer.id}`,
      },
      tx,
    );

    assert.equal(movement.balanceAfter.toString(), '50000');
    assert.equal(movement.amount.toString(), '50000');

    // The same movement exists in the book of record as a liability we owe her.
    const walletAccount = await tx.ledgerAccount.findFirstOrThrow({
      where: {
        code: LedgerAccountCode.CUSTOMER_WALLET,
        ownerKey: customer.id,
      },
    });
    assert.equal(walletAccount.balance.toString(), '50000');
    assert.ok(movement.journalEntryId, 'movement must link to its journal entry');
  });
});

dbTest('spending more than the balance is refused', async () => {
  await inRolledBackTx(async (tx) => {
    const customer = await makeUser(tx, 'o');

    await wallets.credit(
      {
        userId: customer.id,
        amount: syp('10000'),
        source: WalletTransactionSource.CAMPAIGN_GIFT,
        reason: 'gift',
        reference: `test:over:${customer.id}:c`,
      },
      tx,
    );

    await assert.rejects(
      wallets.spend(
        {
          userId: customer.id,
          amount: syp('10001'),
          reason: 'checkout',
          reference: `test:over:${customer.id}:s`,
        },
        tx,
      ),
      /Insufficient wallet balance/,
    );
  });
});

dbTest('a refund credit must name who absorbs it', async () => {
  await inRolledBackTx(async (tx) => {
    const customer = await makeUser(tx, 'f');

    // Q56/Q67 leave the bearer to the case, so the wallet refuses to guess.
    await assert.rejects(
      wallets.credit(
        {
          userId: customer.id,
          amount: syp('25000'),
          source: WalletTransactionSource.RETURN_REFUND,
          reason: 'return',
          reference: `test:refund:${customer.id}`,
        },
        tx,
      ),
      /no default funding account/,
    );
  });
});

dbTest('a refund funded by the seller moves it out of their payable', async () => {
  await inRolledBackTx(async (tx) => {
    const customer = await makeUser(tx, 'c');
    const seller = await makeUser(tx, 'p');

    // The seller has money owing to them…
    await ledger.post(
      {
        type: JournalEntryType.COMMISSION_EARNED,
        reference: `test:fund:${seller.id}:earn`,
        description: 'Settled',
        lines: [
          {
            account: { code: LedgerAccountCode.PLATFORM_CASH },
            direction: LedgerDirection.DEBIT,
            amount: syp('200000'),
          },
          {
            account: {
              code: LedgerAccountCode.SELLER_PAYABLE,
              ownerId: seller.id,
            },
            direction: LedgerDirection.CREDIT,
            amount: syp('200000'),
          },
        ],
      },
      tx,
    );

    // …and a refund for their fault comes out of it.
    await wallets.credit(
      {
        userId: customer.id,
        amount: syp('75000'),
        source: WalletTransactionSource.RETURN_REFUND,
        reason: 'منتج به عيب',
        reference: `test:fund:${customer.id}:refund`,
        fundedBy: {
          code: LedgerAccountCode.SELLER_PAYABLE,
          ownerId: seller.id,
        },
      },
      tx,
    );

    const payable = await tx.ledgerAccount.findFirstOrThrow({
      where: {
        code: LedgerAccountCode.SELLER_PAYABLE,
        ownerKey: seller.id,
      },
    });
    assert.equal(payable.balance.toString(), '125000');

    const wallet = await tx.ledgerAccount.findFirstOrThrow({
      where: {
        code: LedgerAccountCode.CUSTOMER_WALLET,
        ownerKey: customer.id,
      },
    });
    assert.equal(wallet.balance.toString(), '75000');
  });
});

dbTest('a repeated refund reference credits once', async () => {
  await inRolledBackTx(async (tx) => {
    const customer = await makeUser(tx, 'y');
    const reference = `test:once:${customer.id}`;

    const input = {
      userId: customer.id,
      amount: syp('30000'),
      source: WalletTransactionSource.CAMPAIGN_GIFT,
      reason: 'gift',
      reference,
    };

    const first = await wallets.credit(input, tx);
    const second = await wallets.credit(input, tx);

    assert.equal(second.id, first.id);

    const wallet = await tx.wallet.findFirstOrThrow({
      where: { userId: customer.id },
    });
    assert.equal(wallet.balance.toString(), '30000');
  });
});

// ── Cross-currency settlement ─────────────────────────────────────────────

dbTest('paying a USD obligation with SYP cash balances in both currencies', async () => {
  await inRolledBackTx(async (tx) => {
    const seller = await makeUser(tx, 'fx');

    // She priced in USD, so her payable is a USD liability.
    await ledger.post(
      {
        type: JournalEntryType.COMMISSION_EARNED,
        reference: `fx:accrue:${seller.id}`,
        description: 'Settled in USD',
        lines: [
          {
            account: { code: LedgerAccountCode.PLATFORM_CASH },
            direction: LedgerDirection.DEBIT,
            amount: Money.of('100', Currency.USD),
          },
          {
            account: {
              code: LedgerAccountCode.SELLER_PAYABLE,
              ownerId: seller.id,
            },
            direction: LedgerDirection.CREDIT,
            amount: Money.of('100', Currency.USD),
          },
        ],
      },
      tx,
    );

    // Paid out in SYP at 15,000.
    const entry = await ledger.postConversion(
      {
        type: JournalEntryType.PAYOUT_PAID,
        reference: `fx:payout:${seller.id}`,
        description: 'Payout in SYP against a USD payable',
        debit: {
          account: {
            code: LedgerAccountCode.SELLER_PAYABLE,
            ownerId: seller.id,
          },
          amount: Money.of('100', Currency.USD),
        },
        credit: {
          account: { code: LedgerAccountCode.PLATFORM_CASH },
          amount: Money.of('1500000', Currency.SYP),
        },
        rate: new Prisma.Decimal('15000'),
      },
      tx,
    );

    assert.equal(entry.lines.length, 4, 'a conversion has two legs');

    // The USD obligation is gone.
    const payable = await tx.ledgerAccount.findFirstOrThrow({
      where: {
        code: LedgerAccountCode.SELLER_PAYABLE,
        ownerKey: seller.id,
        currency: Currency.USD,
      },
    });
    assert.equal(payable.balance.toString(), '0');

    // SYP cash fell by what was actually paid.
    const sypCash = await tx.ledgerAccount.findFirstOrThrow({
      where: {
        code: LedgerAccountCode.PLATFORM_CASH,
        ownerKey: 'platform',
        currency: Currency.SYP,
      },
    });
    assert.equal(sypCash.balance.toString(), '-1500000');

    // Both legs of the conversion sit in the bridge, one per currency.
    const bridgeUsd = await tx.ledgerAccount.findFirstOrThrow({
      where: {
        code: LedgerAccountCode.FX_ADJUSTMENT,
        ownerKey: 'platform',
        currency: Currency.USD,
      },
    });
    const bridgeSyp = await tx.ledgerAccount.findFirstOrThrow({
      where: {
        code: LedgerAccountCode.FX_ADJUSTMENT,
        ownerKey: 'platform',
        currency: Currency.SYP,
      },
    });
    // FX_ADJUSTMENT is debit-normal: credited in USD, debited in SYP.
    assert.equal(bridgeUsd.balance.toString(), '-100');
    assert.equal(bridgeSyp.balance.toString(), '1500000');
  });
});

dbTest('a conversion whose amounts contradict its rate writes nothing', async () => {
  await inRolledBackTx(async (tx) => {
    const seller = await makeUser(tx, 'fxbad');
    const reference = `fx:bad:${seller.id}`;

    await assert.rejects(
      ledger.postConversion(
        {
          type: JournalEntryType.PAYOUT_PAID,
          reference,
          description: 'Wrong arithmetic',
          debit: {
            account: {
              code: LedgerAccountCode.SELLER_PAYABLE,
              ownerId: seller.id,
            },
            amount: Money.of('100', Currency.USD),
          },
          credit: {
            account: { code: LedgerAccountCode.PLATFORM_CASH },
            // 100,000 SYP more than the rate allows.
            amount: Money.of('1600000', Currency.SYP),
          },
          rate: new Prisma.Decimal('15000'),
        },
        tx,
      ),
      /does not reconcile/,
    );

    const entry = await tx.journalEntry.findUnique({ where: { reference } });
    assert.equal(entry, null, 'nothing may survive a rejected conversion');
  });
});

dbTest('a same-currency conversion is refused', async () => {
  await inRolledBackTx(async (tx) => {
    const seller = await makeUser(tx, 'fxsame');

    await assert.rejects(
      ledger.postConversion(
        {
          type: JournalEntryType.PAYOUT_PAID,
          reference: `fx:same:${seller.id}`,
          description: 'Not a conversion at all',
          debit: {
            account: {
              code: LedgerAccountCode.SELLER_PAYABLE,
              ownerId: seller.id,
            },
            amount: syp('1000'),
          },
          credit: {
            account: { code: LedgerAccountCode.PLATFORM_CASH },
            amount: syp('1000'),
          },
          rate: new Prisma.Decimal('1'),
        },
        tx,
      ),
      /two different currencies/,
    );
  });
});

test.after(async () => {
  await prisma.$disconnect();
});
