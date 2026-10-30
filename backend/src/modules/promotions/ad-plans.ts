import { PromotionPlacement, StoreAdTier } from '@prisma/client';

/**
 * «باقات الإعلان» — what each plan buys a boutique.
 *
 * Pure data and pure arithmetic, so the rules a seller is quoted and the rules
 * the server enforces are the same lines of code, and both can be tested
 * without a database.
 *
 * The plans rank boutiques by what they pay. A higher plan reaches further
 * (more placements, audience targeting), runs more at once, pays less per
 * campaign, carries more ad credit than it costs, and — when several paid
 * placements compete for one slot — is shown more often. «More often», not
 * «always»: a lower plan that paid for a slot is still shown some of the time.
 * A boutique that paid and is never seen has been sold nothing.
 */

/** How long one plan period lasts. */
export const PLAN_PERIOD_DAYS = 30;

/** Placements a Free boutique can already buy, as it always could. */
const BASE_PLACEMENTS: readonly PromotionPlacement[] = [
  PromotionPlacement.SEARCH,
  PromotionPlacement.CATEGORY,
];

/** Which audience groups a plan may target. */
export type TargetingLevel = 'none' | 'location' | 'full';

export interface AdPlan {
  tier: StoreAdTier;
  /** Monthly price in SYP. Zero for Free. */
  priceSyp: number;
  /** Ad credit included in the period, in SYP. Worth more than the price. */
  creditSyp: number;
  /** Off every campaign's price, in basis points (1000 = 10%). */
  discountBps: number;
  /** Campaigns that may be live at the same time. */
  maxActiveCampaigns: number;
  placements: readonly PromotionPlacement[];
  targeting: TargetingLevel;
  /**
   * The share of voice weight. When paid placements compete for a slot, each
   * is picked with probability proportional to this times its daily price.
   */
  servingWeight: number;
  /** Her followers hear about a new campaign (at most once a week). */
  notifiesFollowers: boolean;
  /** Placed first in «متاجر مميزة» on the home page, with her badge. */
  featuredStore: boolean;
}

export const AD_PLANS: Readonly<Record<StoreAdTier, AdPlan>> = {
  [StoreAdTier.FREE]: {
    tier: StoreAdTier.FREE,
    priceSyp: 0,
    creditSyp: 0,
    discountBps: 0,
    maxActiveCampaigns: 1,
    placements: BASE_PLACEMENTS,
    targeting: 'none',
    servingWeight: 1,
    notifiesFollowers: false,
    featuredStore: false,
  },
  [StoreAdTier.SILVER]: {
    tier: StoreAdTier.SILVER,
    priceSyp: 25_000,
    creditSyp: 30_000,
    discountBps: 1000,
    maxActiveCampaigns: 3,
    placements: [...BASE_PLACEMENTS, PromotionPlacement.FEED_TOP],
    targeting: 'location',
    servingWeight: 2,
    notifiesFollowers: false,
    featuredStore: false,
  },
  [StoreAdTier.GOLD]: {
    tier: StoreAdTier.GOLD,
    priceSyp: 60_000,
    creditSyp: 80_000,
    discountBps: 2000,
    maxActiveCampaigns: 6,
    placements: [
      ...BASE_PLACEMENTS,
      PromotionPlacement.FEED_TOP,
      PromotionPlacement.HOME_SPOTLIGHT,
    ],
    targeting: 'full',
    servingWeight: 3,
    notifiesFollowers: true,
    featuredStore: true,
  },
  [StoreAdTier.DIAMOND]: {
    tier: StoreAdTier.DIAMOND,
    priceSyp: 120_000,
    creditSyp: 180_000,
    discountBps: 3000,
    maxActiveCampaigns: 15,
    placements: [
      ...BASE_PLACEMENTS,
      PromotionPlacement.FEED_TOP,
      PromotionPlacement.HOME_SPOTLIGHT,
    ],
    targeting: 'full',
    servingWeight: 5,
    notifiesFollowers: true,
    featuredStore: true,
  },
};

/** Free → Diamond. The order Postgres sorts the enum in, too. */
export const TIER_ORDER: readonly StoreAdTier[] = [
  StoreAdTier.FREE,
  StoreAdTier.SILVER,
  StoreAdTier.GOLD,
  StoreAdTier.DIAMOND,
];

export const tierRank = (tier: StoreAdTier): number => TIER_ORDER.indexOf(tier);

/**
 * The daily price of each placement, in SYP, before any plan discount.
 *
 * The home spotlight is the dearest because everyone opening the app sees it;
 * a category page the cheapest because only the women already browsing that
 * shelf do. Overridable from the console through [RATE_CARD_SETTING].
 */
export const DEFAULT_DAILY_RATES_SYP: Readonly<Record<PromotionPlacement, number>> = {
  [PromotionPlacement.SEARCH]: 1_500,
  [PromotionPlacement.CATEGORY]: 1_000,
  [PromotionPlacement.FEED_TOP]: 2_500,
  [PromotionPlacement.HOME_SPOTLIGHT]: 4_000,
};

/** System setting: `{ "SEARCH": 1500, ... }`, any subset, in SYP per day. */
export const RATE_CARD_SETTING = 'promotions.rate_card_syp';

/**
 * A targeted campaign is shown to fewer women, so it costs less than one shown
 * to everyone — 80% of the price.
 */
export const TARGETED_PRICE_FACTOR = 0.8;

/** How many times a day one shopper may be shown the same feed/home advert. */
export const DAILY_FREQUENCY_CAP = 3;

/** An order counts toward a campaign when she tapped it in this window before. */
export const ATTRIBUTION_WINDOW_DAYS = 7;

/** Followers are told about a boutique's campaign at most this often. */
export const FOLLOWER_NOTICE_INTERVAL_DAYS = 7;

export interface AudienceSpec {
  targeted: boolean;
  governorates: readonly string[];
  followers: boolean;
  pastBuyers: boolean;
  interested: boolean;
  newShoppers: boolean;
}

export const EVERYONE: AudienceSpec = {
  targeted: false,
  governorates: [],
  followers: false,
  pastBuyers: false,
  interested: false,
  newShoppers: false,
};

export const hasInterestGroups = (a: AudienceSpec): boolean =>
  a.followers || a.pastBuyers || a.interested || a.newShoppers;

/**
 * Why a plan cannot buy this campaign, or null when it can.
 *
 * Returned as a code the client turns into a sentence and an upgrade button,
 * not thrown as prose: «this needs Gold» is an offer, not an error.
 */
export function planRefusal(
  plan: AdPlan,
  placement: PromotionPlacement,
  audience: AudienceSpec,
): 'placement_locked' | 'targeting_locked' | 'interest_targeting_locked' | null {
  if (!plan.placements.includes(placement)) return 'placement_locked';
  if (!audience.targeted) return null;
  if (plan.targeting === 'none') return 'targeting_locked';
  if (plan.targeting === 'location' && hasInterestGroups(audience)) {
    return 'interest_targeting_locked';
  }
  return null;
}

/** The lowest plan that can buy this campaign. */
export function lowestPlanFor(
  placement: PromotionPlacement,
  audience: AudienceSpec,
): StoreAdTier {
  for (const tier of TIER_ORDER) {
    if (planRefusal(AD_PLANS[tier], placement, audience) === null) return tier;
  }
  return StoreAdTier.DIAMOND;
}

/**
 * Whole days a window is billed for: any part of a day is a day, at least one
 * — after a minute's grace, so a window that starts "now" a moment before it
 * is priced is not billed an extra day for the milliseconds in between.
 */
export function billedDays(startsAt: Date, endsAt: Date): number {
  const ms = endsAt.getTime() - startsAt.getTime() - 60_000;
  return Math.max(1, Math.ceil(ms / 86_400_000));
}

export interface PriceBreakdown {
  days: number;
  dailyRate: number;
  /** Rate × days, after the audience factor. */
  listPrice: number;
  discount: number;
  /** What the campaign costs her. */
  total: number;
  creditApplied: number;
  /** What leaves her earnings. */
  toPay: number;
}

/**
 * The price of a campaign, in whole SYP.
 *
 * Rounded up to the lira at each step a seller sees, so the figures on her
 * screen add up exactly.
 */
export function priceCampaign(input: {
  dailyRate: number;
  days: number;
  targeted: boolean;
  plan: AdPlan;
  creditAvailable: number;
}): PriceBreakdown {
  const factor = input.targeted ? TARGETED_PRICE_FACTOR : 1;
  const listPrice = Math.ceil(input.dailyRate * input.days * factor);
  const discount = Math.floor((listPrice * input.plan.discountBps) / 10_000);
  const total = listPrice - discount;
  const creditApplied = Math.max(0, Math.min(Math.floor(input.creditAvailable), total));
  return {
    days: input.days,
    dailyRate: input.dailyRate,
    listPrice,
    discount,
    total,
    creditApplied,
    toPay: total - creditApplied,
  };
}

/**
 * The plan that would have cost her least for what she spent on campaigns in
 * the last month, and how much it would have saved — or null when staying put
 * is already cheapest.
 *
 * `spentSyp` is the list price of what she bought (before any discount), so
 * the comparison is like for like across plans.
 */
export function recommendPlan(
  current: StoreAdTier,
  listSpendSyp: number,
): { tier: StoreAdTier; saving: number } | null {
  const costUnder = (tier: StoreAdTier) => {
    const plan = AD_PLANS[tier];
    const campaigns = listSpendSyp - Math.floor((listSpendSyp * plan.discountBps) / 10_000);
    return plan.priceSyp + Math.max(0, campaigns - plan.creditSyp);
  };
  const currentCost = costUnder(current);
  let best: { tier: StoreAdTier; cost: number } | null = null;
  for (const tier of TIER_ORDER) {
    if (tierRank(tier) <= tierRank(current)) continue;
    const cost = costUnder(tier);
    if (cost < currentCost && (!best || cost < best.cost)) best = { tier, cost };
  }
  return best ? { tier: best.tier, saving: currentCost - best.cost } : null;
}

/**
 * Efraimidis–Spirakis weighted sampling without replacement: each item's key
 * is `u^(1/w)` for a uniform `u`, and the k largest keys are a sample in which
 * every item's chance of being first is proportional to its weight.
 *
 * `random` is injectable so the tests can make it deterministic.
 */
export function weightedOrder<T>(
  items: readonly T[],
  weightOf: (item: T) => number,
  random: () => number = Math.random,
): T[] {
  return items
    .map((item) => {
      const weight = Math.max(weightOf(item), 1e-9);
      // log(u)/w rather than u^(1/w): the same order, without every key
      // rounding to 1.0 when the weights are in the thousands.
      return { item, key: Math.log(Math.max(random(), 1e-12)) / weight };
    })
    .sort((a, b) => b.key - a.key)
    .map((entry) => entry.item);
}
