import assert from 'node:assert/strict';
import test from 'node:test';
import { FulfilmentMode } from '@prisma/client';

import { fulfilmentModeFor } from './fulfilment-routing';

const on = (governorates: string[] = [], cities: string[] = []) => ({
  selfDeliveryEnabled: true,
  selfDeliveryGovernorates: governorates,
  selfDeliveryCities: cities,
});

test('no settings, or self-delivery off, goes to the carriers', () => {
  assert.equal(fulfilmentModeFor(null, { governorate: 'دمشق' }), FulfilmentMode.PLATFORM_COURIER);
  assert.equal(
    fulfilmentModeFor({ ...on(), selfDeliveryEnabled: false }, { governorate: 'دمشق' }),
    FulfilmentMode.PLATFORM_COURIER,
  );
});

test('self-delivery with no area means she carries everything', () => {
  assert.equal(fulfilmentModeFor(on(), { governorate: 'حلب' }), FulfilmentMode.SELLER_SHIPS);
});

test('inside her governorate she carries it, outside the carrier does', () => {
  const settings = on(['دمشق', 'ريف دمشق']);
  assert.equal(fulfilmentModeFor(settings, { governorate: 'دمشق' }), FulfilmentMode.SELLER_SHIPS);
  assert.equal(fulfilmentModeFor(settings, { governorate: 'حلب' }), FulfilmentMode.PLATFORM_COURIER);
});

test('a city list narrows the area, forgiving spelling variants', () => {
  const settings = on(['ريف دمشق'], ['جرمانا']);
  assert.equal(
    fulfilmentModeFor(settings, { governorate: 'ريف  دمشق', city: 'جرمانا ' }),
    FulfilmentMode.SELLER_SHIPS,
  );
  assert.equal(
    fulfilmentModeFor(settings, { governorate: 'ريف دمشق', city: 'دوما' }),
    FulfilmentMode.PLATFORM_COURIER,
  );
  assert.equal(
    fulfilmentModeFor(on([], ['اللاذقية']), { governorate: 'اللاذقيه', city: 'اللاذقيه' }),
    FulfilmentMode.SELLER_SHIPS,
  );
});
