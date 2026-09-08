import assert from 'node:assert/strict';
import test from 'node:test';

import { MarketplaceFacts, findingsFor } from './findings';

/**
 * What the console says, and what it refuses to say.
 *
 * The rules being guarded are all about restraint: every finding names its
 * evidence, every finding names an action somebody can actually take, and a
 * quiet week produces nothing at all. A briefing padded with findings nobody
 * needs is one people stop opening, which costs more than the week it papered
 * over.
 */

/** A marketplace with nothing wrong with it. */
const calm = (over: Partial<MarketplaceFacts> = {}): MarketplaceFacts => ({
  openTrustSignals: 0,
  suspectTrustSignals: 0,
  churningCustomers: 0,
  churningValue: 0,
  quietSellers: 0,
  quietSellerLifetimeOrders: 0,
  contributionMargin: 500_000,
  platformRevenue: 800_000,
  gmv: 10_000_000,
  takeRate: 0.08,
  unmetDemandTerms: 0,
  topUnmetTerm: null,
  topUnmetSearches: 0,
  duplicateCandidates: 0,
  risingProducts: 0,
  topRisingTitle: null,
  stockoutRisks: 0,
  windowDays: 30,
  currencyLabel: 'ل.س',
  ...over,
});

const codes = (facts: MarketplaceFacts) =>
  findingsFor(facts).map((finding) => finding.code);

test('a quiet week reports nothing at all', () => {
  assert.deepEqual(
    findingsFor(calm()),
    [],
    'padding a briefing is how it stops being read',
  );
});

test('losing money on every order is the loudest thing there is', () => {
  const findings = findingsFor(calm({ contributionMargin: -400_000 }));
  assert.equal(findings[0].code, 'negative_contribution');
  assert.equal(findings[0].severity, 'critical');
  assert.equal(findings[0].weight, 100);
});

test('a thin take rate is raised, but not while the platform is losing money', () => {
  // Both conditions true: only the more fundamental one is worth saying,
  // because fixing the margin is what fixing the take rate is *for*.
  const bleeding = codes(calm({ contributionMargin: -100, takeRate: 0.01 }));
  assert.ok(bleeding.includes('negative_contribution'));
  assert.ok(!bleeding.includes('take_rate_thin'));

  const thin = codes(calm({ takeRate: 0.01 }));
  assert.ok(thin.includes('take_rate_thin'));
});

test('churn is weighted by what leaving would cost, not by how many', () => {
  const many = findingsFor(
    calm({ churningCustomers: 500, churningValue: 50_000 }),
  ).find((f) => f.code === 'value_at_risk')!;
  const valuable = findingsFor(
    calm({ churningCustomers: 11, churningValue: 4_000_000 }),
  ).find((f) => f.code === 'value_at_risk')!;

  assert.ok(
    valuable.weight > many.weight,
    'two hundred customers worth nothing is not the story',
  );
  assert.equal(valuable.severity, 'critical');
  assert.equal(many.severity, 'warning');
});

test('a suspect trust signal outranks a backlog of ordinary ones', () => {
  const suspects = codes(calm({ suspectTrustSignals: 3, openTrustSignals: 40 }));
  assert.ok(suspects.includes('trust_suspects_waiting'));
  assert.ok(
    !suspects.includes('trust_backlog'),
    'saying both would bury the one that matters',
  );

  const backlog = codes(calm({ openTrustSignals: 40 }));
  assert.ok(backlog.includes('trust_backlog'));
});

test('good news is reported too', () => {
  const findings = findingsFor(
    calm({ risingProducts: 6, topRisingTitle: 'عباية سوداء' }),
  );
  assert.equal(findings[0].code, 'rising_products');
  assert.equal(findings[0].severity, 'opportunity');
  assert.ok(
    findings[0].ar.includes('عباية سوداء'),
    'a console that only ever reports problems gets read as noise',
  );
});

test('every finding names its evidence and an action', () => {
  const findings = findingsFor(
    calm({
      contributionMargin: -100,
      churningCustomers: 20,
      churningValue: 900_000,
      suspectTrustSignals: 2,
      quietSellers: 4,
      quietSellerLifetimeOrders: 90,
      unmetDemandTerms: 12,
      topUnmetTerm: 'عبايات سهرة',
      topUnmetSearches: 40,
      duplicateCandidates: 7,
      stockoutRisks: 5,
      risingProducts: 3,
      topRisingTitle: 'فستان',
    }),
  );

  assert.ok(findings.length >= 7);
  for (const finding of findings) {
    assert.ok(finding.ar.length > 0, `${finding.code} has no wording`);
    assert.ok(finding.actionAr.length > 0, `${finding.code} has no action`);
    assert.ok(
      Object.keys(finding.evidence).length > 0,
      `${finding.code} asserts something with no numbers behind it`,
    );
  }
});

test('findings come back worst-first', () => {
  const findings = findingsFor(
    calm({
      contributionMargin: -100,
      duplicateCandidates: 9,
      suspectTrustSignals: 1,
    }),
  );
  for (let i = 1; i < findings.length; i += 1) {
    assert.ok(
      findings[i - 1].weight >= findings[i].weight,
      'a briefing nobody can read top-down is a list, not a briefing',
    );
  }
});

test('unmet demand is framed as the two things it can be', () => {
  const finding = findingsFor(
    calm({ unmetDemandTerms: 5, topUnmetTerm: 'شنطة', topUnmetSearches: 60 }),
  ).find((f) => f.code === 'unmet_demand')!;

  assert.ok(finding.actionAr.includes('مرادف'));
  assert.ok(
    finding.ar.includes('شنطة'),
    'the term itself is the actionable part',
  );
});

test('a link is offered only where there is somewhere to go', () => {
  const findings = findingsFor(
    calm({ suspectTrustSignals: 1, duplicateCandidates: 2 }),
  );
  assert.ok(findings.every((f) => f.href === null || f.href.startsWith('/')));
});
