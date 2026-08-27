import assert from 'node:assert/strict';
import test from 'node:test';
import { FulfilmentMode, ReturnCostBearer, ReturnReason } from '@prisma/client';

import {
  RETURN_WINDOW_DAYS,
  ReturnBlocker,
  blockerFor,
  defaultCostBearer,
  isResaleable,
  requiresEvidence,
  returnWindowClosesAt,
} from './return-policy';

/**
 * The return rules, checked without a database.
 *
 * These are the answers the client gave, not implementation details, so each
 * case below names the question it comes from. If one of them ever has to
 * change, the client changed their mind — which is exactly when you want a
 * test that fails loudly rather than code that quietly still works.
 */

const line = (over: Partial<Parameters<typeof blockerFor>[0]> = {}) => ({
  quantityOrdered: 2,
  quantityClaimed: 0,
  categoryAllowsReturns: true,
  offerAcceptsReturns: true,
  isMadeToOrder: false,
  ...over,
});

const delivered = (daysAgo: number) => {
  const at = new Date();
  at.setDate(at.getDate() - daysAgo);
  return { deliveredAt: at };
};

// ── The window (Q56 P1) ─────────────────────────────────────────────────

test('the window is seven days from delivery', () => {
  const at = new Date('2026-08-01T10:00:00Z');
  const closes = returnWindowClosesAt(at);
  assert.equal(
    (closes.getTime() - at.getTime()) / 86_400_000,
    RETURN_WINDOW_DAYS,
  );
});

test('a parcel delivered eight days ago is out of time', () => {
  assert.equal(
    blockerFor(line(), delivered(8), ReturnReason.DEFECTIVE),
    ReturnBlocker.WindowClosed,
  );
});

test('a parcel delivered six days ago is still in time', () => {
  assert.equal(blockerFor(line(), delivered(6), ReturnReason.DEFECTIVE), null);
});

test('a parcel that never arrived cannot be returned', () => {
  assert.equal(
    blockerFor(line(), { deliveredAt: null }, ReturnReason.CHANGED_MIND),
    ReturnBlocker.NotDelivered,
  );
});

// ── The exclusions are exclusions from *change of mind* ─────────────────

test('a made-to-order piece cannot be sent back by choice', () => {
  assert.equal(
    blockerFor(
      line({ isMadeToOrder: true }),
      delivered(1),
      ReturnReason.CHANGED_MIND,
    ),
    ReturnBlocker.MadeToOrder,
  );
});

test('but a made-to-order piece that arrives faulty comes back', () => {
  assert.equal(
    blockerFor(
      line({ isMadeToOrder: true }),
      delivered(1),
      ReturnReason.DEFECTIVE,
    ),
    null,
  );
});

test('an excluded category refuses a change of mind and accepts a defect', () => {
  const cosmetics = line({ categoryAllowsReturns: false });
  assert.equal(
    blockerFor(cosmetics, delivered(1), ReturnReason.CHANGED_MIND),
    ReturnBlocker.CategoryExcluded,
  );
  assert.equal(
    blockerFor(cosmetics, delivered(1), ReturnReason.NOT_AS_DESCRIBED),
    null,
  );
});

test("a seller's own opt-out only binds a change of mind", () => {
  const refused = line({ offerAcceptsReturns: false });
  assert.equal(
    blockerFor(refused, delivered(1), ReturnReason.SIZE_ISSUE),
    ReturnBlocker.OfferExcluded,
  );
  assert.equal(
    blockerFor(refused, delivered(1), ReturnReason.WRONG_ITEM),
    null,
  );
});

test('a line already fully claimed cannot be claimed again', () => {
  assert.equal(
    blockerFor(
      line({ quantityClaimed: 2 }),
      delivered(1),
      ReturnReason.DEFECTIVE,
    ),
    ReturnBlocker.FullyReturned,
  );
});

test('the window is checked before the exclusions', () => {
  // Both apply; the customer is told the useful one — nothing she could have
  // done about the category matters once the seven days are gone.
  assert.equal(
    blockerFor(
      line({ categoryAllowsReturns: false }),
      delivered(30),
      ReturnReason.CHANGED_MIND,
    ),
    ReturnBlocker.WindowClosed,
  );
});

// ── Who pays the return leg (Q56 P1, Q67 P1) ────────────────────────────

test('the seller bears the leg when the goods were the problem', () => {
  for (const reason of [
    ReturnReason.DEFECTIVE,
    ReturnReason.WRONG_ITEM,
    ReturnReason.NOT_AS_DESCRIBED,
  ]) {
    assert.equal(
      defaultCostBearer(reason, FulfilmentMode.PLATFORM_COURIER),
      ReturnCostBearer.SELLER,
      `${reason} should fall on the seller`,
    );
  }
});

test('the customer bears the leg when she changed her mind', () => {
  assert.equal(
    defaultCostBearer(ReturnReason.CHANGED_MIND, FulfilmentMode.PLATFORM_COURIER),
    ReturnCostBearer.CUSTOMER,
  );
  assert.equal(
    defaultCostBearer(ReturnReason.SIZE_ISSUE, FulfilmentMode.PLATFORM_COURIER),
    ReturnCostBearer.CUSTOMER,
  );
});

test('a fault of carriage follows whoever carried it', () => {
  assert.equal(
    defaultCostBearer(
      ReturnReason.DAMAGED_IN_TRANSIT,
      FulfilmentMode.PLATFORM_COURIER,
    ),
    ReturnCostBearer.PLATFORM,
  );
  assert.equal(
    defaultCostBearer(
      ReturnReason.DAMAGED_IN_TRANSIT,
      FulfilmentMode.SELLER_SHIPS,
    ),
    ReturnCostBearer.SELLER,
  );
});

test('an unexplained return charges nobody by default', () => {
  // Q67 answered «حسب الحالة». A free-text reason carries no fault, and a
  // guess here would be a small silent unfairness nobody ever audits.
  assert.equal(
    defaultCostBearer(ReturnReason.OTHER, FulfilmentMode.PLATFORM_COURIER),
    null,
  );
});

// ── Evidence and restocking ─────────────────────────────────────────────

test('a claim of fault needs a photo; a change of mind does not', () => {
  assert.equal(requiresEvidence(ReturnReason.DEFECTIVE), true);
  assert.equal(requiresEvidence(ReturnReason.DAMAGED_IN_TRANSIT), true);
  assert.equal(requiresEvidence(ReturnReason.CHANGED_MIND), false);
  assert.equal(requiresEvidence(ReturnReason.SIZE_ISSUE), false);
});

test('goods returned unused go back on sale; faulty ones do not', () => {
  assert.equal(isResaleable(ReturnReason.CHANGED_MIND), true);
  assert.equal(isResaleable(ReturnReason.SIZE_ISSUE), true);
  assert.equal(isResaleable(ReturnReason.DEFECTIVE), false);
  assert.equal(isResaleable(ReturnReason.DAMAGED_IN_TRANSIT), false);
});
