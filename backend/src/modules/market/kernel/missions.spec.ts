import assert from 'node:assert/strict';
import test from 'node:test';

import { Criteria, isWorthOffering, rankOffers, readProgress } from './missions';

/**
 * Missions.
 *
 * The tests are almost all about withholding a mission. Offering a good one is
 * easy; the discipline is in never offering one she cannot finish, one she has
 * already finished, or one that asks for something she has no occasion to do.
 */

const criteria = (over: Partial<Criteria> = {}): Criteria => ({
  type: 'REVIEW_PURCHASES',
  target: 3,
  ...over,
});

test('progress is a share of the target, not a running total', () => {
  const reading = readProgress(criteria(), { done: 1, possible: 5 });
  assert.equal(reading.progress, 0.33);
  assert.equal(reading.remaining, 2);
  assert.equal(reading.complete, false);
});

test('progress measures what she did since being asked', () => {
  // She had written four reviews before the mission existed. It must arrive
  // empty, not two-thirds finished.
  const fresh = readProgress(criteria(), { done: 4, possible: 5, baseline: 4 });
  assert.equal(fresh.progress, 0);
  assert.equal(fresh.remaining, 3);

  const after = readProgress(criteria(), { done: 6, possible: 3, baseline: 4 });
  assert.equal(after.progress, 0.67, 'two of three written since the ask');
});

test('a history-heavy shopper is still offered the mission', () => {
  // Without the baseline this would read as already complete and never appear.
  assert.ok(
    isWorthOffering(criteria(), { done: 40, possible: 5, baseline: 40 }),
    'past contributions must not disqualify her from being asked',
  );
});

test('progress cannot exceed one', () => {
  const reading = readProgress(criteria(), { done: 9, possible: 9 });
  assert.equal(reading.progress, 1);
  assert.equal(reading.remaining, 0);
  assert.ok(reading.complete);
});

test('a mission she has no way to finish is never offered', () => {
  // Two reviews left, one unreviewed delivery in existence.
  assert.equal(
    isWorthOffering(criteria(), { done: 1, possible: 1 }),
    false,
    'asking for what does not exist is how this feature becomes noise',
  );
});

test('a mission she can just finish is offered', () => {
  assert.ok(isWorthOffering(criteria(), { done: 1, possible: 2 }));
});

test('an already-finished mission is not offered as an achievement', () => {
  assert.equal(isWorthOffering(criteria(), { done: 3, possible: 4 }), false);
});

test('nothing to do at all means nothing offered', () => {
  assert.equal(isWorthOffering(criteria(), { done: 0, possible: 0 }), false);
});

test('the nearly-finished mission comes first', () => {
  const ranked = rankOffers([
    { id: 'fresh', criteria: criteria({ target: 5 }), evidence: { done: 0, possible: 9 } },
    { id: 'nearly', criteria: criteria({ target: 3 }), evidence: { done: 2, possible: 4 } },
  ] as Array<{ id: string; criteria: Criteria; evidence: { done: number; possible: number } }>);

  assert.equal(ranked[0].id, 'nearly');
});

test('a zero target cannot divide by zero', () => {
  const reading = readProgress(criteria({ target: 0 }), { done: 0, possible: 3 });
  assert.equal(reading.progress, 0);
  assert.ok(Number.isFinite(reading.progress));
});
