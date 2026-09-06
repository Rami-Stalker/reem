import assert from 'node:assert/strict';
import test from 'node:test';

import {
  CandidateSignals,
  DropShape,
  MIN_AFFINITY,
  measureDrop,
  selectAudience,
} from './drop-audience';

/**
 * Drop targeting.
 *
 * The tests that matter are about *not* inviting people. A drop that reaches
 * everybody is the blast this feature exists to replace, and a notification
 * nobody wanted is the fastest way to lose the right to send one.
 */

const drop: DropShape = {
  slots: ['BAG'],
  occasions: ['wedding'],
  sellerIds: ['s1'],
  productCount: 4,
};

const shopper = (over: Partial<CandidateSignals> = {}): CandidateSignals => ({
  userId: 'u1',
  needsSlots: [],
  occasions: [],
  sellerIds: [],
  tasteMatches: 0,
  searchHits: 0,
  ...over,
});

// ── Restraint ────────────────────────────────────────────────────────────

test('a shopper with no relationship to the drop is not invited', () => {
  assert.deepEqual(selectAudience(drop, [shopper()]), []);
});

test('one weak signal alone is below the floor', () => {
  // Having once bought from the seller is not a reason to interrupt her.
  const customer = shopper({ sellerIds: ['s1'] });
  const chosen = selectAudience(drop, [customer]);
  assert.deepEqual(chosen, [], `weak signals must not clear ${MIN_AFFINITY}`);
});

test('an open need alone is enough, and leads', () => {
  // The only signal that describes something she is missing rather than
  // something she likes.
  const needs = shopper({ needsSlots: ['BAG'] });
  const [invite] = selectAudience(drop, [needs]);

  assert.ok(invite);
  assert.equal(invite.reasons[0].code, 'OPEN_NEED');
  assert.ok(invite.affinity >= MIN_AFFINITY);
});

test('weak signals can add up to a real match', () => {
  const several = shopper({
    occasions: ['wedding'],
    sellerIds: ['s1'],
    tasteMatches: 3,
  });
  const [invite] = selectAudience(drop, [several]);
  assert.ok(invite, 'occasion plus taste plus custom is a real match');
  assert.equal(invite.reasons.length, 3);
});

test('the strongest match is invited first', () => {
  const chosen = selectAudience(drop, [
    shopper({ userId: 'weak', occasions: ['wedding'], tasteMatches: 3 }),
    shopper({ userId: 'strong', needsSlots: ['BAG'], occasions: ['wedding'] }),
  ]);

  assert.equal(chosen[0].userId, 'strong');
  assert.ok(chosen[0].affinity > chosen[1].affinity);
});

test('a drop for a different slot does not reach her', () => {
  const needsShoes = shopper({ needsSlots: ['SHOES'] });
  assert.deepEqual(selectAudience(drop, [needsShoes]), []);
});

test('every invitation says why', () => {
  const chosen = selectAudience(drop, [
    shopper({ needsSlots: ['BAG'], searchHits: 2, occasions: ['wedding'] }),
  ]);
  for (const invite of chosen) {
    assert.ok(invite.reasons.length > 0, 'an unexplained invitation is a blast');
    for (const reason of invite.reasons) {
      assert.ok(reason.weight > 0);
    }
  }
});

test('repeated searching saturates', () => {
  const three = selectAudience(drop, [shopper({ userId: 'a', searchHits: 3, needsSlots: ['BAG'] })]);
  const thirty = selectAudience(drop, [shopper({ userId: 'b', searchHits: 30, needsSlots: ['BAG'] })]);
  assert.equal(
    three[0].affinity,
    thirty[0].affinity,
    'thirty searches is not ten times three',
  );
});

test('the audience is capped', () => {
  const many = Array.from({ length: 50 }, (_, i) =>
    shopper({ userId: `u${i}`, needsSlots: ['BAG'] }),
  );
  assert.equal(selectAudience(drop, many, { limit: 10 }).length, 10);
});

// ── Measurement ──────────────────────────────────────────────────────────

const at = (d: string) => new Date(d);

test('a drop nobody opened reports zero precision, not a crash', () => {
  const performance = measureDrop([
    { affinity: 80, notifiedAt: at('2026-01-01'), openedAt: null, convertedAt: null },
    { affinity: 60, notifiedAt: at('2026-01-01'), openedAt: null, convertedAt: null },
  ]);
  assert.equal(performance.precision, 0);
  assert.equal(performance.conversion, 0);
  assert.equal(performance.affinityLift, null, 'no buyers, no comparison');
});

test('precision is opens over notified, not over invited', () => {
  // Inviting a thousand and notifying ten should not read as 0.1% precision.
  const performance = measureDrop([
    { affinity: 90, notifiedAt: at('2026-01-01'), openedAt: at('2026-01-02'), convertedAt: null },
    { affinity: 70, notifiedAt: at('2026-01-01'), openedAt: null, convertedAt: null },
    { affinity: 50, notifiedAt: null, openedAt: null, convertedAt: null },
  ]);
  assert.equal(performance.invited, 3);
  assert.equal(performance.notified, 2);
  assert.equal(performance.precision, 0.5);
});

test('affinity lift shows whether the targeting actually worked', () => {
  // The women the graph rated highest are the ones who bought.
  const working = measureDrop([
    { affinity: 95, notifiedAt: at('2026-01-01'), openedAt: at('2026-01-02'), convertedAt: at('2026-01-02') },
    { affinity: 35, notifiedAt: at('2026-01-01'), openedAt: at('2026-01-02'), convertedAt: null },
  ]);
  assert.ok((working.affinityLift ?? 0) > 0);

  // And when it is the low-affinity women buying, the number says so.
  const backwards = measureDrop([
    { affinity: 35, notifiedAt: at('2026-01-01'), openedAt: at('2026-01-02'), convertedAt: at('2026-01-02') },
    { affinity: 95, notifiedAt: at('2026-01-01'), openedAt: at('2026-01-02'), convertedAt: null },
  ]);
  assert.ok((backwards.affinityLift ?? 0) < 0, 'a negative lift is a real finding');
});
