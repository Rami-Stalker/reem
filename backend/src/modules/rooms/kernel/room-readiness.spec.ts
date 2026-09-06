import assert from 'node:assert/strict';
import test from 'node:test';
import { RoomCandidateStatus, RoomDecisionStatus } from '@prisma/client';
import {
  CandidateFacts,
  DecisionFacts,
  budgetFit,
  consensusFor,
  decisionState,
  roomReadiness,
} from './room-readiness';

/**
 * The kernel is pure, so it is tested with rooms written by hand. Every case
 * below is a situation a cart cannot represent — which is the point of the
 * feature, so it is the point of the tests.
 */

let seq = 0;
function candidate(overrides: Partial<CandidateFacts> = {}): CandidateFacts {
  return {
    id: `c${(seq += 1)}`,
    status: RoomCandidateStatus.CANDIDATE,
    quantity: 1,
    votesUp: 0,
    votesDown: 0,
    voteScore: 0,
    unitPriceSyp: 100_000,
    purchasable: true,
    ...overrides,
  };
}

function decision(overrides: Partial<DecisionFacts> = {}): DecisionFacts {
  return {
    id: `d${(seq += 1)}`,
    title: 'الفستان',
    status: RoomDecisionStatus.OPEN,
    pickCount: 1,
    isRequired: true,
    isSuggested: false,
    candidates: [],
    ...overrides,
  };
}

// ── A decision is not a cart line ───────────────────────────────────────

test('three candidates for one decision is an unmade decision, not three purchases', () => {
  const state = decisionState(
    decision({ candidates: [candidate(), candidate(), candidate()] }),
  );

  assert.equal(state.chosen.length, 0);
  assert.equal(state.remaining, 1);
  assert.equal(state.settled, false);
  assert.equal(state.blockers[0].code, 'DECISION_UNRESOLVED');
});

test('choosing one of three resolves it, and the others are not bought', () => {
  const state = decisionState(
    decision({
      status: RoomDecisionStatus.RESOLVED,
      candidates: [
        candidate({ status: RoomCandidateStatus.CHOSEN }),
        candidate({ status: RoomCandidateStatus.REJECTED }),
        candidate(),
      ],
    }),
  );

  assert.equal(state.chosen.length, 1);
  assert.equal(state.settled, true);
  assert.deepEqual(state.blockers, []);
});

test('a decision that wants two is not settled by one', () => {
  const state = decisionState(
    decision({
      pickCount: 2,
      status: RoomDecisionStatus.RESOLVED,
      candidates: [candidate({ status: RoomCandidateStatus.CHOSEN }), candidate()],
    }),
  );

  assert.equal(state.remaining, 1);
  assert.equal(state.settled, false);
});

test('choosing more than the decision asked for is a blocker, not a bigger basket', () => {
  const state = decisionState(
    decision({
      pickCount: 1,
      status: RoomDecisionStatus.RESOLVED,
      candidates: [
        candidate({ status: RoomCandidateStatus.CHOSEN }),
        candidate({ status: RoomCandidateStatus.CHOSEN }),
      ],
    }),
  );

  assert.equal(state.blockers[0].code, 'OVER_PICK_COUNT');
  assert.equal(state.settled, false);
});

test('deciding to buy nothing is a real outcome', () => {
  const state = decisionState(
    decision({ status: RoomDecisionStatus.SKIPPED, candidates: [candidate()] }),
  );

  assert.equal(state.settled, true);
  assert.deepEqual(state.blockers, []);
});

test('a chosen piece that sold out blocks the room, not the payment screen', () => {
  const state = decisionState(
    decision({
      status: RoomDecisionStatus.RESOLVED,
      candidates: [
        candidate({ status: RoomCandidateStatus.CHOSEN, purchasable: false }),
      ],
    }),
  );

  assert.ok(state.blockers.some((b) => b.code === 'CHOSEN_UNAVAILABLE'));
});

// ── Readiness ───────────────────────────────────────────────────────────

test('an empty room is not ready, and says why', () => {
  const readiness = roomReadiness([]);
  assert.equal(readiness.ready, false);
  assert.equal(readiness.blockers[0].code, 'NO_DECISIONS');
});

test('an optional decision never holds the room back', () => {
  const readiness = roomReadiness([
    decision({
      status: RoomDecisionStatus.RESOLVED,
      candidates: [candidate({ status: RoomCandidateStatus.CHOSEN })],
    }),
    decision({ title: 'حقيبة', isRequired: false, candidates: [candidate()] }),
  ]);

  assert.equal(readiness.ready, true, 'a nice-to-have must not block the dress');
  assert.equal(readiness.totalRequired, 1);
});

test('a decision the room suggested and she ignored never blocks either', () => {
  const readiness = roomReadiness([
    decision({
      status: RoomDecisionStatus.RESOLVED,
      candidates: [candidate({ status: RoomCandidateStatus.CHOSEN })],
    }),
    decision({ title: 'عطر', isSuggested: true, candidates: [] }),
  ]);

  assert.equal(readiness.ready, true);
});

test('progress counts every decision, so an almost-done room reads as one', () => {
  const readiness = roomReadiness([
    decision({
      status: RoomDecisionStatus.RESOLVED,
      candidates: [candidate({ status: RoomCandidateStatus.CHOSEN })],
    }),
    decision({
      status: RoomDecisionStatus.RESOLVED,
      candidates: [candidate({ status: RoomCandidateStatus.CHOSEN })],
    }),
    decision({ title: 'حذاء', candidates: [candidate()] }),
  ]);

  assert.ok(readiness.progress > 0.6 && readiness.progress < 0.7);
  assert.equal(readiness.ready, false);
});

// ── Consensus advises; it does not decide ───────────────────────────────

test('silence is reported as silence, not as a tie', () => {
  const result = consensusFor([candidate(), candidate()]);
  assert.equal(result.silent, true);
  assert.equal(result.leaderId, null);
});

test('a clear favourite is reported as one', () => {
  const winner = candidate({ votesUp: 4, voteScore: 4 });
  const other = candidate({ votesUp: 1, voteScore: 1 });

  const result = consensusFor([winner, other]);
  assert.equal(result.leaderId, winner.id);
  assert.equal(result.margin, 3);
  assert.equal(result.contested, false);
});

test('a one-vote lead is contested, not a winner', () => {
  const a = candidate({ votesUp: 2, voteScore: 2 });
  const b = candidate({ votesUp: 1, voteScore: 1 });

  assert.equal(consensusFor([a, b]).contested, true);
});

test('a leader half the room voted against is contested', () => {
  const a = candidate({ votesUp: 3, votesDown: 3, voteScore: 0 });
  const b = candidate({ votesUp: 0, votesDown: 2, voteScore: -2 });

  const result = consensusFor([a, b]);
  assert.equal(result.leaderId, a.id);
  assert.equal(result.contested, true);
});

test('rejected candidates are out of the count entirely', () => {
  const rejected = candidate({
    status: RoomCandidateStatus.REJECTED,
    votesUp: 9,
    voteScore: 9,
  });
  const live = candidate({ votesUp: 1, voteScore: 1 });

  assert.equal(consensusFor([rejected, live]).leaderId, live.id);
});

test('consensus is deterministic when scores tie', () => {
  const a = candidate({ id: 'aaa', votesUp: 2, voteScore: 2 });
  const b = candidate({ id: 'bbb', votesUp: 2, voteScore: 2 });

  assert.equal(consensusFor([a, b]).leaderId, 'aaa');
  assert.equal(consensusFor([b, a]).leaderId, 'aaa');
});

// ── Budget ──────────────────────────────────────────────────────────────

test('no budget is "unknown", never "inside"', () => {
  const fit = budgetFit([{ unitPriceSyp: 500_000, quantity: 1 }], {
    minSyp: null,
    maxSyp: null,
  });
  assert.equal(fit.verdict, 'unknown');
});

test('over the ceiling says by how much', () => {
  const fit = budgetFit(
    [
      { unitPriceSyp: 400_000, quantity: 1 },
      { unitPriceSyp: 300_000, quantity: 2 },
    ],
    { minSyp: null, maxSyp: 800_000 },
  );

  assert.equal(fit.totalSyp, 1_000_000);
  assert.equal(fit.verdict, 'over');
  assert.equal(fit.overBySyp, 200_000);
});

test('quantities count towards the total', () => {
  const fit = budgetFit([{ unitPriceSyp: 100_000, quantity: 3 }], {
    minSyp: null,
    maxSyp: 500_000,
  });
  assert.equal(fit.totalSyp, 300_000);
  assert.equal(fit.verdict, 'inside');
});

test('a delisted line is counted as unpriced rather than as free', () => {
  const fit = budgetFit(
    [
      { unitPriceSyp: null, quantity: 1 },
      { unitPriceSyp: 200_000, quantity: 1 },
    ],
    { minSyp: null, maxSyp: 500_000 },
  );

  assert.equal(fit.unpricedCount, 1);
  assert.equal(fit.totalSyp, 200_000);
});
