import assert from 'node:assert/strict';
import test from 'node:test';

import { MIN_FIT_SAMPLE, normaliseSize, sizeFit } from './size-fit';

/**
 * The size-fit kernel.
 *
 * Like the verdicts, the cases that matter most are the silent ones: a rate
 * shown over three sales is worse than no rate at all.
 */

test('a size below the sample floor reports no rate', () => {
  const [fit] = sizeFit([
    { size: 'M', delivered: MIN_FIT_SAMPLE - 1, returnedForSize: 0 },
  ]);
  assert.equal(fit.keptRate, null);
});

test('the rate is the share of delivered units that stayed', () => {
  const [fit] = sizeFit([{ size: 'M', delivered: 25, returnedForSize: 2 }]);
  assert.equal(fit.keptRate, 0.92);
});

test('every other option of the same size counts as that size', () => {
  // An M in red and an M in navy, written two ways.
  const fits = sizeFit([
    { size: 'M', delivered: 6, returnedForSize: 1 },
    { size: ' m ', delivered: 6, returnedForSize: 0 },
  ]);
  assert.deepEqual(fits, [{ size: 'M', keptRate: 0.92 }]);
});

test('sizes come back in the order a size row reads', () => {
  const fits = sizeFit(
    [
      { size: 'XL', delivered: 1, returnedForSize: 0 },
      { size: '40', delivered: 1, returnedForSize: 0 },
      { size: 'S', delivered: 1, returnedForSize: 0 },
      { size: '38', delivered: 1, returnedForSize: 0 },
      { size: 'M', delivered: 1, returnedForSize: 0 },
      { size: 'ONE SIZE', delivered: 1, returnedForSize: 0 },
    ],
    1,
  );
  assert.deepEqual(
    fits.map((f) => f.size),
    ['S', 'M', 'XL', '38', '40', 'ONE SIZE'],
  );
});

test('more returns than deliveries never make a rate negative', () => {
  const [fit] = sizeFit([{ size: 'L', delivered: 10, returnedForSize: 14 }]);
  assert.equal(fit.keptRate, 0);
});

test('a variant with no size is not a size', () => {
  assert.equal(normaliseSize(undefined), null);
  assert.equal(normaliseSize('  '), null);
  assert.deepEqual(
    sizeFit([{ size: '', delivered: 50, returnedForSize: 0 }]),
    [],
  );
});

test('2XL and XXL are one size', () => {
  assert.equal(normaliseSize('2xl'), 'XXL');
  assert.equal(normaliseSize('3XL'), 'XXXL');
  assert.equal(normaliseSize(42), '42');
});
