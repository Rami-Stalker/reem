import assert from 'node:assert/strict';
import test from 'node:test';
import { ShipmentStatus } from '@prisma/client';

import { ShipmentsService } from './shipments.service';

/**
 * The transition table is what stops a parcel being delivered twice — and
 * since delivery is what books cash-on-delivery money into a courier's
 * account, delivering twice would invent money. Tested directly on the
 * prototype: no database, no DI.
 */
const service = Object.create(ShipmentsService.prototype) as {
  assertTransition(from: ShipmentStatus, to: ShipmentStatus): void;
  trackingCode(): string;
};

const allows = (from: ShipmentStatus, to: ShipmentStatus) => {
  try {
    service.assertTransition(from, to);
    return true;
  } catch {
    return false;
  }
};

test('a parcel walks the normal path from created to delivered', () => {
  const path: ShipmentStatus[] = [
    ShipmentStatus.CREATED,
    ShipmentStatus.ASSIGNED,
    ShipmentStatus.PICKED_UP,
    ShipmentStatus.OUT_FOR_DELIVERY,
    ShipmentStatus.DELIVERED,
  ];

  for (let i = 0; i < path.length - 1; i += 1) {
    assert.ok(
      allows(path[i], path[i + 1]),
      `${path[i]} → ${path[i + 1]} should be allowed`,
    );
  }
});

test('a delivered parcel is final — it cannot be delivered again', () => {
  // The one that matters most: re-delivering would settle the sub-order twice
  // and double the cash booked against the courier.
  for (const to of Object.values(ShipmentStatus)) {
    assert.equal(
      allows(ShipmentStatus.DELIVERED, to),
      false,
      `DELIVERED → ${to} must be refused`,
    );
  }
});

test('a parcel cannot be delivered before it goes out for delivery', () => {
  for (const from of [
    ShipmentStatus.CREATED,
    ShipmentStatus.ASSIGNED,
    ShipmentStatus.PICKED_UP,
    ShipmentStatus.IN_TRANSIT,
  ]) {
    assert.equal(
      allows(from, ShipmentStatus.DELIVERED),
      false,
      `${from} → DELIVERED must be refused`,
    );
  }
});

test('a failed attempt can be retried or sent back, per Q37', () => {
  // «فشل التسليم — المندوب حاول التسليم ولم يتمكن» is not the end of the road.
  assert.ok(allows(ShipmentStatus.FAILED, ShipmentStatus.OUT_FOR_DELIVERY));
  assert.ok(allows(ShipmentStatus.FAILED, ShipmentStatus.RETURNING));
  assert.equal(allows(ShipmentStatus.FAILED, ShipmentStatus.DELIVERED), false);
});

test('returned and cancelled are terminal', () => {
  for (const from of [ShipmentStatus.RETURNED, ShipmentStatus.CANCELLED]) {
    for (const to of Object.values(ShipmentStatus)) {
      assert.equal(
        allows(from, to),
        false,
        `${from} → ${to} must be refused`,
      );
    }
  }
});

test('a cancelled parcel cannot be resurrected once picked up', () => {
  // Cancelling is only available before the courier has the goods.
  assert.ok(allows(ShipmentStatus.CREATED, ShipmentStatus.CANCELLED));
  assert.ok(allows(ShipmentStatus.ASSIGNED, ShipmentStatus.CANCELLED));
  assert.equal(
    allows(ShipmentStatus.PICKED_UP, ShipmentStatus.CANCELLED),
    false,
  );
});

test('every status has a transition rule', () => {
  // A status missing from the table would throw on lookup rather than refuse
  // cleanly, so the table must cover the enum exhaustively.
  for (const from of Object.values(ShipmentStatus)) {
    assert.doesNotThrow(
      () => allows(from, ShipmentStatus.DELIVERED),
      `${from} has no entry in the transition table`,
    );
  }
});

test('tracking codes avoid characters that get misread down a phone line', () => {
  for (let i = 0; i < 200; i += 1) {
    const code = service.trackingCode();
    assert.match(code, /^REM-[0-9A-HJ-NP-Z]{8}$/);
    assert.equal(code.includes('I'), false, 'I reads as 1');
    assert.equal(code.includes('O'), false, 'O reads as 0');
  }
});

test('tracking codes are not sequential', () => {
  // A guessable code would let anyone read someone else's delivery address.
  const codes = new Set<string>();
  for (let i = 0; i < 500; i += 1) codes.add(service.trackingCode());
  assert.equal(codes.size, 500, 'tracking codes must not collide');
});
