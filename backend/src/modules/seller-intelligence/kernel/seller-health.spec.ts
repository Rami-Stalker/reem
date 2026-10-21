import assert from 'node:assert/strict';
import test from 'node:test';
import { SellerHealthBand } from '@prisma/client';

import {
  SellerHealthFacts,
  adviseSellerHealth,
  arabicCount,
  bandFor,
  evidenceOf,
  rampDown,
  rateScore,
  scoreSellerHealth,
} from './seller-health';
import { RATE_CEILINGS, RESPONSE_HOURS } from '../intelligence.constants';

/**
 * The seller health kernel.
 *
 * The cases that matter are the ones about *evidence*, not the ones about
 * arithmetic: a scoring system for a marketplace is judged by how it treats
 * the seller who has barely started, and every one of those cases is here.
 */

const blank: SellerHealthFacts = {
  acceptedOrders: 0,
  openOrders: 0,
  deliveredOrders: 0,
  cancelledBySeller: 0,
  cancelledByOthers: 0,
  prepHours: null,
  prepSample: 0,
  shipHours: null,
  shipSample: 0,
  responseHours: null,
  responseSample: 0,
  returnedOrders: 0,
  averageRating: null,
  reviewCount: 0,
  productHealthMean: null,
  productHealthSample: 0,
};

/** A shop with a real, unremarkable history. */
const established: SellerHealthFacts = {
  acceptedOrders: 120,
  openOrders: 0,
  deliveredOrders: 110,
  cancelledBySeller: 4,
  cancelledByOthers: 6,
  prepHours: 20,
  prepSample: 110,
  shipHours: 40,
  shipSample: 110,
  responseHours: 1.5,
  responseSample: 60,
  returnedOrders: 6,
  averageRating: 4.6,
  reviewCount: 48,
  productHealthMean: 82,
  productHealthSample: 20,
};

// ── Shapes ───────────────────────────────────────────────────────────────

test('a ramp is a slope, not a cliff', () => {
  assert.equal(rampDown(24, 24, 96), 100, 'at the target is full marks');
  assert.equal(rampDown(10, 24, 96), 100, 'better than target is not extra');
  assert.equal(rampDown(96, 24, 96), 0);
  assert.equal(rampDown(200, 24, 96), 0, 'past the floor stays at the floor');

  // The point of the ramp: an hour late is not a failure.
  const slightlyLate = rampDown(30, 24, 96);
  assert.ok(slightlyLate > 90, `30h against a 24h target should stay high, got ${slightlyLate}`);
});

test('a rate where zero is perfect', () => {
  assert.equal(rateScore(0, 0.25), 100);
  assert.equal(rateScore(0.25, 0.25), 0);
  assert.equal(rateScore(0.125, 0.25), 50);
  assert.equal(rateScore(0.9, 0.25), 0, 'worse than the ceiling is still zero');
});

test('evidence is the share of a full sample', () => {
  assert.equal(evidenceOf(0, 20), 0);
  assert.equal(evidenceOf(10, 20), 0.5);
  assert.equal(evidenceOf(40, 20), 1, 'more than full is still full');
});

// ── The evidence rule, which is the whole design ─────────────────────────

test('a brand-new seller is unmeasured, not bad', () => {
  const result = scoreSellerHealth(blank);
  assert.equal(result.band, SellerHealthBand.BUILDING);
  assert.equal(result.confidence, 0);
  // Every dimension is still reported, so the screen can show her what will
  // be measured rather than showing her an empty page.
  assert.equal(result.dimensions.length, 8);
  assert.ok(
    result.dimensions.every((d) => d.weight === 0),
    'nothing with no evidence may move the score',
  );
});

test('a perfect score on six orders is still BUILDING', () => {
  const result = scoreSellerHealth({
    ...blank,
    acceptedOrders: 6,
    deliveredOrders: 6,
    prepHours: 2,
    prepSample: 6,
    shipHours: 10,
    shipSample: 6,
    averageRating: 5,
    reviewCount: 2,
  });

  assert.ok(result.score > 90, `the arithmetic is genuinely high: ${result.score}`);
  assert.equal(
    result.band,
    SellerHealthBand.BUILDING,
    'six orders cannot buy the top band',
  );
});

test('knowing one dimension well is not knowing the shop', () => {
  // The case live data caught. Her operations are excellent — everything on
  // time, replies inside an hour, four stars — but only a handful of orders
  // have settled, so the sole dimension with a deep sample is the quality of
  // her listings. Scoring depth alone reported "confidence 1.0" and branded
  // her AT_RISK on that one axis.
  const oneAxis: SellerHealthFacts = {
    ...blank,
    acceptedOrders: 4,
    openOrders: 3,
    deliveredOrders: 1,
    cancelledBySeller: 1,
    prepHours: 19,
    prepSample: 4,
    shipHours: 46,
    shipSample: 2,
    responseHours: 0.6,
    responseSample: 1,
    returnedOrders: 1,
    averageRating: 4,
    reviewCount: 1,
    // The one thing measured deeply: a hundred listings scored.
    productHealthMean: 36.5,
    productHealthSample: 107,
  };

  const result = scoreSellerHealth(oneAxis);
  const counted = result.dimensions.filter((d) => d.weight > 0);
  assert.equal(counted.length, 1, 'only listing quality has evidence');

  assert.ok(
    result.confidence < 0.35,
    `one axis of eight cannot be full confidence, got ${result.confidence}`,
  );
  assert.equal(
    result.band,
    SellerHealthBand.BUILDING,
    'she is unmeasured, not failing',
  );
});

test('an ordinary working shop escapes BUILDING', () => {
  // The other risk in the coverage rule: a gate strict enough to be honest
  // about a brand-new shop must still let a normal one through, or the score
  // says "BUILDING" forever and nobody reads it. Forty settled orders over a
  // quarter, eight reviews, a handful of conversations — an unremarkable
  // Damascus boutique, not a flagship.
  const working: SellerHealthFacts = {
    acceptedOrders: 40,
    openOrders: 5,
    deliveredOrders: 37,
    cancelledBySeller: 2,
    cancelledByOthers: 1,
    prepHours: 28,
    prepSample: 37,
    shipHours: 60,
    shipSample: 37,
    responseHours: 6,
    responseSample: 5,
    returnedOrders: 3,
    averageRating: 4.4,
    reviewCount: 8,
    productHealthMean: 68,
    productHealthSample: 30,
  };

  const result = scoreSellerHealth(working);
  assert.ok(
    result.confidence > 0.35,
    `a working shop must be measurable, got ${result.confidence}`,
  );
  assert.notEqual(result.band, SellerHealthBand.BUILDING);
  assert.ok(
    result.dimensions.filter((d) => d.weight > 0).length >= 7,
    'and nearly every dimension should count',
  );
});

test('coverage does not punish a shop that is genuinely well measured', () => {
  // The other side of the same rule: everything measured, deep samples, so
  // coverage must not quietly cap a mature shop's confidence.
  const result = scoreSellerHealth(established);
  assert.equal(result.confidence, 1);
  assert.equal(result.band, SellerHealthBand.EXEMPLARY);
});

test('a dimension nothing has happened in does not cost her anything', () => {
  // She has never been messaged. Responsiveness must not be scored as zero.
  const unmessaged = scoreSellerHealth({ ...established, responseHours: null, responseSample: 0 });
  const messaged = scoreSellerHealth(established);

  const dim = unmessaged.dimensions.find((d) => d.key === 'responsiveness');
  assert.equal(dim?.score, null);
  assert.equal(dim?.weight, 0, 'an unmeasured dimension carries no weight');

  assert.ok(
    unmessaged.score >= messaged.score - 2,
    `silence must not be punished: ${unmessaged.score} vs ${messaged.score}`,
  );
});

test('the weights renormalise across what she has actually done', () => {
  const result = scoreSellerHealth(established);
  const carried = result.dimensions.reduce((t, d) => t + d.weight, 0);
  assert.ok(
    Math.abs(carried - 100) < 0.5,
    `weights of scored dimensions should sum to 100, got ${carried}`,
  );
});

// ── The arithmetic ───────────────────────────────────────────────────────

test('a buyer cancelling is not a fact about the seller', () => {
  const herFault = scoreSellerHealth({
    ...established,
    cancelledBySeller: 20,
    cancelledByOthers: 0,
    deliveredOrders: 100,
  });
  const theirFault = scoreSellerHealth({
    ...established,
    cancelledBySeller: 0,
    cancelledByOthers: 20,
    deliveredOrders: 100,
  });

  assert.ok(
    theirFault.score > herFault.score,
    `cancellations she did not cause must hurt less: ${theirFault.score} vs ${herFault.score}`,
  );

  const rel = theirFault.dimensions.find((d) => d.key === 'reliability');
  assert.equal(rel?.score, 100, 'every order she could deliver, she delivered');
});

test('orders still in transit are not counted as failures', () => {
  // The bug live data caught: a shop with one delivered parcel and twelve
  // still with the courier was scored as 8% reliable. A busy week is the
  // opposite of a failing shop, and reliability may only judge what finished.
  const busy: SellerHealthFacts = {
    ...blank,
    acceptedOrders: 1, // settled
    openOrders: 12, // still moving
    deliveredOrders: 1,
    prepHours: 16,
    prepSample: 9,
  };

  const reliability = scoreSellerHealth(busy).dimensions.find(
    (d) => d.key === 'reliability',
  );
  assert.equal(
    reliability?.score,
    100,
    'the one order that finished, arrived',
  );
  assert.equal(reliability?.sample, 1, 'and only that one is evidence');
});

test('cancelling still counts against everything she took on', () => {
  // The other half: cancellation must not be flattered by the same exclusion.
  // She pulled out of one of thirteen, not one of one.
  const facts: SellerHealthFacts = {
    ...blank,
    acceptedOrders: 1,
    openOrders: 12,
    deliveredOrders: 1,
    cancelledBySeller: 1,
  };

  const cancellation = scoreSellerHealth(facts).dimensions.find(
    (d) => d.key === 'cancellation',
  );
  assert.equal(cancellation?.sample, 13, 'divided by everything she accepted');
  assert.ok(
    (cancellation?.value ?? 0) < 10,
    `one in thirteen is ~7.7%, got ${cancellation?.value}`,
  );
});

test('returns and quality are separate failures', () => {
  const clean = scoreSellerHealth(established);
  const returning = scoreSellerHealth({ ...established, returnedOrders: 30 });

  assert.ok(returning.score < clean.score);
  const dim = returning.dimensions.find((d) => d.key === 'returns');
  assert.ok((dim?.score ?? 100) < 30, 'a 27% return rate is close to the ceiling');
});

test('the band ladder needs both points and evidence', () => {
  assert.equal(bandFor(95, 0.9), SellerHealthBand.EXEMPLARY);
  assert.equal(bandFor(80, 0.9), SellerHealthBand.STRONG);
  assert.equal(bandFor(60, 0.9), SellerHealthBand.STEADY);
  assert.equal(bandFor(20, 0.9), SellerHealthBand.AT_RISK);
  assert.equal(bandFor(95, 0.1), SellerHealthBand.BUILDING, 'confidence vetoes');
});

test('a shop that meets every target reaches the top band', () => {
  // 96% of accepted orders delivered, prep and shipping inside target, 4.6
  // stars, replies within two hours. If this is not the band Reem would put
  // in front of a first-time buyer, the band means nothing.
  const result = scoreSellerHealth(established);
  assert.ok(result.score > 88, `got ${result.score}`);
  assert.equal(result.band, SellerHealthBand.EXEMPLARY);
  assert.equal(result.confidence, 1, 'over 120 orders, every dimension is full');

  const advice = adviseSellerHealth(result, established);
  assert.ok(
    !advice.some((a) => a.severity === 'critical'),
    'nothing critical in a shop doing fine',
  );
});

test('the ladder discriminates: an ordinary shop lands in the middle', () => {
  // Everything works, nothing is fast. This is the common case, and it must
  // not read as either excellent or failing.
  const ordinary: SellerHealthFacts = {
    acceptedOrders: 80,
    openOrders: 0,
    deliveredOrders: 70,
    cancelledBySeller: 5,
    cancelledByOthers: 5,
    prepHours: 50,
    prepSample: 70,
    shipHours: 90,
    shipSample: 70,
    responseHours: 12,
    responseSample: 30,
    returnedOrders: 10,
    averageRating: 4.0,
    reviewCount: 20,
    productHealthMean: 60,
    productHealthSample: 15,
  };

  const result = scoreSellerHealth(ordinary);
  assert.equal(result.band, SellerHealthBand.STEADY, `scored ${result.score}`);
  assert.ok(
    result.score > 58 && result.score < 74,
    `an ordinary shop belongs between the rungs, got ${result.score}`,
  );

  // And it should have something concrete to say to her.
  const advice = adviseSellerHealth(result, ordinary);
  assert.ok(advice.length >= 3, 'an ordinary shop has obvious things to fix');
  assert.ok(
    advice[0].gainPoints >= advice[advice.length - 1].gainPoints,
    'ordered by what it is worth',
  );
});

// ── Advice ───────────────────────────────────────────────────────────────

test('advice is ordered by what it is worth, not by how bad it looks', () => {
  // Cancellation is the lightest dimension (5) and prep is heavy (15). A
  // slightly-bad heavy dimension must outrank a very-bad light one.
  const facts: SellerHealthFacts = {
    ...established,
    prepHours: 70,
    cancelledBySeller: 10,
    acceptedOrders: 120,
  };
  const result = scoreSellerHealth(facts);
  const advice = adviseSellerHealth(result, facts);

  const prep = advice.findIndex((a) => a.dimension === 'prepSpeed');
  const cancel = advice.findIndex((a) => a.dimension === 'cancellation');
  assert.ok(prep >= 0 && cancel >= 0, 'both should be raised');
  assert.ok(
    advice[prep].gainPoints > advice[cancel].gainPoints,
    'the heavier dimension is worth more points',
  );
  assert.ok(prep < cancel, 'and therefore comes first');
});

test('advice speaks in her own numbers', () => {
  const facts: SellerHealthFacts = { ...established, responseHours: 30, responseSample: 40 };
  const result = scoreSellerHealth(facts);
  const advice = adviseSellerHealth(result, facts);

  const line = advice.find((a) => a.code === 'RESPONSE_SLOW');
  assert.ok(line, 'a 30-hour reply time should be raised');
  assert.match(line.ar, /30/, 'the sentence quotes the measured figure');
  assert.ok(line.ar.includes(String(RESPONSE_HOURS.good)) || line.ar.includes('ساعتين'));
});

test('counts in advice read as Arabic, not as a filled-in template', () => {
  const orders = { one: 'طلباً واحداً', two: 'طلبين', few: 'طلبات', many: 'طلباً' };
  assert.equal(arabicCount(1, orders), 'طلباً واحداً');
  assert.equal(arabicCount(2, orders), 'طلبين');
  assert.equal(arabicCount(7, orders), '7 طلبات');
  assert.equal(arabicCount(12, orders), '12 طلباً');
  assert.equal(arabicCount(103, orders), '103 طلبات');

  const facts: SellerHealthFacts = { ...established, cancelledBySeller: 1, acceptedOrders: 11 };
  const line = adviseSellerHealth(scoreSellerHealth(facts), facts).find(
    (a) => a.code === 'CANCEL_RATE',
  );
  assert.ok(line, 'one cancellation is raised');
  assert.match(line.ar, /^ألغيتِ طلباً واحداً من أصل/);

  const slowReply: SellerHealthFacts = { ...established, responseHours: 5, responseSample: 40 };
  const reply = adviseSellerHealth(scoreSellerHealth(slowReply), slowReply).find(
    (a) => a.code === 'RESPONSE_SLOW',
  );
  assert.ok(reply);
  assert.match(reply.ar, /5 ساعات/);
});

test('nothing is advised where nothing was measured', () => {
  const result = scoreSellerHealth(blank);
  assert.deepEqual(adviseSellerHealth(result, blank), []);
});

test('a return rate at the ceiling is critical, a small one is not', () => {
  const mild = { ...established, returnedOrders: 8 };
  const severe = { ...established, returnedOrders: 40 };

  const mildAdvice = adviseSellerHealth(scoreSellerHealth(mild), mild)
    .find((a) => a.code === 'RETURN_RATE');
  const severeAdvice = adviseSellerHealth(scoreSellerHealth(severe), severe)
    .find((a) => a.code === 'RETURN_RATE');

  assert.equal(mildAdvice?.severity, 'warning');
  assert.equal(severeAdvice?.severity, 'critical');
  assert.ok(
    40 / established.deliveredOrders > RATE_CEILINGS.returns,
    'the fixture really is past the ceiling',
  );
});
