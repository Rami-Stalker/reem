import assert from 'node:assert/strict';
import test from 'node:test';
import { Currency, Prisma } from '@prisma/client';

import { Money } from '../../common/money';
import { LedgerService } from './ledger.service';

const Decimal = Prisma.Decimal;

/**
 * The rate-reconciliation guard.
 *
 * `postConversion` is the one entry shape that legitimately mixes currencies,
 * which makes it the one place value could be created without either currency
 * looking unbalanced. This check is what closes that hole, so it is tested on
 * its own.
 */
const service = Object.create(LedgerService.prototype) as {
  assertRateReconciles(
    from: Money,
    to: Money,
    rate: Prisma.Decimal,
    tolerance?: Money,
  ): void;
};

const usd = (v: string) => Money.of(v, Currency.USD);
const syp = (v: string) => Money.of(v, Currency.SYP);
const rate = (v: string) => new Decimal(v);

test('a conversion that matches its rate is accepted', () => {
  // $100 at 15,000 is 1,500,000 SYP.
  assert.doesNotThrow(() =>
    service.assertRateReconciles(usd('100'), syp('1500000'), rate('15000')),
  );
});

test('rounding to the nearest 1000 SYP is within tolerance', () => {
  // Q48 rounds what is charged, so the exact arithmetic almost never matches.
  // $100.03 at 15,000 is 1,500,450 — charged as 1,500,000.
  assert.doesNotThrow(() =>
    service.assertRateReconciles(usd('100.03'), syp('1500000'), rate('15000')),
  );
});

test('a conversion that does not match its rate is rejected', () => {
  // The hole this guard exists to close: both currencies would still balance
  // against the bridge while 100,000 SYP appeared from nowhere.
  assert.throws(
    () =>
      service.assertRateReconciles(usd('100'), syp('1600000'), rate('15000')),
    /does not reconcile/,
  );
});

test('a rate of zero or less is rejected', () => {
  for (const bad of ['0', '-15000']) {
    assert.throws(
      () => service.assertRateReconciles(usd('100'), syp('1500000'), rate(bad)),
      /must be positive/,
    );
  }
});

test('a zero-amount conversion is rejected on either side', () => {
  assert.throws(
    () => service.assertRateReconciles(usd('0'), syp('1500000'), rate('15000')),
    /cannot be for zero/,
  );
  assert.throws(
    () => service.assertRateReconciles(usd('100'), syp('0'), rate('15000')),
    /cannot be for zero/,
  );
});

test('a caller may widen the tolerance deliberately', () => {
  // Rejected at the default…
  assert.throws(
    () =>
      service.assertRateReconciles(usd('100'), syp('1505000'), rate('15000')),
    /does not reconcile/,
  );
  // …accepted when the caller states it knows the difference is larger.
  assert.doesNotThrow(() =>
    service.assertRateReconciles(
      usd('100'),
      syp('1505000'),
      rate('15000'),
      syp('5000'),
    ),
  );
});

test('the tolerance is not a licence for a wrong rate', () => {
  // Half a percent on a big number dwarfs the rounding step, so it fails
  // however the arithmetic is dressed up.
  assert.throws(
    () =>
      service.assertRateReconciles(
        usd('10000'),
        syp('150750000'),
        rate('15000'),
      ),
    /does not reconcile/,
  );
});

test('converting the other way round reconciles too', () => {
  // SYP → USD at 1/15000.
  assert.doesNotThrow(() =>
    service.assertRateReconciles(
      syp('1500000'),
      usd('100'),
      rate('0.00006666666666666667'),
      usd('0.01'),
    ),
  );
});
