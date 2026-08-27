import assert from 'node:assert/strict';
import test from 'node:test';
import {
  Currency,
  JournalEntryType,
  LedgerAccountCode,
  LedgerAccountKind,
  LedgerDirection,
} from '@prisma/client';

import { Money } from '../../common/money';
import { definitionOf, isDebitNormal } from './chart-of-accounts';
import { LedgerService, PostJournalInput, PostingLine } from './ledger.service';

/**
 * The balancing rules are pure, so they are exercised directly on the
 * prototype — no database, no DI container. These are the invariants that make
 * the ledger trustworthy, so they are tested as hard as anything in the
 * codebase.
 */
const service = Object.create(LedgerService.prototype) as {
  assertBalanced(input: PostJournalInput): void;
  signedDelta(
    account: { kind: LedgerAccountKind },
    direction: LedgerDirection,
    amount: Money,
  ): Money;
};

const syp = (value: string) => Money.of(value, Currency.SYP);
const usd = (value: string) => Money.of(value, Currency.USD);

function entry(lines: PostingLine[]): PostJournalInput {
  return {
    type: JournalEntryType.MANUAL_ADJUSTMENT,
    reference: 'test',
    description: 'test',
    lines,
  };
}

const debit = (
  amount: Money,
  code: LedgerAccountCode = LedgerAccountCode.PLATFORM_CASH,
): PostingLine => ({
  account: { code },
  direction: LedgerDirection.DEBIT,
  amount,
});

const credit = (
  amount: Money,
  code: LedgerAccountCode = LedgerAccountCode.COMMISSION_REVENUE,
): PostingLine => ({
  account: { code },
  direction: LedgerDirection.CREDIT,
  amount,
});

// ── Balancing ─────────────────────────────────────────────────────────────

test('a balanced entry is accepted', () => {
  assert.doesNotThrow(() =>
    service.assertBalanced(entry([debit(syp('1000')), credit(syp('1000'))])),
  );
});

test('an unbalanced entry is rejected before anything is written', () => {
  assert.throws(
    () =>
      service.assertBalanced(entry([debit(syp('1000')), credit(syp('999'))])),
    /does not balance/,
  );
});

test('a one-sided entry is rejected — money always moves between two accounts', () => {
  assert.throws(
    () => service.assertBalanced(entry([debit(syp('1000'))])),
    /at least two lines/,
  );
});

test('a zero-amount line is rejected', () => {
  assert.throws(
    () => service.assertBalanced(entry([debit(syp('0')), credit(syp('0'))])),
    /cannot be for zero/,
  );
});

test('a negative line is rejected — direction carries the sign, not the amount', () => {
  assert.throws(
    () =>
      service.assertBalanced(entry([debit(syp('-500')), credit(syp('-500'))])),
    /unsigned/,
  );
});

test('balance is checked per currency, not on a mixed total', () => {
  // SYP and USD each balance against themselves. Were the check done on one
  // combined total, these two currencies could offset each other and hide a
  // conversion that belongs on FX_ADJUSTMENT.
  assert.doesNotThrow(() =>
    service.assertBalanced(
      entry([
        debit(syp('1000')),
        credit(syp('1000')),
        debit(usd('10')),
        credit(usd('10')),
      ]),
    ),
  );

  assert.throws(
    () =>
      service.assertBalanced(
        entry([
          debit(syp('1000')),
          credit(syp('900')),
          debit(usd('10')),
          credit(usd('110')),
        ]),
      ),
    /does not balance in/,
  );
});

test('multi-line entries balance on the sum, not pairwise', () => {
  // One debit split across two credits — a sale settling into seller escrow
  // plus commission revenue.
  assert.doesNotThrow(() =>
    service.assertBalanced(
      entry([
        debit(syp('1000')),
        credit(syp('850'), LedgerAccountCode.SELLER_ESCROW),
        credit(syp('150'), LedgerAccountCode.COMMISSION_REVENUE),
      ]),
    ),
  );
});

// ── Natural balance ───────────────────────────────────────────────────────

test('debits raise assets and expenses, credits lower them', () => {
  for (const kind of [LedgerAccountKind.ASSET, LedgerAccountKind.EXPENSE]) {
    assert.equal(isDebitNormal(kind), true, `${kind} should be debit-normal`);

    const up = service.signedDelta(
      { kind },
      LedgerDirection.DEBIT,
      syp('100'),
    );
    const down = service.signedDelta(
      { kind },
      LedgerDirection.CREDIT,
      syp('100'),
    );
    assert.equal(up.toJSON().amount, '100.0000');
    assert.equal(down.toJSON().amount, '-100.0000');
  }
});

test('credits raise liabilities, equity and revenue, debits lower them', () => {
  for (const kind of [
    LedgerAccountKind.LIABILITY,
    LedgerAccountKind.EQUITY,
    LedgerAccountKind.REVENUE,
  ]) {
    assert.equal(isDebitNormal(kind), false, `${kind} should be credit-normal`);

    const up = service.signedDelta(
      { kind },
      LedgerDirection.CREDIT,
      syp('100'),
    );
    const down = service.signedDelta(
      { kind },
      LedgerDirection.DEBIT,
      syp('100'),
    );
    assert.equal(up.toJSON().amount, '100.0000');
    assert.equal(down.toJSON().amount, '-100.0000');
  }
});

// ── Chart of accounts ─────────────────────────────────────────────────────

test('every account code has a definition', () => {
  for (const code of Object.values(LedgerAccountCode)) {
    const definition = definitionOf(code);
    assert.ok(definition, `${code} has no chart-of-accounts entry`);
    assert.ok(definition.label.length > 0, `${code} has no label`);
  }
});

test('party accounts are per-owner and platform accounts are not', () => {
  // A seller's payable and a customer's wallet only mean anything attached to
  // a person; platform cash is a singleton.
  for (const code of [
    LedgerAccountCode.SELLER_PAYABLE,
    LedgerAccountCode.SELLER_ESCROW,
    LedgerAccountCode.CUSTOMER_WALLET,
    LedgerAccountCode.DISPUTE_HELD,
  ]) {
    assert.equal(definitionOf(code).perOwner, true, `${code} must be per-owner`);
  }

  for (const code of [
    LedgerAccountCode.PLATFORM_CASH,
    LedgerAccountCode.COMMISSION_REVENUE,
    LedgerAccountCode.LOYALTY_LIABILITY,
  ]) {
    assert.equal(
      definitionOf(code).perOwner,
      false,
      `${code} must be a platform singleton`,
    );
  }
});

test('the wallet is a liability — her money, held by us', () => {
  assert.equal(
    definitionOf(LedgerAccountCode.CUSTOMER_WALLET).kind,
    LedgerAccountKind.LIABILITY,
  );
  assert.equal(
    definitionOf(LedgerAccountCode.SELLER_PAYABLE).kind,
    LedgerAccountKind.LIABILITY,
  );
  assert.equal(
    definitionOf(LedgerAccountCode.COMMISSION_REVENUE).kind,
    LedgerAccountKind.REVENUE,
  );
});
