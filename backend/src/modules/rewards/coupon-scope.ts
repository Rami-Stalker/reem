import { Coupon } from '@prisma/client';

import { Money } from '../../common/money';

/**
 * What a coupon needs to know about one line to decide whether it applies.
 *
 * Deliberately a structural type rather than a Prisma payload: the cart, a
 * Ohara Rooms purchase plan and the coupon-preview screen all want this answer
 * and none of them holds the same row shape.
 */
export interface ScopedLine {
  readonly sellerId: string;
  readonly productId: string;
  readonly categoryId: string | null;
  /** What this line contributes to the basket, after any per-line pricing. */
  readonly lineTotal: Money;
}

/**
 * Whether a coupon may be spent on this line.
 *
 * The three scopes are **conjunctive**: a code restricted to a seller *and* a
 * category applies only where both hold. Read the other way round, an unset
 * scope is not a restriction — which is why every coupon that existed before
 * these columns did keeps applying to the whole basket exactly as it used to.
 */
export function couponCovers(coupon: Coupon, line: ScopedLine): boolean {
  if (coupon.sellerId && coupon.sellerId !== line.sellerId) return false;
  if (coupon.productId && coupon.productId !== line.productId) return false;
  // Matched on the line's own category rather than its ancestry. Walking a
  // category tree would be a query per line on the checkout path, and a code
  // meant for a whole branch is better expressed as several codes than as a
  // recursive lookup in the middle of taking somebody's money.
  if (coupon.categoryId && coupon.categoryId !== line.categoryId) return false;
  return true;
}

/**
 * The part of the basket a coupon may discount.
 *
 * **This is the number the discount is computed on, and it is the whole point
 * of the change.** Every code used to be evaluated against the basket total,
 * so a code for one dress took its percentage off a basket of five — and a
 * seller-funded code reduced the commission base of every seller in the order,
 * weighted by their share, so boutique B paid for boutique A's promotion
 * without being told.
 */
export function eligibleSubtotal(
  coupon: Coupon,
  lines: readonly ScopedLine[],
  currency: Money,
): Money {
  const covered = lines.filter((line) => couponCovers(coupon, line));
  if (covered.length === 0) return Money.zero(currency.currency);
  return Money.sum(
    covered.map((line) => line.lineTotal),
    currency.currency,
  );
}

/**
 * Each seller's share of the eligible subtotal, in the order given.
 *
 * The allocation weights that checkout uses to split the discount across
 * sub-orders. Weighting by each seller's *whole* subtotal — which is what
 * happened before — spreads a scoped discount onto sellers it does not cover,
 * so the parts no longer describe the discount that was actually given.
 */
export function eligibleBySeller(
  coupon: Coupon,
  lines: readonly ScopedLine[],
  sellerIds: readonly string[],
  currency: Money,
): Money[] {
  return sellerIds.map((sellerId) =>
    eligibleSubtotal(
      coupon,
      lines.filter((line) => line.sellerId === sellerId),
      currency,
    ),
  );
}

/** A human reason a code did not apply, for the message she is shown. */
export function scopeRefusal(coupon: Coupon): string {
  if (coupon.productId) return 'هذا الكوبون يخصّ منتجاً محدداً ليس في سلتك';
  if (coupon.categoryId) return 'هذا الكوبون يخصّ قسماً ليس في سلتك';
  if (coupon.sellerId) return 'هذا الكوبون يخصّ متجراً ليس في سلتك';
  return 'هذا الكوبون لا ينطبق على سلتك';
}
