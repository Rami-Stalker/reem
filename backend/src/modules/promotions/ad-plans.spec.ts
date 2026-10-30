import assert from 'node:assert/strict';
import test from 'node:test';
import { PromotionPlacement, StoreAdTier } from '@prisma/client';
import {
  AD_PLANS,
  billedDays,
  EVERYONE,
  lowestPlanFor,
  planRefusal,
  priceCampaign,
  recommendPlan,
  TIER_ORDER,
  weightedOrder,
} from './ad-plans';

/**
 * The rules a seller is quoted are the rules the server enforces — these are
 * the same functions, tested without a database.
 */

test('each plan up the ladder gives at least as much as the one below', () => {
  for (let i = 1; i < TIER_ORDER.length; i += 1) {
    const lower = AD_PLANS[TIER_ORDER[i - 1]];
    const higher = AD_PLANS[TIER_ORDER[i]];
    assert.ok(higher.discountBps >= lower.discountBps);
    assert.ok(higher.maxActiveCampaigns >= lower.maxActiveCampaigns);
    assert.ok(higher.servingWeight > lower.servingWeight);
    assert.ok(higher.placements.length >= lower.placements.length);
  }
});

test('a paid plan always carries more ad credit than it costs', () => {
  for (const tier of TIER_ORDER.filter((t) => t !== StoreAdTier.FREE)) {
    assert.ok(AD_PLANS[tier].creditSyp > AD_PLANS[tier].priceSyp, tier);
  }
});

test('the plan a campaign needs is named, so the refusal is an offer', () => {
  assert.equal(lowestPlanFor(PromotionPlacement.SEARCH, EVERYONE), StoreAdTier.FREE);
  assert.equal(lowestPlanFor(PromotionPlacement.FEED_TOP, EVERYONE), StoreAdTier.SILVER);
  assert.equal(lowestPlanFor(PromotionPlacement.HOME_SPOTLIGHT, EVERYONE), StoreAdTier.GOLD);
  const located = { ...EVERYONE, targeted: true, governorates: ['حلب'] };
  assert.equal(lowestPlanFor(PromotionPlacement.SEARCH, located), StoreAdTier.SILVER);
  const followers = { ...EVERYONE, targeted: true, followers: true };
  assert.equal(lowestPlanFor(PromotionPlacement.SEARCH, followers), StoreAdTier.GOLD);
  assert.equal(
    planRefusal(AD_PLANS.SILVER, PromotionPlacement.SEARCH, followers),
    'interest_targeting_locked',
  );
});

test('a price adds up on her screen: list − discount − credit = what she pays', () => {
  const p = priceCampaign({
    dailyRate: 2500,
    days: 7,
    targeted: true,
    plan: AD_PLANS.GOLD,
    creditAvailable: 5000,
  });
  assert.equal(p.listPrice, 2500 * 7 * 0.8);
  assert.equal(p.discount, p.listPrice * 0.2);
  assert.equal(p.total, p.listPrice - p.discount);
  assert.equal(p.creditApplied, 5000);
  assert.equal(p.toPay, p.total - 5000);
});

test('credit never pays more than the campaign costs', () => {
  const p = priceCampaign({
    dailyRate: 1000,
    days: 1,
    targeted: false,
    plan: AD_PLANS.DIAMOND,
    creditAvailable: 1_000_000,
  });
  assert.equal(p.creditApplied, p.total);
  assert.equal(p.toPay, 0);
});

test('any part of a day is billed as a day, after a minute of grace', () => {
  const start = new Date('2026-01-01T00:00:00Z');
  const at = (ms: number) => new Date(start.getTime() + ms);
  assert.equal(billedDays(start, at(60 * 60_000)), 1);
  assert.equal(billedDays(start, at(86_400_000 + 30_000)), 1);
  assert.equal(billedDays(start, at(86_400_000 + 5 * 60_000)), 2);
});

test('the recommendation is the plan that would have cost her least', () => {
  assert.equal(recommendPlan(StoreAdTier.FREE, 0), null, 'spending nothing, no plan is cheaper');
  const rec = recommendPlan(StoreAdTier.FREE, 100_000);
  assert.ok(rec, 'a hundred thousand of campaigns is cheaper on a plan');
  assert.ok(rec!.saving > 0);
  assert.equal(recommendPlan(StoreAdTier.DIAMOND, 1_000_000), null, 'nothing above diamond');
});

test('weighted order favours weight without starving the light', () => {
  let seed = 42;
  const random = () => (seed = (seed * 16807) % 2147483647) / 2147483647;
  const counts = { heavy: 0, light: 0 };
  for (let i = 0; i < 2000; i += 1) {
    const [first] = weightedOrder(
      ['heavy', 'light'] as const,
      (x) => (x === 'heavy' ? 4 : 1),
      random,
    );
    counts[first] += 1;
  }
  // Expected 4:1 → ~1600 / ~400.
  assert.ok(counts.heavy > 1400 && counts.heavy < 1800, JSON.stringify(counts));
  assert.ok(counts.light > 200, JSON.stringify(counts));
});

test('weighted order still works when weights are in the thousands', () => {
  const order = weightedOrder([1, 2, 3], (x) => x * 5000, () => 0.5);
  assert.deepEqual(order, [3, 2, 1]);
});
