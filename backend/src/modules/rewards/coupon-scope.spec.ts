import assert from 'node:assert/strict';
import test from 'node:test';
import { Coupon, Currency, CouponType } from '@prisma/client';

import { Money } from '../../common/money';
import {
  ScopedLine,
  couponCovers,
  eligibleBySeller,
  eligibleSubtotal,
} from './coupon-scope';

/**
 * What a coupon may be spent on.
 *
 * Every code used to apply to the whole basket, and `funded_by_seller` said a
 * seller paid for it without saying which seller's goods it covered. Checkout
 * then reduced the commission base of *every* seller in the order, weighted by
 * their share — so a boutique paid part of a rival's promotion and there was
 * nothing in the data that would have let her notice.
 */
const syp = (value: string | number) => Money.of(String(value), Currency.SYP);

function coupon(scope: Partial<Coupon> = {}): Coupon {
  return {
    id: 'c1',
    code: 'TEST',
    title: 'اختبار',
    type: CouponType.PERCENTAGE,
    currency: Currency.SYP,
    discountPercent: { toString: () => '10' },
    amountOff: null,
    minOrderAmount: null,
    maxUses: null,
    usedCount: 0,
    perUserLimit: null,
    userId: null,
    expiresAt: new Date(Date.now() + 86_400_000),
    isActive: true,
    fundedBySeller: false,
    sellerId: null,
    categoryId: null,
    productId: null,
    createdAt: new Date(),
    updatedAt: new Date(),
    ...scope,
  } as unknown as Coupon;
}

const line = (over: Partial<ScopedLine> = {}): ScopedLine => ({
  sellerId: 'seller-a',
  productId: 'product-1',
  categoryId: 'cat-dresses',
  lineTotal: syp(100_000),
  ...over,
});

// ── Coverage ─────────────────────────────────────────────────────────────

test('an unscoped coupon covers everything, exactly as before', () => {
  assert.equal(couponCovers(coupon(), line()), true);
  assert.equal(
    couponCovers(coupon(), line({ sellerId: 'seller-z', productId: 'p-9' })),
    true,
    'nothing that existed before these columns changes behaviour',
  );
});

test('a seller-scoped coupon covers only that seller', () => {
  const code = coupon({ sellerId: 'seller-a' });
  assert.equal(couponCovers(code, line({ sellerId: 'seller-a' })), true);
  assert.equal(couponCovers(code, line({ sellerId: 'seller-b' })), false);
});

test('scopes narrow together rather than widening', () => {
  const code = coupon({ sellerId: 'seller-a', categoryId: 'cat-dresses' });
  assert.equal(couponCovers(code, line()), true);
  assert.equal(
    couponCovers(code, line({ categoryId: 'cat-shoes' })),
    false,
    'her seller matches but the category does not, so it does not apply',
  );
  assert.equal(couponCovers(code, line({ sellerId: 'seller-b' })), false);
});

test('a line with no category cannot match a category scope', () => {
  assert.equal(
    couponCovers(coupon({ categoryId: 'cat-dresses' }), line({ categoryId: null })),
    false,
  );
});

// ── The discount base ────────────────────────────────────────────────────

test('a scoped coupon discounts its own lines, not the basket', () => {
  const basket = [
    line({ sellerId: 'seller-a', lineTotal: syp(100_000) }),
    line({ sellerId: 'seller-b', lineTotal: syp(400_000) }),
  ];

  const eligible = eligibleSubtotal(
    coupon({ sellerId: 'seller-a' }),
    basket,
    syp(0),
  );
  assert.equal(
    eligible.toString(),
    syp(100_000).toString(),
    'ten per cent of one dress, not ten per cent of five',
  );
});

test('an unscoped coupon still sees the whole basket', () => {
  const basket = [
    line({ sellerId: 'seller-a', lineTotal: syp(100_000) }),
    line({ sellerId: 'seller-b', lineTotal: syp(400_000) }),
  ];
  assert.equal(
    eligibleSubtotal(coupon(), basket, syp(0)).toString(),
    syp(500_000).toString(),
  );
});

test('a coupon covering nothing in the basket is worth nothing', () => {
  const basket = [line({ sellerId: 'seller-a' })];
  assert.equal(
    eligibleSubtotal(coupon({ sellerId: 'seller-z' }), basket, syp(0)).toString(),
    syp(0).toString(),
  );
});

// ── The allocation across sellers ────────────────────────────────────────

test("a seller's coupon lands on her parcel and nobody else's", () => {
  const basket = [
    line({ sellerId: 'seller-a', lineTotal: syp(100_000) }),
    line({ sellerId: 'seller-b', lineTotal: syp(400_000) }),
  ];

  const weights = eligibleBySeller(
    coupon({ sellerId: 'seller-a', fundedBySeller: true }),
    basket,
    ['seller-a', 'seller-b'],
    syp(0),
  );

  assert.equal(weights[0].toString(), syp(100_000).toString());
  assert.equal(
    weights[1].toString(),
    syp(0).toString(),
    'seller B funds none of seller A\'s promotion — the bug this closes',
  );
});

test('an unscoped coupon still splits by basket share', () => {
  const basket = [
    line({ sellerId: 'seller-a', lineTotal: syp(100_000) }),
    line({ sellerId: 'seller-b', lineTotal: syp(400_000) }),
  ];

  const weights = eligibleBySeller(coupon(), basket, ['seller-a', 'seller-b'], syp(0));
  assert.equal(weights[0].toString(), syp(100_000).toString());
  assert.equal(weights[1].toString(), syp(400_000).toString());
});

test('a product-scoped coupon reaches one line of one parcel', () => {
  const basket = [
    line({ sellerId: 'seller-a', productId: 'p-1', lineTotal: syp(60_000) }),
    line({ sellerId: 'seller-a', productId: 'p-2', lineTotal: syp(90_000) }),
    line({ sellerId: 'seller-b', productId: 'p-1', lineTotal: syp(70_000) }),
  ];

  // The product, wherever it is sold — a platform code for one item.
  const weights = eligibleBySeller(
    coupon({ productId: 'p-1' }),
    basket,
    ['seller-a', 'seller-b'],
    syp(0),
  );
  assert.equal(weights[0].toString(), syp(60_000).toString());
  assert.equal(weights[1].toString(), syp(70_000).toString());

  // And narrowed to one boutique's copy of it.
  const narrowed = eligibleBySeller(
    coupon({ productId: 'p-1', sellerId: 'seller-a' }),
    basket,
    ['seller-a', 'seller-b'],
    syp(0),
  );
  assert.equal(narrowed[0].toString(), syp(60_000).toString());
  assert.equal(narrowed[1].toString(), syp(0).toString());
});
