import assert from 'node:assert/strict';
import test from 'node:test';
import { ValuePillar } from '@prisma/client';
import {
  DEFAULT_COMMERCE_CEILING_BPS,
  DEFAULT_DAILY_PILLAR_CAPS,
  DEFAULT_HALF_LIFE_DAYS,
  DEFAULT_HORIZON_DAYS,
  DEFAULT_MIN_EVIDENCE_PER_PILLAR,
  DEFAULT_PILLAR_SCALES,
  DEFAULT_PILLAR_WEIGHTS,
  DEFAULT_RELIABILITY_BASELINE,
  DEFAULT_TIERS,
} from '../value.constants';
import { ValueContribution, ValuePolicyView, TierRung } from './value-facts';
import {
  decayFactor,
  nextRungAdvice,
  resolveTier,
  scoreValue,
  spendingAloneCeiling,
} from './value-kernel';

/**
 * The kernel is a pure function, so it is tested the way one should be: no
 * database, no fixtures, contributions written by hand. Every assertion below
 * is a property the programme claims about itself, so a change that breaks one
 * is a change to what Ohara Value *means*, not a change to how it is computed.
 */

const NOW = new Date('2026-09-03T00:00:00Z');
const daysAgo = (days: number) => new Date(NOW.getTime() - days * 86_400_000);

const policy: ValuePolicyView = {
  pillarWeights: DEFAULT_PILLAR_WEIGHTS,
  pillarScales: DEFAULT_PILLAR_SCALES,
  dailyPillarCaps: DEFAULT_DAILY_PILLAR_CAPS,
  halfLifeDays: DEFAULT_HALF_LIFE_DAYS,
  horizonDays: DEFAULT_HORIZON_DAYS,
  commerceCeilingBps: DEFAULT_COMMERCE_CEILING_BPS,
  reliabilityBaseline: DEFAULT_RELIABILITY_BASELINE,
  minEvidencePerPillar: DEFAULT_MIN_EVIDENCE_PER_PILLAR,
};

function events(
  pillar: ValuePillar,
  count: number,
  weight: number,
  ageDays = 0,
): ValueContribution[] {
  return Array.from({ length: count }, (_, index) => ({
    pillar,
    code: 'test',
    weight,
    // Spread across days so the daily cap does not silently swallow the point
    // of a test that is not about the daily cap.
    occurredAt: daysAgo(ageDays + index),
  }));
}

const pillarOf = (score: ReturnType<typeof scoreValue>, pillar: ValuePillar) =>
  score.pillars.find((entry) => entry.pillar === pillar)!;

// ── The economic guarantee ──────────────────────────────────────────────

test('spending alone cannot reach the third rung', () => {
  const ceiling = spendingAloneCeiling(policy);
  const trusted = DEFAULT_TIERS.find((tier) => tier.key === 'trusted')!;

  assert.ok(
    ceiling < trusted.minScore,
    `a pure spender reaches ${ceiling}, which must stay below ${trusted.minScore}`,
  );
});

test('an unlimited buyer is capped by the commerce ceiling', () => {
  // Two hundred kept orders — far past saturation.
  const score = scoreValue(events(ValuePillar.COMMERCE, 200, 8), policy, NOW);
  const commerce = pillarOf(score, ValuePillar.COMMERCE);

  assert.equal(commerce.capped, true);
  assert.equal(commerce.contribution, (DEFAULT_COMMERCE_CEILING_BPS / 10_000) * 1000);
});

test('breadth beats volume: five pillars thinly beat one pillar heavily', () => {
  const oneDeep = scoreValue(events(ValuePillar.COMMERCE, 120, 8), policy, NOW);

  const broad = scoreValue(
    [
      ...events(ValuePillar.COMMERCE, 10, 8),
      ...events(ValuePillar.CRAFT, 8, 12),
      ...events(ValuePillar.COMMUNITY, 8, 6),
      ...events(ValuePillar.ADVOCACY, 4, 25),
      ...events(ValuePillar.DISCOVERY, 4, 10),
    ],
    policy,
    NOW,
  );

  assert.ok(
    broad.score > oneDeep.score,
    `broad ${broad.score} should beat deep-but-narrow ${oneDeep.score}`,
  );
});

// ── Concavity ───────────────────────────────────────────────────────────

test('the fiftieth review is worth far less than the fifth', () => {
  const five = scoreValue(events(ValuePillar.CRAFT, 5, 12), policy, NOW);
  const six = scoreValue(events(ValuePillar.CRAFT, 6, 12), policy, NOW);
  const fifty = scoreValue(events(ValuePillar.CRAFT, 50, 12), policy, NOW);
  const fiftyOne = scoreValue(events(ValuePillar.CRAFT, 51, 12), policy, NOW);

  const earlyGain = six.score - five.score;
  const lateGain = fiftyOne.score - fifty.score;

  assert.ok(earlyGain > 0);
  assert.ok(
    lateGain < earlyGain,
    `late gain ${lateGain} must be smaller than early gain ${earlyGain}`,
  );
});

test('a pillar saturates rather than running away', () => {
  const heavy = pillarOf(scoreValue(events(ValuePillar.CRAFT, 60, 12), policy, NOW),
    ValuePillar.CRAFT);
  const absurd = pillarOf(scoreValue(events(ValuePillar.CRAFT, 400, 12), policy, NOW),
    ValuePillar.CRAFT);

  // Nearly seven times the contribution buys a couple of points. The asymptote
  // is at 100 and the curve never crosses it; at this end of the range the
  // rounding to two places reaches it, which is why the property under test is
  // the flattening rather than the literal inequality.
  assert.ok(absurd.score <= 100);
  assert.ok(
    absurd.score - heavy.score < 5,
    `saturated: ${heavy.score} → ${absurd.score}`,
  );
});

// ── Decay ───────────────────────────────────────────────────────────────

test('a contribution loses half its weight over a half-life', () => {
  assert.equal(decayFactor(0, 365), 1);
  assert.ok(Math.abs(decayFactor(365, 365) - 0.5) < 1e-9);
  assert.ok(Math.abs(decayFactor(730, 365) - 0.25) < 1e-9);
});

test('standing fades when she stops contributing', () => {
  const fresh = scoreValue(events(ValuePillar.CRAFT, 10, 12, 0), policy, NOW);
  const stale = scoreValue(events(ValuePillar.CRAFT, 10, 12, 700), policy, NOW);

  assert.ok(
    stale.score < fresh.score,
    'the same contributions two years ago must be worth less today',
  );
});

test('a contribution past the horizon is worth nothing at all', () => {
  const score = scoreValue(
    events(ValuePillar.CRAFT, 10, 12, DEFAULT_HORIZON_DAYS + 30),
    policy,
    NOW,
  );
  assert.equal(pillarOf(score, ValuePillar.CRAFT).raw, 0);
});

// ── Anti-farming ────────────────────────────────────────────────────────

test('forty reviews in one day count as roughly three', () => {
  const sameDay: ValueContribution[] = Array.from({ length: 40 }, () => ({
    pillar: ValuePillar.CRAFT,
    code: 'review_helpful',
    weight: 12,
    occurredAt: daysAgo(1),
  }));

  const score = scoreValue(sameDay, policy, NOW);
  const craft = pillarOf(score, ValuePillar.CRAFT);

  // The cap is 24, so at most two reviews' worth survives the day.
  assert.ok(
    craft.raw <= DEFAULT_DAILY_PILLAR_CAPS[ValuePillar.CRAFT],
    `raw ${craft.raw} must not exceed the daily cap`,
  );
});

test('the daily cap keeps her best contribution of the day, not the first', () => {
  const day = daysAgo(1);
  const mixed: ValueContribution[] = [
    { pillar: ValuePillar.COMMUNITY, code: 'comment', weight: 2, occurredAt: day },
    { pillar: ValuePillar.COMMUNITY, code: 'post', weight: 6, occurredAt: day },
    { pillar: ValuePillar.COMMUNITY, code: 'comment', weight: 2, occurredAt: day },
  ];

  const capped: ValuePolicyView = {
    ...policy,
    dailyPillarCaps: { ...policy.dailyPillarCaps, [ValuePillar.COMMUNITY]: 6 },
    minEvidencePerPillar: 1,
  };

  const score = scoreValue(mixed, capped, NOW);
  const community = pillarOf(score, ValuePillar.COMMUNITY);

  // The single 6 survives whole rather than three 2s in arrival order.
  assert.ok(community.raw > 5.9 && community.raw <= 6);
});

test('refusals cannot be diluted by concentrating them', () => {
  const day = daysAgo(1);
  const refusals: ValueContribution[] = Array.from({ length: 5 }, () => ({
    pillar: ValuePillar.RELIABILITY,
    code: 'parcel_refused',
    weight: -22,
    occurredAt: day,
  }));

  const score = scoreValue(refusals, policy, NOW);
  const reliability = pillarOf(score, ValuePillar.RELIABILITY);

  assert.ok(reliability.raw < -100, 'negative weights are never capped');
  assert.ok(reliability.score < DEFAULT_RELIABILITY_BASELINE);
});

// ── Evidence ────────────────────────────────────────────────────────────

test('a thin pillar says "we do not know" rather than scoring low', () => {
  const score = scoreValue(events(ValuePillar.CRAFT, 1, 12), policy, NOW);
  const craft = pillarOf(score, ValuePillar.CRAFT);

  assert.equal(craft.evidence, 'insufficient');
  assert.equal(craft.score, 0);
});

test('a woman with no history sits at the reliability baseline, not at zero', () => {
  const score = scoreValue([], policy, NOW);
  const reliability = pillarOf(score, ValuePillar.RELIABILITY);

  assert.equal(reliability.score, DEFAULT_RELIABILITY_BASELINE);
  assert.ok(score.score > 0, 'a new customer is not scored as a bad one');
});

test('scoring is deterministic', () => {
  const contributions = [
    ...events(ValuePillar.COMMERCE, 6, 8),
    ...events(ValuePillar.CRAFT, 4, 12),
    ...events(ValuePillar.RELIABILITY, 3, 4),
  ];
  assert.deepEqual(
    scoreValue(contributions, policy, NOW),
    scoreValue(contributions, policy, NOW),
  );
});

test('the score stays inside 0–1000', () => {
  const everything = [
    ...events(ValuePillar.COMMERCE, 300, 8),
    ...events(ValuePillar.CRAFT, 300, 12),
    ...events(ValuePillar.COMMUNITY, 300, 6),
    ...events(ValuePillar.ADVOCACY, 300, 25),
    ...events(ValuePillar.DISCOVERY, 300, 14),
    ...events(ValuePillar.RELIABILITY, 300, 4),
  ];
  const score = scoreValue(everything, policy, NOW);
  assert.ok(score.score > 0 && score.score <= 1000);
});

// ── Tiering ─────────────────────────────────────────────────────────────

const ladder: TierRung[] = DEFAULT_TIERS.map((tier) => ({
  id: tier.key,
  key: tier.key,
  name: tier.name,
  minScore: tier.minScore,
  rank: tier.rank,
  demotionBufferScore: tier.demotionBufferScore,
  holdDays: tier.holdDays,
}));

const nowhere = { tierKey: null, tierAchievedAt: null, tierHeldUntil: null };

test('promotion is immediate', () => {
  const decision = resolveTier(450, ladder, nowhere, NOW);
  assert.equal(decision.tier?.key, 'trusted');
  assert.equal(decision.movement, 'promoted');
});

test('a rung is held for its hold period whatever the score does', () => {
  const decision = resolveTier(
    100,
    ladder,
    {
      tierKey: 'trusted',
      tierAchievedAt: daysAgo(10),
      tierHeldUntil: new Date(NOW.getTime() + 30 * 86_400_000),
    },
    NOW,
  );

  assert.equal(decision.tier?.key, 'trusted');
  assert.equal(decision.movement, 'held');
});

test('after the hold, hysteresis still protects a score near the line', () => {
  const decision = resolveTier(
    // 420 minus a 40 buffer is 380; 400 is inside it.
    400,
    ladder,
    { tierKey: 'trusted', tierAchievedAt: daysAgo(200), tierHeldUntil: daysAgo(10) },
    NOW,
  );

  assert.equal(decision.tier?.key, 'trusted');
  assert.equal(decision.movement, 'held');
});

test('a real fall does demote, once the hold has run out', () => {
  const decision = resolveTier(
    200,
    ladder,
    { tierKey: 'trusted', tierAchievedAt: daysAgo(200), tierHeldUntil: daysAgo(10) },
    NOW,
  );

  assert.equal(decision.tier?.key, 'known');
  assert.equal(decision.movement, 'demoted');
});

test('a score on a boundary does not oscillate', () => {
  let state = nowhere as {
    tierKey: string | null;
    tierAchievedAt: Date | null;
    tierHeldUntil: Date | null;
  };

  // Promote at exactly the threshold, then hover just under it for a year.
  for (const [index, score] of [420, 419, 421, 418, 419].entries()) {
    const at = new Date(NOW.getTime() + index * 400 * 86_400_000);
    const decision = resolveTier(score, ladder, state, at);
    state = {
      tierKey: decision.tier?.key ?? null,
      tierAchievedAt: at,
      tierHeldUntil: decision.heldUntil,
    };
    assert.equal(decision.tier?.key, 'trusted', `oscillated at step ${index}`);
  }
});

// ── Advice ──────────────────────────────────────────────────────────────

test('the advice never tells a capped spender to spend more', () => {
  const score = scoreValue(events(ValuePillar.COMMERCE, 200, 8), policy, NOW);
  const next = ladder.find((rung) => rung.key === 'trusted')!;

  const advice = nextRungAdvice(score, policy, next);
  const commerce = advice.find((entry) => entry.pillar === ValuePillar.COMMERCE);

  assert.ok(
    commerce === undefined || commerce.headroom === 0,
    'a woman already at the commerce ceiling must not be told to buy more',
  );
  assert.ok(advice.length > 0, 'but she must still be told what would work');
});

test('advice is empty once she has already reached the rung', () => {
  const score = scoreValue(events(ValuePillar.CRAFT, 40, 12), policy, NOW);
  const reached: TierRung = { ...ladder[0], minScore: 0 };
  assert.deepEqual(nextRungAdvice(score, policy, reached), []);
});
