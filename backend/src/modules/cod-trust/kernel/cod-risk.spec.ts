import assert from 'node:assert/strict';
import test from 'node:test';
import { CodAssurance, CodRiskTier } from '@prisma/client';
import {
  BASE_SCORE,
  HARD_RULES,
  MIN_EVIDENCE,
  TRUSTED_MIN_DELIVERIES,
  WEIGHTS,
} from '../cod-trust.constants';
import { CodFacts } from './cod-facts';
import { scoreCodRisk } from './cod-risk';
import { decideCodAssurance, tierFor } from './cod-policy';

/**
 * A customer with no history and nothing wrong with her order — the shape
 * every case below deviates from by one field, so a test reads as the single
 * fact it is about.
 */
const baseline = (): CodFacts => ({
  customer: {
    isGuest: false,
    accountAgeDays: 40,
    phoneVerified: true,
    deviceEnrolled: true,
    deliveredParcels: 0,
    refusedParcels: 0,
    failedParcels: 0,
    cancelledAfterConfirmation: 0,
    totalOrders: 0,
    medianOrderValue: null,
    openDisputes: 0,
  },
  destination: {
    fromAddressBook: true,
    addressLineLength: 60,
    hasLandmark: true,
    isRural: false,
    governorateAttempts: 0,
    governorateRefusals: 0,
    otherAccountsOnPhone: 0,
  },
  basket: {
    orderValue: 20,
    sellerCount: 1,
    itemCount: 2,
    maxUnitsOnOneLine: 1,
  },
});

const facts = (patch: {
  customer?: Partial<CodFacts['customer']>;
  destination?: Partial<CodFacts['destination']>;
  basket?: Partial<CodFacts['basket']>;
}): CodFacts => {
  const base = baseline();
  return {
    customer: { ...base.customer, ...patch.customer },
    destination: { ...base.destination, ...patch.destination },
    basket: { ...base.basket, ...patch.basket },
  };
};

const factorOf = (result: ReturnType<typeof scoreCodRisk>, code: string) => {
  const found = result.factors.find((f) => f.code === code);
  assert.ok(found, `no factor ${code}`);
  return found;
};

// ── The property the whole engine rests on ─────────────────────────────

test('a customer with no history scores near the base rate, not near the top', () => {
  // The failure this guards against is the one that would have made the whole
  // feature unshippable: an engine that treats "we have never seen her" as
  // "she is dangerous" adds friction to every new customer's first order, on
  // a platform whose entire launch plan is first orders.
  const result = scoreCodRisk(baseline());
  assert.equal(result.score, BASE_SCORE);
  assert.equal(result.confidence, 0);
});

test('every rate factor is silent until it has enough attempts to be a rate', () => {
  const thin = facts({
    customer: { refusedParcels: 1, deliveredParcels: 1, totalOrders: 2 },
  });
  const refusal = factorOf(scoreCodRisk(thin), 'refusalRate');

  // One refusal in two attempts is 50% by arithmetic and nothing by evidence.
  assert.equal(refusal.evidence, 'insufficient');
  assert.equal(refusal.points, 0);
  assert.ok(MIN_EVIDENCE.personalAttempts > 2);
});

test('the same refusal rate scores higher once the sample is real', () => {
  const thin = scoreCodRisk(
    facts({ customer: { refusedParcels: 1, deliveredParcels: 1, totalOrders: 2 } }),
  );
  const thick = scoreCodRisk(
    facts({ customer: { refusedParcels: 4, deliveredParcels: 4, totalOrders: 8 } }),
  );
  assert.ok(factorOf(thick, 'refusalRate').points > factorOf(thin, 'refusalRate').points);
  assert.ok(thick.confidence > thin.confidence);
});

// ── The factors, one at a time ─────────────────────────────────────────

test('refusal weighs more than a door nobody answered', () => {
  const refused = scoreCodRisk(
    facts({ customer: { refusedParcels: 3, deliveredParcels: 3, totalOrders: 6 } }),
  );
  const missed = scoreCodRisk(
    facts({ customer: { failedParcels: 3, deliveredParcels: 3, totalOrders: 6 } }),
  );
  assert.ok(refused.score > missed.score);
  assert.ok(WEIGHTS.refusalRate > WEIGHTS.failureRate);
});

test('a proven history is the only thing that pulls a score down', () => {
  const proven = scoreCodRisk(
    facts({ customer: { deliveredParcels: 9, totalOrders: 9 } }),
  );
  assert.ok(proven.score < BASE_SCORE);
  assert.equal(
    proven.factors.filter((f) => f.points < 0).map((f) => f.code).join(),
    'provenHistory',
  );
});

test('deliveries mixed with refusals earn less credit than clean ones', () => {
  const clean = scoreCodRisk(facts({ customer: { deliveredParcels: 8, totalOrders: 8 } }));
  const mixed = scoreCodRisk(
    facts({ customer: { deliveredParcels: 8, refusedParcels: 4, totalOrders: 12 } }),
  );
  assert.ok(
    factorOf(mixed, 'provenHistory').points > factorOf(clean, 'provenHistory').points,
    'credit is negative, so "greater" means "less credit"',
  );
});

test('spending below her usual is not a risk; spending far above it is', () => {
  const below = scoreCodRisk(
    facts({
      customer: { deliveredParcels: 4, totalOrders: 4, medianOrderValue: 100 },
      basket: { orderValue: 30 },
    }),
  );
  const above = scoreCodRisk(
    facts({
      customer: { deliveredParcels: 4, totalOrders: 4, medianOrderValue: 20 },
      basket: { orderValue: 140 },
    }),
  );
  assert.equal(factorOf(below, 'valueAnomaly').points, 0);
  assert.ok(factorOf(above, 'valueAnomaly').points > 0);
});

test('a typed address with no landmark scores worse than one from her book', () => {
  const saved = scoreCodRisk(baseline());
  const typed = scoreCodRisk(
    facts({
      destination: { fromAddressBook: false, hasLandmark: false, addressLineLength: 12 },
    }),
  );
  assert.ok(typed.score > saved.score);
});

test('a quiet governorate contributes nothing, however bad its handful of parcels', () => {
  const quiet = scoreCodRisk(
    facts({ destination: { governorateAttempts: 5, governorateRefusals: 5 } }),
  );
  assert.equal(factorOf(quiet, 'destinationBaseRate').evidence, 'insufficient');
  assert.equal(factorOf(quiet, 'destinationBaseRate').points, 0);
});

test('basket shape is read on a first order and ignored once she has a history', () => {
  const wild = { sellerCount: 4, itemCount: 9, maxUnitsOnOneLine: 6 };
  const first = scoreCodRisk(facts({ basket: wild }));
  const known = scoreCodRisk(
    facts({ basket: wild, customer: { deliveredParcels: 6, totalOrders: 6 } }),
  );
  assert.ok(factorOf(first, 'basketShape').points > 0);
  assert.equal(factorOf(known, 'basketShape').evidence, 'insufficient');
});

test('an open dispute never touches the score', () => {
  const disputed = scoreCodRisk(facts({ customer: { openDisputes: 3 } }));
  assert.equal(disputed.score, BASE_SCORE);
});

test('the score is clamped to 0..100 however many alarms fire', () => {
  const worst = scoreCodRisk(
    facts({
      customer: {
        isGuest: true,
        phoneVerified: false,
        deviceEnrolled: false,
        refusedParcels: 12,
        failedParcels: 8,
        cancelledAfterConfirmation: 9,
        totalOrders: 20,
        deliveredParcels: 0,
        medianOrderValue: 5,
      },
      destination: {
        fromAddressBook: false,
        hasLandmark: false,
        addressLineLength: 4,
        isRural: true,
        governorateAttempts: 500,
        governorateRefusals: 300,
        otherAccountsOnPhone: 7,
      },
      basket: { orderValue: 900, sellerCount: 5, itemCount: 20, maxUnitsOnOneLine: 9 },
    }),
  );
  assert.equal(worst.score, 100);

  const best = scoreCodRisk(facts({ customer: { deliveredParcels: 40, totalOrders: 40 } }));
  assert.ok(best.score >= 0);
});

// ── Policy ─────────────────────────────────────────────────────────────

test('the trusted tier cannot be reached without deliveries actually taken', () => {
  assert.equal(tierFor(5, TRUSTED_MIN_DELIVERIES - 1), CodRiskTier.LOW);
  assert.equal(tierFor(5, TRUSTED_MIN_DELIVERIES), CodRiskTier.TRUSTED);
});

test('a quiet first order under the threshold passes without friction', () => {
  const input = facts({ basket: { orderValue: HARD_RULES.firstOrderConfirmAbove - 1 } });
  const decision = decideCodAssurance(scoreCodRisk(input), input);
  assert.equal(decision.assurance, CodAssurance.NONE);
  assert.deepEqual(decision.ruleCodes, []);
});

test('a first order above the threshold asks for a code even at a low score', () => {
  const input = facts({ basket: { orderValue: HARD_RULES.firstOrderConfirmAbove + 5 } });
  const scored = scoreCodRisk(input);
  const decision = decideCodAssurance(scored, input);
  assert.equal(tierFor(scored.score, 0), CodRiskTier.LOW);
  assert.equal(decision.assurance, CodAssurance.ORDER_CONFIRMATION);
  assert.ok(decision.ruleCodes.includes('first_order_above_threshold'));
});

test('a spotless history does not buy past the high-value rule', () => {
  const input = facts({
    customer: { deliveredParcels: 30, totalOrders: 30, medianOrderValue: 400 },
    basket: { orderValue: HARD_RULES.alwaysConfirmAbove + 1 },
  });
  const decision = decideCodAssurance(scoreCodRisk(input), input);
  assert.equal(decision.tier, CodRiskTier.TRUSTED);
  assert.equal(decision.assurance, CodAssurance.ORDER_CONFIRMATION);
  assert.ok(decision.ruleCodes.includes('high_value_order'));
});

test('repeat refusals take cash off the table regardless of the score', () => {
  const input = facts({
    customer: {
      deliveredParcels: 60,
      totalOrders: 60,
      refusedParcels: HARD_RULES.refusalsForPrepayment,
      medianOrderValue: 50,
    },
  });
  const decision = decideCodAssurance(scoreCodRisk(input), input);
  assert.equal(decision.assurance, CodAssurance.PREPAYMENT);
  assert.ok(decision.ruleCodes.includes('repeat_refusals'));
});

test('the score alone can reach prepayment, with no hard rule to help it', () => {
  // Every hard rule is deliberately kept below its threshold — two refusals
  // where three are needed, an order too small for the value rules — so the
  // only thing that can produce `PREPAYMENT` here is the score itself. This is
  // the test that would catch an engine whose tiers had quietly become
  // decoration on top of four `if` statements.
  const input = facts({
    customer: {
      isGuest: true,
      phoneVerified: false,
      deviceEnrolled: false,
      refusedParcels: HARD_RULES.refusalsForPrepayment - 1,
      failedParcels: 10,
      deliveredParcels: 0,
      cancelledAfterConfirmation: 10,
      totalOrders: 12,
    },
    destination: {
      fromAddressBook: false,
      hasLandmark: false,
      addressLineLength: 6,
      isRural: true,
      otherAccountsOnPhone: 3,
      governorateAttempts: 100,
      governorateRefusals: 40,
    },
    basket: { orderValue: 3, sellerCount: 4, itemCount: 9, maxUnitsOnOneLine: 6 },
  });
  const scored = scoreCodRisk(input);
  const decision = decideCodAssurance(scored, input);

  assert.deepEqual(decision.ruleCodes, [], 'no hard rule may fire');
  assert.ok(scored.score >= 70, `score was ${scored.score}`);
  assert.equal(decision.tier, CodRiskTier.HIGH);
  assert.equal(decision.assurance, CodAssurance.PREPAYMENT);
});

test('the ladder never ends in a refusal to sell', () => {
  const input = facts({
    customer: { isGuest: true, phoneVerified: false, refusedParcels: 20, totalOrders: 20 },
    basket: { orderValue: 5000 },
  });
  const decision = decideCodAssurance(scoreCodRisk(input), input);
  assert.ok(Object.values(CodAssurance).includes(decision.assurance));
  assert.equal(decision.assurance, CodAssurance.PREPAYMENT);
});
