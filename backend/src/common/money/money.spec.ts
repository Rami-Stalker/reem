import assert from 'node:assert/strict';
import test from 'node:test';
import { Currency, RoundingPolicy } from '@prisma/client';
import { Money } from './money';

test('addition does not degrade into string concatenation', () => {
  // The failure this class exists to prevent: `decimalA + decimalB` yields
  // "100200" because Decimal.valueOf() returns a string.
  const sum = Money.of('100', Currency.SYP).plus(Money.of('200', Currency.SYP));

  assert.equal(sum.toJSON().amount, '300.0000');
});

test('mixing currencies is rejected rather than silently summed', () => {
  assert.throws(
    () => Money.of('100', Currency.SYP).plus(Money.of('100', Currency.USD)),
    /Currency mismatch/,
  );
});

test('summing an empty list yields zero in the requested currency', () => {
  const total = Money.sum([], Currency.USD);

  assert.equal(total.isZero(), true);
  assert.equal(total.currency, Currency.USD);
});

test('SYP rounds to the nearest thousand', () => {
  const policy = RoundingPolicy.NEAREST_1000;

  assert.equal(Money.of('124400', Currency.SYP).round(policy).toJSON().amount, '124000.0000');
  assert.equal(Money.of('124500', Currency.SYP).round(policy).toJSON().amount, '125000.0000');
  assert.equal(Money.of('999', Currency.SYP).round(policy).toJSON().amount, '1000.0000');
});

test('allocation across sub-orders never loses or invents a unit', () => {
  // One shipping charge split over three sellers by item weight — the classic
  // place where float maths leaves a stray 0.01 unaccounted for.
  const shipping = Money.of('10000', Currency.SYP);
  const parts = shipping.allocate([1, 1, 1]);

  assert.equal(parts.length, 3);
  const rebuilt = Money.sum(parts, Currency.SYP);
  assert.equal(rebuilt.equals(shipping), true, `expected 10000, got ${rebuilt}`);
});

test('allocation weights the split and still reconciles exactly', () => {
  const discount = Money.of('333.33', Currency.USD);
  const parts = discount.allocate(['50', '30', '20']);

  assert.equal(Money.sum(parts, Currency.USD).equals(discount), true);
  assert.equal(parts[0].greaterThan(parts[1]), true);
  assert.equal(parts[1].greaterThan(parts[2]), true);
});

test('allocation with zero total weight still conserves the amount', () => {
  const parts = Money.of('500', Currency.SYP).allocate([0, 0]);

  assert.equal(Money.sum(parts, Currency.SYP).toJSON().amount, '500.0000');
});

test('commission in basis points is exact', () => {
  // 7.5% of 1,000,000 SYP — the seller-tier commission path (Q18 P1).
  const commission = Money.of('1000000', Currency.SYP).percentBps(750);

  assert.equal(commission.toJSON().amount, '75000.0000');
});

test('conversion requires a positive rate and retags the currency', () => {
  const usd = Money.of('10', Currency.USD);
  const syp = usd.convertTo(Currency.SYP, '13000');

  assert.equal(syp.currency, Currency.SYP);
  assert.equal(syp.toJSON().amount, '130000.0000');
  assert.throws(() => usd.convertTo(Currency.SYP, '0'), /rate must be positive/);
});

test('the wire shape always carries its currency', () => {
  assert.deepEqual(Money.of('1500.5', Currency.SYP).toJSON(), {
    amount: '1500.5000',
    currency: Currency.SYP,
  });
});
