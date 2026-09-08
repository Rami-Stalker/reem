import assert from 'node:assert/strict';
import test from 'node:test';

import { CONTROL, assign, parseVariants } from './assignment';
import { ALPHA, MIN_SUBJECTS, compare } from './significance';

/**
 * The two pieces of an experiment that have to be right before any of it means
 * anything: who lands where, and how much of the difference to believe.
 *
 * Both run without a database, because neither knows one exists.
 */

const evenSplit = [
  { key: CONTROL, weight: 50 },
  { key: 'treatment', weight: 50 },
];

// ── Assignment ───────────────────────────────────────────────────────────────

test('the same woman gets the same arm every time', () => {
  const first = assign('cards', 'user-1', evenSplit);
  for (let i = 0; i < 50; i += 1) {
    assert.equal(assign('cards', 'user-1', evenSplit), first);
  }
});

test('two experiments split the audience differently', () => {
  // If they did not, whoever landed in the treatment arm of one test would
  // land in the treatment arm of every test, and no two results could ever be
  // told apart.
  const subjects = Array.from({ length: 400 }, (_, i) => `user-${i}`);
  const agreements = subjects.filter(
    (subject) =>
      assign('cards', subject, evenSplit) ===
      assign('checkout', subject, evenSplit),
  ).length;

  // Independent 50/50 splits agree about half the time. Anything near total
  // agreement means the experiment key is not in the hash.
  assert.ok(
    agreements > 150 && agreements < 250,
    `two experiments agreed on ${agreements} of 400 subjects`,
  );
});

test('an even split is even', () => {
  const subjects = Array.from({ length: 2000 }, (_, i) => `u${i}`);
  const treated = subjects.filter(
    (subject) => assign('cards', subject, evenSplit) === 'treatment',
  ).length;

  assert.ok(
    treated > 900 && treated < 1100,
    `a 50/50 split put ${treated} of 2000 in treatment`,
  );
});

test('weights are honoured, not just the arm count', () => {
  const split = [
    { key: CONTROL, weight: 90 },
    { key: 'treatment', weight: 10 },
  ];
  const subjects = Array.from({ length: 2000 }, (_, i) => `u${i}`);
  const treated = subjects.filter(
    (subject) => assign('cards', subject, split) === 'treatment',
  ).length;

  assert.ok(
    treated > 150 && treated < 250,
    `a 10% arm took ${treated} of 2000`,
  );
});

test('a zero-weight arm is never served', () => {
  const split = [
    { key: CONTROL, weight: 100 },
    { key: 'dark', weight: 0 },
  ];
  const subjects = Array.from({ length: 500 }, (_, i) => `u${i}`);
  assert.ok(
    subjects.every((subject) => assign('cards', subject, split) === CONTROL),
  );
});

test('nothing usable means the control, never a crash', () => {
  assert.equal(assign('cards', 'user-1', []), CONTROL);
  assert.equal(assign('cards', 'user-1', [{ key: 'x', weight: 0 }]), CONTROL);
});

// ── Validation ───────────────────────────────────────────────────────────────

test('a split without a control is refused', () => {
  assert.equal(
    parseVariants([
      { key: 'a', weight: 50 },
      { key: 'b', weight: 50 },
    ]),
    null,
    'without a control there is nothing to compare the result against',
  );
});

test('a one-armed experiment is refused', () => {
  assert.equal(parseVariants([{ key: CONTROL, weight: 100 }]), null);
});

test('duplicate and malformed arms are refused', () => {
  assert.equal(
    parseVariants([
      { key: CONTROL, weight: 50 },
      { key: CONTROL, weight: 50 },
    ]),
    null,
  );
  assert.equal(
    parseVariants([
      { key: CONTROL, weight: 50 },
      { key: 'b', weight: -1 },
    ]),
    null,
  );
  assert.equal(parseVariants('control'), null);
  assert.equal(parseVariants(null), null);
});

test('a valid split parses to exactly what was given', () => {
  assert.deepEqual(parseVariants(evenSplit), evenSplit);
});

// ── Significance ─────────────────────────────────────────────────────────────

const arm = (subjects: number, conversions: number, key = 'treatment') => ({
  key,
  subjects,
  conversions,
});

test('a thin sample reports no p-value at all', () => {
  const result = compare(arm(40, 4, CONTROL), arm(40, 8));

  assert.equal(result.readable, false);
  assert.equal(result.pValue, null);
  assert.equal(
    result.intervalPoints,
    null,
    'a test read at forty a side reports whatever happened first',
  );
  // The rate and the lift are still shown — they are facts, just not yet
  // evidence.
  assert.ok(result.rate !== null);
  assert.ok(result.liftPoints !== null);
});

test('a real difference on a real sample is readable', () => {
  const result = compare(arm(5000, 250, CONTROL), arm(5000, 400));

  assert.equal(result.readable, true);
  assert.ok(result.pValue !== null && result.pValue < ALPHA);
  assert.ok(result.liftPoints !== null && result.liftPoints > 0);

  const [low, high] = result.intervalPoints!;
  assert.ok(low > 0, 'the whole interval is above zero');
  assert.ok(high > low);
});

test('two identical arms are not called a winner', () => {
  const result = compare(arm(5000, 300, CONTROL), arm(5000, 300));

  assert.equal(result.liftPoints, 0);
  assert.ok(result.pValue !== null && result.pValue > ALPHA);
  const [low, high] = result.intervalPoints!;
  assert.ok(low < 0 && high > 0, 'the interval straddles zero, as it should');
});

test('a large sample with almost no conversions is still not readable', () => {
  // The subject count clears the bar; the cells do not. This is the case a
  // naive "n > 200" check gets wrong.
  const result = compare(arm(10_000, 2, CONTROL), arm(10_000, 4));
  assert.equal(result.readable, false);
  assert.equal(result.pValue, null);
});

test('an arm nobody was exposed to has no rate', () => {
  const result = compare(arm(1000, 100, CONTROL), arm(0, 0));
  assert.equal(result.rate, null);
  assert.equal(result.readable, false);
});

test('the floor is high enough to be inconvenient', () => {
  // Guarding the constant itself: somebody lowering it to make a test "pass"
  // is the failure this whole file exists to prevent.
  assert.ok(
    MIN_SUBJECTS >= 200,
    'a lower floor turns the framework into a machine for confirming hunches',
  );
});
