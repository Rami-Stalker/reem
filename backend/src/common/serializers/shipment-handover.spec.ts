import assert from 'node:assert/strict';
import test from 'node:test';
import { Currency, Shipment, ShipmentStatus } from '@prisma/client';

import { serializeShipment } from './order.serializer';

const shipment = (status: ShipmentStatus): Shipment =>
  ({
    id: 's1',
    trackingCode: 'REM-TEST',
    sellerOrderId: 'so1',
    courierId: null,
    zoneId: null,
    status,
    currency: Currency.SYP,
    codAmount: null,
    collectedAmount: null,
    scheduledFor: null,
    isExpress: false,
    pickedUpAt: null,
    deliveredAt: null,
    proofImageUrl: null,
    recipientNote: null,
    failureReason: null,
    failureNote: null,
    attemptCount: 0,
    maskedPhone: null,
    handoverCode: '4821',
    handoverAttempts: 0,
    handoverVerifiedAt: null,
    createdAt: new Date(),
    updatedAt: new Date(),
  }) as Shipment;

test('the customer sees her handover code while the parcel is on its way', () => {
  const view = serializeShipment(shipment(ShipmentStatus.OUT_FOR_DELIVERY), { forCustomer: true });
  assert.equal(view.handover_code, '4821');
});

test('nobody else is ever shown the code', () => {
  assert.equal(serializeShipment(shipment(ShipmentStatus.OUT_FOR_DELIVERY)).handover_code, null);
});

test('the code disappears once the parcel is closed', () => {
  const view = serializeShipment(shipment(ShipmentStatus.DELIVERED), { forCustomer: true });
  assert.equal(view.handover_code, null);
});
