import assert from 'node:assert/strict';
import test from 'node:test';
import { OrderStatus, SellerOrderStatus } from '@prisma/client';
import {
  assertTransition,
  canTransition,
  deriveOrderStatus,
  nextStatuses,
} from './order-status';

const S = SellerOrderStatus;

test('a seller cannot skip the courier and mark an order delivered', () => {
  assert.equal(canTransition(S.PREPARING, S.DELIVERED, 'SELLER'), false);
  assert.throws(() => assertTransition(S.PREPARING, S.DELIVERED, 'SELLER'), /Cannot move/);
});

test('the customer may cancel until the parcel is handed over, then not', () => {
  assert.equal(canTransition(S.PREPARING, S.CANCELLED_BY_CUSTOMER, 'CUSTOMER'), true);
  assert.equal(canTransition(S.READY_TO_SHIP, S.CANCELLED_BY_CUSTOMER, 'CUSTOMER'), true);
  assert.equal(canTransition(S.IN_TRANSIT, S.CANCELLED_BY_CUSTOMER, 'CUSTOMER'), false);
});

test('a refunded sub-order is terminal', () => {
  assert.deepEqual(nextStatuses(S.REFUNDED, 'ADMIN'), []);
});

test('a failed delivery can be retried or sent back', () => {
  const options = nextStatuses(S.DELIVERY_FAILED, 'COURIER');

  assert.ok(options.includes(S.IN_TRANSIT));
  assert.ok(options.includes(S.RETURN_IN_TRANSIT));
});

test('admin may intervene but still cannot invent an edge', () => {
  assert.equal(canTransition(S.RETURNED, S.REFUND_PENDING, 'ADMIN'), true);
  assert.equal(canTransition(S.NEW, S.DELIVERED, 'ADMIN'), false);
});

test('parent order reports partial shipment across sellers', () => {
  const derived = deriveOrderStatus([S.IN_TRANSIT, S.PREPARING], { paid: true });

  assert.equal(derived, OrderStatus.PARTIALLY_SHIPPED);
});

test('parent order reports partial delivery across sellers', () => {
  const derived = deriveOrderStatus([S.DELIVERED, S.IN_TRANSIT], { paid: true });

  assert.equal(derived, OrderStatus.PARTIALLY_DELIVERED);
});

test('one seller cancelling does not cancel the whole order', () => {
  const derived = deriveOrderStatus(
    [S.CANCELLED_BY_SELLER, S.PREPARING],
    { paid: true },
  );

  assert.equal(derived, OrderStatus.PARTIALLY_CANCELLED);
});

test('every seller cancelling does cancel the whole order', () => {
  const derived = deriveOrderStatus(
    [S.CANCELLED_BY_SELLER, S.CANCELLED_BY_CUSTOMER],
    { paid: true },
  );

  assert.equal(derived, OrderStatus.CANCELLED);
});

test('an unpaid order stays pending payment', () => {
  assert.equal(
    deriveOrderStatus([S.NEW, S.NEW], { paid: false }),
    OrderStatus.PENDING_PAYMENT,
  );
});

test('all sub-orders settled closes the parent', () => {
  assert.equal(
    deriveOrderStatus([S.REFUNDED, S.EXCHANGED], { paid: true }),
    OrderStatus.CLOSED,
  );
});
