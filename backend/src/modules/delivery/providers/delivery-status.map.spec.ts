import assert from 'node:assert/strict';
import test from 'node:test';
import { DeliveryFailureReason, ShipmentStatus } from '@prisma/client';

import {
  isForwardDeliveryStatus,
  isTerminalDeliveryStatus,
  toCanonicalStatus,
  toFailureReason,
} from './delivery-status.map';

/**
 * The map is the seam between a carrier's vocabulary and the platform's, and
 * everything downstream of a delivery — the return window, escrow, the
 * customer's tracking page — reads the platform's word. A wrong mapping is not
 * a cosmetic bug: mapping the wrong thing to DELIVERED settles money.
 */

test('a carrier word is understood however it is spelled', () => {
  assert.equal(toCanonicalStatus('OUT_FOR_DELIVERY'), ShipmentStatus.OUT_FOR_DELIVERY);
  assert.equal(toCanonicalStatus('out for delivery'), ShipmentStatus.OUT_FOR_DELIVERY);
  assert.equal(toCanonicalStatus('Out-For-Delivery'), ShipmentStatus.OUT_FOR_DELIVERY);
  assert.equal(toCanonicalStatus('picked_up'), ShipmentStatus.PICKED_UP);
  assert.equal(toCanonicalStatus('COLLECTED'), ShipmentStatus.PICKED_UP);
});

test("a carrier's own map wins over the built-in guesses", () => {
  // A carrier whose "completed" means the parcel came back, not that it landed.
  assert.equal(
    toCanonicalStatus('completed', { completed: 'RETURNED' }),
    ShipmentStatus.RETURNED,
  );
  assert.equal(toCanonicalStatus('completed'), ShipmentStatus.DELIVERED);
});

test('an unknown word maps to nothing rather than to a guess', () => {
  // The alternative — falling back to "in transit", say — is how a customer is
  // told her parcel is moving when the carrier said it was lost.
  assert.equal(toCanonicalStatus('quantum_state'), null);
  assert.equal(toCanonicalStatus(''), null);
  assert.equal(toCanonicalStatus(null), null);
});

test('a mapping to something outside the ladder is refused', () => {
  assert.equal(toCanonicalStatus('weird', { weird: 'NOT_A_STATUS' }), null);
});

test('failure reasons land on the list Q37 separates', () => {
  assert.equal(toFailureReason('customer_refused'), DeliveryFailureReason.CUSTOMER_REFUSED);
  assert.equal(toFailureReason('no answer'), DeliveryFailureReason.NO_ANSWER);
  assert.equal(toFailureReason('WRONG_ADDRESS'), DeliveryFailureReason.WRONG_ADDRESS);
  // An unrecognised reason is still a failure — it just is not one of the
  // reasons that decide whether money comes back.
  assert.equal(toFailureReason('van_broke_down'), DeliveryFailureReason.OTHER);
});

test('a parcel never walks backwards', () => {
  assert.equal(
    isForwardDeliveryStatus(ShipmentStatus.OUT_FOR_DELIVERY, ShipmentStatus.PICKED_UP),
    false,
  );
  assert.equal(
    isForwardDeliveryStatus(ShipmentStatus.PICKED_UP, ShipmentStatus.OUT_FOR_DELIVERY),
    true,
  );
});

test('a status we already hold is not a move', () => {
  assert.equal(
    isForwardDeliveryStatus(ShipmentStatus.IN_TRANSIT, ShipmentStatus.IN_TRANSIT),
    false,
  );
});

test('a finished parcel accepts nothing further', () => {
  for (const terminal of [
    ShipmentStatus.DELIVERED,
    ShipmentStatus.RETURNED,
    ShipmentStatus.CANCELLED,
  ]) {
    assert.equal(isTerminalDeliveryStatus(terminal), true);
    assert.equal(
      isForwardDeliveryStatus(terminal, ShipmentStatus.IN_TRANSIT),
      false,
      `${terminal} must not reopen`,
    );
  }
});

test('a failed attempt may be retried', () => {
  // Q37 — a missed attempt is not the end of the parcel, and a carrier that
  // tries again tomorrow must be able to say so.
  assert.equal(
    isForwardDeliveryStatus(ShipmentStatus.FAILED, ShipmentStatus.OUT_FOR_DELIVERY),
    true,
  );
  assert.equal(
    isForwardDeliveryStatus(ShipmentStatus.FAILED, ShipmentStatus.RETURNING),
    true,
  );
});
