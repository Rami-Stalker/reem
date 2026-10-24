/**
 * The economics of one corner of the market.
 *
 * Pure arithmetic over facts that already exist. Nothing here counts anything
 * — `ProductDemandDaily` and `CategoryDemandDaily` did the counting, and the
 * commerce graph knows who wants what. What this file does is the step none of
 * them take: hold demand and supply up against each other and say what the
 * comparison means.
 *
 * ── Why five numbers instead of one ──────────────────────────────────────
 *
 * A single "market score" is worse than useless. High demand with no listings
 * and low demand with hundreds average to the same middle, and they are
 * opposite instructions: one says *stock this*, the other says *do not*. So
 * demand, supply, conversion and competition stay apart, and `tension` — the
 * difference between the first two — is the only figure that combines them,
 * because that difference is the actual finding.
 */

import { MarketFinding } from '@prisma/client';

const round = (n: number, dp = 2): number => {
  const f = 10 ** dp;
  return Math.round(n * f) / f;
};
const clamp = (n: number, lo = 0, hi = 100): number =>
  Math.min(hi, Math.max(lo, n));

/**
 * Saturating scale.
 *
 * Markets are long-tailed: a handful of categories get thousands of views and
 * most get dozens, so a linear scale would put the whole catalogue at 2 and
 * the top three at 100. `scale` flattens the tail — the difference between 10
 * views and 40 matters, the difference between 4,000 and 4,030 does not.
 */
export function scale(value: number, half: number): number {
  if (value <= 0 || half <= 0) return 0;
  return round((value / (value + half)) * 100);
}

// ── What the kernel is given ─────────────────────────────────────────────

/**
 * One subject's window, as plain counts.
 *
 * Every field is something a person could total by hand from the daily
 * tables, which is what keeps a market reading auditable.
 */
export interface MarketFacts {
  /** Attention, over the whole window. */
  views: number;
  searches: number;
  /** Intent — the signals short of a purchase. */
  cartAdds: number;
  favourites: number;
  /** Outcome. */
  orders: number;
  units: number;

  /** The recent half against the half before it, for direction. */
  recentViews: number;
  previousViews: number;

  /** Supply, snapshotted: what is actually buyable. */
  liveProducts: number;
  liveOffers: number;
  stockUnits: number;
  /** Distinct sellers competing here. */
  sellers: number;

  /** Shoppers whose closet gaps or open room decisions name this subject. */
  openNeeds: number;

  /** Median live price, and the parent's, for the price index. */
  medianPriceSyp: number | null;
  parentMedianPriceSyp: number | null;
}

/** The scale a market is read against — set from the platform, not invented. */
export interface MarketNorms {
  /** Views at which demand reads as 50. The platform median works well. */
  halfViews: number;
  /** Live products at which supply reads as 50. */
  halfProducts: number;
  /** Sellers at which competition reads as 50. */
  halfSellers: number;
  /** The platform's own conversion rate, so a subject is judged against its market. */
  medianConversion: number;
}

export interface Finding {
  code: MarketFinding;
  /** 0-100 — how strongly the numbers support it. */
  strength: number;
  evidence: Record<string, number | null>;
}

export interface MarketReading {
  demandScore: number;
  supplyScore: number;
  conversionScore: number;
  competition: number;
  /** Demand minus supply, -100…100. */
  tension: number;
  priceIndexBps: number | null;
  confidence: number;
  findings: Finding[];
  components: Record<string, number | null>;
}

// ── Thresholds ───────────────────────────────────────────────────────────

/** Tension above which demand is genuinely ahead of supply. */
const SUPPLY_GAP_TENSION = 25;

/** Tension below which the aisle is crowded relative to what anybody wants. */
const OVERSUPPLY_TENSION = -30;

/** Growth at which a subject counts as rising. */
const RISING_GROWTH = 0.25;

/** Views below which growth is noise rather than a trend. */
const MIN_VIEWS_FOR_DIRECTION = 25;

/** Views below which conversion cannot be judged. */
const MIN_VIEWS_FOR_CONVERSION = 40;

/** Sellers above which an aisle is crowded. */
const CROWDED_SELLERS = 8;

/** Demand this high with no stock is the most expensive state in commerce. */
const STOCKOUT_MIN_DEMAND = 30;

// ── The kernel ───────────────────────────────────────────────────────────

export function readMarket(
  facts: MarketFacts,
  norms: MarketNorms,
): MarketReading {
  // Demand is attention *plus intent*, weighted: a cart add says far more
  // about wanting something than a view does, and a market read on views
  // alone rewards whatever the home page happens to be showing.
  const intent = facts.cartAdds * 6 + facts.favourites * 3 + facts.openNeeds * 8;
  const demandScore = scale(
    facts.views + facts.searches * 2 + intent,
    norms.halfViews,
  );

  // Supply is what she could actually buy today — listings that exist but
  // have no stock are not supply, which is the distinction that makes
  // STOCKED_OUT possible at all.
  const buyable = facts.stockUnits > 0 ? facts.liveProducts : 0;
  const supplyScore = scale(buyable, norms.halfProducts);

  const conversion = facts.views > 0 ? facts.orders / facts.views : 0;
  const conversionScore =
    facts.views < MIN_VIEWS_FOR_CONVERSION
      ? 0
      : norms.medianConversion > 0
        ? clamp(round((conversion / norms.medianConversion) * 50))
        : clamp(round((conversion / 0.03) * 50));

  const competition = scale(facts.sellers, norms.halfSellers);
  const tension = round(demandScore - supplyScore);

  const priceIndexBps =
    facts.medianPriceSyp && facts.parentMedianPriceSyp
      ? Math.round(
          ((facts.medianPriceSyp - facts.parentMedianPriceSyp) /
            facts.parentMedianPriceSyp) *
            10_000,
        )
      : null;

  const growth = growthOf(facts.recentViews, facts.previousViews);
  const findings: Finding[] = [];

  // ── Supply against demand ─────────────────────────────────────────────
  if (tension >= SUPPLY_GAP_TENSION && demandScore >= 20) {
    findings.push({
      code: MarketFinding.SUPPLY_GAP,
      strength: clamp(round(tension)),
      evidence: {
        demandScore,
        supplyScore,
        liveProducts: facts.liveProducts,
        openNeeds: facts.openNeeds,
      },
    });
  } else if (tension <= OVERSUPPLY_TENSION && supplyScore >= 30) {
    findings.push({
      code: MarketFinding.OVERSUPPLIED,
      strength: clamp(round(-tension)),
      evidence: { demandScore, supplyScore, liveProducts: facts.liveProducts },
    });
  }

  // ── Direction ─────────────────────────────────────────────────────────
  //
  // Only when the numbers are big enough to have a direction. A subject that
  // went from two views to six has not started trending.
  if (facts.recentViews >= MIN_VIEWS_FOR_DIRECTION) {
    if (growth >= RISING_GROWTH) {
      findings.push({
        code: MarketFinding.RISING,
        strength: clamp(round(Math.min(1, growth / (RISING_GROWTH * 3)) * 100)),
        evidence: {
          growth: round(growth, 3),
          recentViews: facts.recentViews,
          previousViews: facts.previousViews,
        },
      });
    } else if (growth <= -RISING_GROWTH) {
      findings.push({
        code: MarketFinding.COOLING,
        strength: clamp(round(Math.min(1, -growth / (RISING_GROWTH * 3)) * 100)),
        evidence: { growth: round(growth, 3), recentViews: facts.recentViews },
      });
    }
  }

  // ── Attention that does not convert ───────────────────────────────────
  if (facts.views >= MIN_VIEWS_FOR_CONVERSION && conversionScore < 30) {
    findings.push({
      code: MarketFinding.WEAK_CONVERSION,
      strength: clamp(round(100 - conversionScore)),
      evidence: {
        views: facts.views,
        orders: facts.orders,
        conversion: round(conversion, 4),
        medianConversion: round(norms.medianConversion, 4),
      },
    });
  }

  // ── Crowding ──────────────────────────────────────────────────────────
  if (facts.sellers >= CROWDED_SELLERS && tension < 0) {
    findings.push({
      code: MarketFinding.CROWDED,
      strength: clamp(round(competition)),
      evidence: { sellers: facts.sellers, tension },
    });
  }

  // ── Wanted and unavailable ────────────────────────────────────────────
  //
  // Last because it is the most specific, and the most urgent: demand
  // arriving at something nobody can buy is spend the market is losing today.
  if (demandScore >= STOCKOUT_MIN_DEMAND && facts.stockUnits <= 0) {
    findings.push({
      code: MarketFinding.STOCKED_OUT,
      strength: clamp(round(demandScore)),
      evidence: { demandScore, liveProducts: facts.liveProducts, stockUnits: 0 },
    });
  }

  // Confidence is about how much traffic the reading rests on. A category
  // with nine views has an arithmetically valid tension and nothing anybody
  // should act on.
  const confidence = round(
    Math.min(1, (facts.views + facts.searches) / (norms.halfViews * 2)),
    2,
  );

  return {
    demandScore,
    supplyScore,
    conversionScore,
    competition,
    tension,
    priceIndexBps,
    confidence,
    findings: findings.sort((a, b) => b.strength - a.strength),
    components: {
      views: facts.views,
      searches: facts.searches,
      cartAdds: facts.cartAdds,
      favourites: facts.favourites,
      orders: facts.orders,
      units: facts.units,
      openNeeds: facts.openNeeds,
      liveProducts: facts.liveProducts,
      liveOffers: facts.liveOffers,
      stockUnits: facts.stockUnits,
      sellers: facts.sellers,
      growth: round(growth, 3),
      conversion: round(conversion, 4),
      medianPriceSyp: facts.medianPriceSyp,
    },
  };
}

/** Growth with a floor under the denominator, as everywhere else in Ohara. */
export function growthOf(recent: number, previous: number): number {
  const base = Math.max(previous, 3);
  return (recent - previous) / base;
}

/**
 * How promising a product is for a launch.
 *
 * Drops need a different question answered from the market readings above:
 * not "what is this aisle like" but "is this particular thing worth making an
 * event of". Newness counts, because a drop is a launch; demand counts,
 * because an event nobody wants is an embarrassment; and *proven* conversion
 * counts against it only when it has already had its chance — a product that
 * has been seen five hundred times and sold twice does not need a spotlight,
 * it needs a better price.
 */
export function launchPotential(input: {
  reading: MarketReading;
  ageDays: number;
  stockUnits: number;
}): number {
  const { reading, ageDays, stockUnits } = input;
  if (stockUnits <= 0) return 0;

  // Newness, halving over a fortnight.
  const newness = Math.pow(0.5, Math.max(0, ageDays) / 14) * 30;

  // Demand it already shows, and demand nobody is serving.
  const wanted = (reading.demandScore / 100) * 35;
  const gap = (clamp(reading.tension, 0, 100) / 100) * 20;

  // Rising is the strongest single reason to launch something now.
  const rising = reading.findings.some((f) => f.code === MarketFinding.RISING)
    ? 15
    : 0;

  // A product that has had attention and failed to convert is not a drop
  // candidate — an event would only spend more attention on the same problem.
  const proven = reading.findings.some(
    (f) => f.code === MarketFinding.WEAK_CONVERSION,
  )
    ? -25
    : 0;

  return clamp(round(newness + wanted + gap + rising + proven));
}
