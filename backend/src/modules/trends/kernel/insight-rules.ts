/**
 * The rules that turn numbers into findings, and the Arabic that turns
 * findings into sentences.
 *
 * The two halves are separate on purpose, and the separation is the reason a
 * language model is safe to attach here at all:
 *
 *  - A **finding** is arithmetic. It has a kind, a subject, a severity, and
 *    the figures it was derived from. It is produced by a pure function from
 *    pre-computed scores, and it exists whether or not anything can phrase it.
 *  - A **rendering** is prose. `render()` below is the fallback and the
 *    reference: correct Arabic, every number taken from the finding. Claude,
 *    when configured, replaces the prose and nothing else — it is handed the
 *    finding and returns two strings, and if it returns anything unusable the
 *    template output is what ships.
 *
 * So the worst case for a model outage, a bad prompt or a hallucinated verb is
 * a duller sentence. It is never a wrong number, and never an insight that
 * should not have fired.
 */

import {
  TrendInsightAudience,
  TrendInsightKind,
  TrendInsightSeverity,
  TrendStage,
  TrendSubjectKind,
} from '@prisma/client';
import { clamp, round } from './trend-math';
import { STAGE_LABELS_AR, TrendScoreResult } from './trend-score';

// ─────────────────────────── The finding ───────────────────────────

export interface InsightFinding {
  kind: TrendInsightKind;
  audience: TrendInsightAudience;
  severity: TrendInsightSeverity;
  subjectKind: TrendSubjectKind;
  subjectKey: string;
  /** What to call the subject in the sentence. */
  subjectLabel: string;
  productId?: string;
  categoryId?: string;
  sellerId?: string;
  /** Everything the sentence is allowed to quote. */
  metrics: Record<string, number | string | boolean | null>;
  confidence: number;
  priority: number;
  dedupeKey: string;
  /** A route hint for the app: `product`, `category`, `search`, `inventory`. */
  actionTarget?: string;
}

export interface RenderedInsight {
  titleAr: string;
  bodyAr: string;
  actionAr: string | null;
}

const SEVERITY_WEIGHT: Record<TrendInsightSeverity, number> = {
  [TrendInsightSeverity.INFO]: 0.4,
  [TrendInsightSeverity.OPPORTUNITY]: 0.75,
  [TrendInsightSeverity.WARNING]: 0.85,
  [TrendInsightSeverity.CRITICAL]: 1,
};

/**
 * How the feed is ordered.
 *
 * Severity alone would put every stock warning above every opportunity;
 * confidence alone would bury a brand-new signal. The product of the three,
 * with magnitude normalised by the caller into 0–1, is what makes "your best
 * product sells out on Thursday" beat "this colour is up nine percent" without
 * a hand-maintained list.
 */
export function priorityOf(
  severity: TrendInsightSeverity,
  confidence: number,
  magnitude: number,
): number {
  return round(
    SEVERITY_WEIGHT[severity] * (0.3 + 0.7 * clamp(confidence)) * clamp(magnitude),
    4,
  );
}

// ─────────────────────────── Rule inputs ───────────────────────────

export interface ProductRuleInput {
  productId: string;
  title: string;
  categoryId: string;
  categoryNameAr: string;
  /** Present for seller-audience findings; null makes them admin-only. */
  sellerId: string | null;
  windowDays: number;
  score: TrendScoreResult;
  previousScore: number | null;
  stockUnits: number;
  priceSyp: number | null;
  /** Median live price in the product's category, for the price comparison. */
  categoryMedianPriceSyp: number | null;
  /** Median view→order rate among category peers, for the conversion rule. */
  peerViewToOrderRate: number | null;
  forecast: {
    horizonDays: number;
    totalUnits: number;
    confidence: number;
    stockoutInDays: number | null;
  } | null;
}

export interface CategoryRuleInput {
  categoryId: string;
  nameAr: string;
  windowDays: number;
  score: TrendScoreResult;
  previousScore: number | null;
  /** Live products in the subtree, for the assortment-gap comparison. */
  liveProducts: number;
  inStockProducts: number;
}

export interface AttributeRuleInput {
  dimension: 'COLOR' | 'PRICE_BAND' | 'BRAND' | 'SIZE' | 'MATERIAL' | 'OCCASION';
  value: string;
  labelAr: string;
  scopeKey: string;
  scopeLabelAr: string | null;
  windowDays: number;
  current: number;
  previous: number;
  /** This value's share of its dimension now, and one window ago. */
  share: number;
  previousShare: number;
  orders: number;
}

export interface SearchRuleInput {
  termKey: string;
  display: string;
  facetSummary: string;
  windowDays: number;
  searches: number;
  previousSearches: number;
  zeroResults: number;
  missRate: number;
  clicks: number;
  orders: number;
  demandScore: number;
  suggestedCategoryId: string | null;
}

export interface SellerRuleInput {
  sellerId: string;
  displayName: string;
  windowDays: number;
  units: number;
  previousUnits: number;
  revenueSyp: number;
  previousRevenueSyp: number;
  cancelRate: number;
  returnRate: number;
  risingProducts: number;
  decliningProducts: number;
}

// ─────────────────────────── Product rules ───────────────────────────

/**
 * Every finding one product's numbers support.
 *
 * The rules are written to be *quiet*. Each has a volume floor as well as a
 * ratio test, because the failure mode of an insight feed is not missing a
 * signal — it is fifty rows a morning, at which point nobody reads any of
 * them and the whole feature is off even though it is running.
 */
export function productFindings(input: ProductRuleInput): InsightFinding[] {
  const findings: InsightFinding[] = [];
  const { score, title, productId, sellerId } = input;
  const m = score.metrics;
  const audience = sellerId
    ? TrendInsightAudience.SELLER
    : TrendInsightAudience.ADMIN;
  const delta =
    input.previousScore === null ? null : round(score.score - input.previousScore, 2);

  const base = {
    audience,
    subjectKind: TrendSubjectKind.PRODUCT,
    subjectKey: productId,
    subjectLabel: title,
    productId,
    categoryId: input.categoryId,
    ...(sellerId ? { sellerId } : {}),
    actionTarget: 'product',
  } as const;

  const key = (kind: TrendInsightKind) =>
    `${audience}:${sellerId ?? 'platform'}:${kind}:${productId}:${input.windowDays}`;

  // ── Early signal. The reason the engine exists. ──────────────────────
  if (score.stage === TrendStage.EMERGING && score.confidence >= 0.2) {
    findings.push({
      ...base,
      kind: TrendInsightKind.EMERGING_PRODUCT,
      severity: TrendInsightSeverity.OPPORTUNITY,
      metrics: {
        score: score.score,
        stage: score.stage,
        views: m.views,
        previous_views: m.previousViews,
        cart_adds: m.cartAdds,
        previous_cart_adds: m.previousCartAdds,
        units: m.units,
        window_days: input.windowDays,
        view_growth_pct: growthPct(m.views, m.previousViews),
        cart_growth_pct: growthPct(m.cartAdds, m.previousCartAdds),
      },
      confidence: score.confidence,
      priority: priorityOf(
        TrendInsightSeverity.OPPORTUNITY,
        score.confidence,
        clamp(score.components.acceleration + 0.3),
      ),
      dedupeKey: key(TrendInsightKind.EMERGING_PRODUCT),
    });
  }

  if (
    score.stage === TrendStage.RISING &&
    delta !== null &&
    delta >= 5 &&
    score.confidence >= 0.3
  ) {
    findings.push({
      ...base,
      kind: TrendInsightKind.RISING_DEMAND,
      severity: TrendInsightSeverity.OPPORTUNITY,
      metrics: {
        score: score.score,
        previous_score: input.previousScore,
        delta,
        views: m.views,
        view_growth_pct: growthPct(m.views, m.previousViews),
        units: m.units,
        units_growth_pct: growthPct(m.units, m.previousUnits),
        window_days: input.windowDays,
      },
      confidence: score.confidence,
      priority: priorityOf(
        TrendInsightSeverity.OPPORTUNITY,
        score.confidence,
        clamp(delta / 30),
      ),
      dedupeKey: key(TrendInsightKind.RISING_DEMAND),
    });
  }

  if (
    score.stage === TrendStage.DECLINING &&
    delta !== null &&
    delta <= -6 &&
    score.confidence >= 0.35
  ) {
    findings.push({
      ...base,
      kind: TrendInsightKind.DECLINING_DEMAND,
      severity: TrendInsightSeverity.WARNING,
      metrics: {
        score: score.score,
        previous_score: input.previousScore,
        delta,
        views: m.views,
        view_growth_pct: growthPct(m.views, m.previousViews),
        units: m.units,
        window_days: input.windowDays,
      },
      confidence: score.confidence,
      priority: priorityOf(
        TrendInsightSeverity.WARNING,
        score.confidence,
        clamp(Math.abs(delta) / 30),
      ),
      dedupeKey: key(TrendInsightKind.DECLINING_DEMAND),
    });
  }

  // ── Attention that is not converting ─────────────────────────────────
  if (m.views >= 60 && m.orders === 0) {
    findings.push({
      ...base,
      kind: TrendInsightKind.HIGH_VIEW_NO_SALES,
      severity: TrendInsightSeverity.WARNING,
      metrics: {
        views: m.views,
        cart_adds: m.cartAdds,
        orders: 0,
        in_stock_rate: m.inStockRate,
        price_syp: input.priceSyp,
        window_days: input.windowDays,
      },
      confidence: clamp(m.views / (m.views + 80)),
      priority: priorityOf(
        TrendInsightSeverity.WARNING,
        clamp(m.views / (m.views + 80)),
        clamp(m.views / 300),
      ),
      dedupeKey: key(TrendInsightKind.HIGH_VIEW_NO_SALES),
    });
  } else if (
    m.views >= 80 &&
    input.peerViewToOrderRate !== null &&
    input.peerViewToOrderRate > 0 &&
    m.viewToOrderRate < input.peerViewToOrderRate * 0.5
  ) {
    findings.push({
      ...base,
      kind: TrendInsightKind.LOW_CONVERSION,
      severity: TrendInsightSeverity.WARNING,
      metrics: {
        views: m.views,
        orders: m.orders,
        view_to_order_rate: m.viewToOrderRate,
        peer_view_to_order_rate: round(input.peerViewToOrderRate, 4),
        gap_pct: round(
          (1 - m.viewToOrderRate / input.peerViewToOrderRate) * 100,
          1,
        ),
        category: input.categoryNameAr,
        window_days: input.windowDays,
      },
      confidence: clamp(m.views / (m.views + 120)),
      priority: priorityOf(
        TrendInsightSeverity.WARNING,
        clamp(m.views / (m.views + 120)),
        clamp(1 - m.viewToOrderRate / input.peerViewToOrderRate),
      ),
      dedupeKey: key(TrendInsightKind.LOW_CONVERSION),
    });
  }

  if (m.cartAdds >= 15 && m.cartToOrderRate < 0.15) {
    findings.push({
      ...base,
      kind: TrendInsightKind.CART_ABANDONMENT,
      severity: TrendInsightSeverity.WARNING,
      metrics: {
        cart_adds: m.cartAdds,
        orders: m.orders,
        cart_to_order_rate: m.cartToOrderRate,
        abandoned: Math.max(0, m.cartAdds - m.orders),
        window_days: input.windowDays,
      },
      confidence: clamp(m.cartAdds / (m.cartAdds + 25)),
      priority: priorityOf(
        TrendInsightSeverity.WARNING,
        clamp(m.cartAdds / (m.cartAdds + 25)),
        clamp(1 - m.cartToOrderRate / 0.25),
      ),
      dedupeKey: key(TrendInsightKind.CART_ABANDONMENT),
      actionTarget: 'checkout',
    });
  }

  // ── Stock against demand ─────────────────────────────────────────────
  const stockout = input.forecast?.stockoutInDays ?? null;
  if (
    stockout !== null &&
    stockout <= 7 &&
    m.unitsPerDay > 0 &&
    (input.forecast?.confidence ?? 0) >= 0.25
  ) {
    const critical = stockout <= 3;
    findings.push({
      ...base,
      kind: TrendInsightKind.STOCK_RISK,
      severity: critical
        ? TrendInsightSeverity.CRITICAL
        : TrendInsightSeverity.WARNING,
      metrics: {
        stock_units: input.stockUnits,
        stockout_in_days: stockout,
        units_per_day: m.unitsPerDay,
        forecast_units: input.forecast?.totalUnits ?? null,
        horizon_days: input.forecast?.horizonDays ?? null,
        window_days: input.windowDays,
      },
      confidence: input.forecast?.confidence ?? 0.4,
      priority: priorityOf(
        critical ? TrendInsightSeverity.CRITICAL : TrendInsightSeverity.WARNING,
        input.forecast?.confidence ?? 0.4,
        clamp(1 - stockout / 10),
      ),
      dedupeKey: key(TrendInsightKind.STOCK_RISK),
      actionTarget: 'inventory',
    });
  } else if (
    input.stockUnits === 0 &&
    (score.stage === TrendStage.RISING || score.stage === TrendStage.EMERGING) &&
    m.views >= 30
  ) {
    findings.push({
      ...base,
      kind: TrendInsightKind.STOCK_OPPORTUNITY,
      severity: TrendInsightSeverity.OPPORTUNITY,
      metrics: {
        stock_units: 0,
        views: m.views,
        cart_adds: m.cartAdds,
        view_growth_pct: growthPct(m.views, m.previousViews),
        stage: score.stage,
        window_days: input.windowDays,
      },
      confidence: score.confidence,
      priority: priorityOf(
        TrendInsightSeverity.OPPORTUNITY,
        score.confidence,
        clamp(m.views / 200),
      ),
      dedupeKey: key(TrendInsightKind.STOCK_OPPORTUNITY),
      actionTarget: 'inventory',
    });
  } else if (
    m.daysOfCover !== null &&
    m.daysOfCover > 90 &&
    input.stockUnits >= 10 &&
    (score.stage === TrendStage.DECLINING || score.stage === TrendStage.COOLING)
  ) {
    findings.push({
      ...base,
      kind: TrendInsightKind.OVERSTOCK,
      severity: TrendInsightSeverity.INFO,
      metrics: {
        stock_units: input.stockUnits,
        days_of_cover: m.daysOfCover,
        units_per_day: m.unitsPerDay,
        stage: score.stage,
        window_days: input.windowDays,
      },
      confidence: score.confidence,
      priority: priorityOf(
        TrendInsightSeverity.INFO,
        score.confidence,
        clamp(m.daysOfCover / 365),
      ),
      dedupeKey: key(TrendInsightKind.OVERSTOCK),
      actionTarget: 'inventory',
    });
  }

  // ── Quality ──────────────────────────────────────────────────────────
  if (m.units >= 10 && m.returnRate >= 0.2) {
    findings.push({
      ...base,
      kind: TrendInsightKind.RETURN_RISK,
      severity: TrendInsightSeverity.WARNING,
      metrics: {
        units: m.units,
        returns: m.returns,
        return_rate: m.returnRate,
        window_days: input.windowDays,
      },
      confidence: clamp(m.units / (m.units + 20)),
      priority: priorityOf(
        TrendInsightSeverity.WARNING,
        clamp(m.units / (m.units + 20)),
        clamp(m.returnRate / 0.5),
      ),
      dedupeKey: key(TrendInsightKind.RETURN_RISK),
    });
  }

  if (m.reviews >= 5 && m.averageRating > 0 && m.averageRating < 3.2) {
    findings.push({
      ...base,
      kind: TrendInsightKind.RATING_RISK,
      severity: TrendInsightSeverity.WARNING,
      metrics: {
        reviews: m.reviews,
        average_rating: m.averageRating,
        window_days: input.windowDays,
      },
      confidence: clamp(m.reviews / (m.reviews + 10)),
      priority: priorityOf(
        TrendInsightSeverity.WARNING,
        clamp(m.reviews / (m.reviews + 10)),
        clamp((3.5 - m.averageRating) / 2.5),
      ),
      dedupeKey: key(TrendInsightKind.RATING_RISK),
    });
  }

  // ── Price ────────────────────────────────────────────────────────────
  if (
    input.priceSyp !== null &&
    input.categoryMedianPriceSyp !== null &&
    input.categoryMedianPriceSyp > 0 &&
    m.views >= 60 &&
    m.viewToCartRate < 0.03 &&
    input.priceSyp > input.categoryMedianPriceSyp * 1.35
  ) {
    const premium = round(
      (input.priceSyp / input.categoryMedianPriceSyp - 1) * 100,
      1,
    );
    findings.push({
      ...base,
      kind: TrendInsightKind.PRICE_OPPORTUNITY,
      severity: TrendInsightSeverity.OPPORTUNITY,
      metrics: {
        price_syp: input.priceSyp,
        category_median_price_syp: round(input.categoryMedianPriceSyp, 2),
        premium_pct: premium,
        views: m.views,
        view_to_cart_rate: m.viewToCartRate,
        category: input.categoryNameAr,
        window_days: input.windowDays,
      },
      confidence: clamp(m.views / (m.views + 100)),
      priority: priorityOf(
        TrendInsightSeverity.OPPORTUNITY,
        clamp(m.views / (m.views + 100)),
        clamp(premium / 100),
      ),
      dedupeKey: key(TrendInsightKind.PRICE_OPPORTUNITY),
      actionTarget: 'pricing',
    });
  }

  // ── Forecast ─────────────────────────────────────────────────────────
  if (
    input.forecast &&
    input.forecast.confidence >= 0.4 &&
    m.units > 0 &&
    input.forecast.totalUnits >= m.units * 1.5 &&
    input.forecast.totalUnits >= 5
  ) {
    findings.push({
      ...base,
      kind: TrendInsightKind.FORECAST_SPIKE,
      severity: TrendInsightSeverity.OPPORTUNITY,
      metrics: {
        forecast_units: round(input.forecast.totalUnits, 1),
        horizon_days: input.forecast.horizonDays,
        units: m.units,
        window_days: input.windowDays,
        uplift_pct: growthPct(input.forecast.totalUnits, m.units),
      },
      confidence: input.forecast.confidence,
      priority: priorityOf(
        TrendInsightSeverity.OPPORTUNITY,
        input.forecast.confidence,
        clamp(input.forecast.totalUnits / (m.units * 3 + 1)),
      ),
      dedupeKey: key(TrendInsightKind.FORECAST_SPIKE),
      actionTarget: 'inventory',
    });
  }

  return findings;
}

// ─────────────────────────── Category rules ───────────────────────────

export function categoryFindings(input: CategoryRuleInput): InsightFinding[] {
  const findings: InsightFinding[] = [];
  const { score } = input;
  const m = score.metrics;
  const delta =
    input.previousScore === null ? null : round(score.score - input.previousScore, 2);

  const base = {
    audience: TrendInsightAudience.ADMIN,
    subjectKind: TrendSubjectKind.CATEGORY,
    subjectKey: input.categoryId,
    subjectLabel: input.nameAr,
    categoryId: input.categoryId,
    actionTarget: 'category',
  } as const;
  const key = (kind: TrendInsightKind) =>
    `ADMIN:platform:${kind}:${input.categoryId}:${input.windowDays}`;

  const rising =
    score.stage === TrendStage.RISING || score.stage === TrendStage.EMERGING;
  if (rising && score.confidence >= 0.3) {
    findings.push({
      ...base,
      kind: TrendInsightKind.CATEGORY_MOMENTUM,
      severity: TrendInsightSeverity.OPPORTUNITY,
      metrics: {
        score: score.score,
        delta,
        views: m.views,
        view_growth_pct: growthPct(m.views, m.previousViews),
        units: m.units,
        units_growth_pct: growthPct(m.units, m.previousUnits),
        live_products: input.liveProducts,
        window_days: input.windowDays,
      },
      confidence: score.confidence,
      priority: priorityOf(
        TrendInsightSeverity.OPPORTUNITY,
        score.confidence,
        clamp(score.components.viewGrowth),
      ),
      dedupeKey: key(TrendInsightKind.CATEGORY_MOMENTUM),
    });
  }

  if (
    score.stage === TrendStage.DECLINING &&
    delta !== null &&
    delta <= -5 &&
    score.confidence >= 0.4
  ) {
    findings.push({
      ...base,
      kind: TrendInsightKind.DECLINING_DEMAND,
      severity: TrendInsightSeverity.WARNING,
      metrics: {
        score: score.score,
        delta,
        views: m.views,
        view_growth_pct: growthPct(m.views, m.previousViews),
        units: m.units,
        window_days: input.windowDays,
      },
      confidence: score.confidence,
      priority: priorityOf(
        TrendInsightSeverity.WARNING,
        score.confidence,
        clamp(Math.abs(delta) / 25),
      ),
      dedupeKey: key(TrendInsightKind.DECLINING_DEMAND),
    });
  }

  // Demand that the shelf cannot answer: interest is climbing and most of the
  // subtree is out of stock.
  const inStockRate = input.liveProducts
    ? input.inStockProducts / input.liveProducts
    : 1;
  if (rising && inStockRate < 0.55 && input.liveProducts >= 5) {
    findings.push({
      ...base,
      kind: TrendInsightKind.ASSORTMENT_GAP,
      severity: TrendInsightSeverity.OPPORTUNITY,
      metrics: {
        live_products: input.liveProducts,
        in_stock_products: input.inStockProducts,
        in_stock_rate: round(inStockRate, 3),
        views: m.views,
        view_growth_pct: growthPct(m.views, m.previousViews),
        window_days: input.windowDays,
      },
      confidence: score.confidence,
      priority: priorityOf(
        TrendInsightSeverity.OPPORTUNITY,
        score.confidence,
        clamp(1 - inStockRate),
      ),
      dedupeKey: key(TrendInsightKind.ASSORTMENT_GAP),
    });
  }

  return findings;
}

// ─────────────────────────── Attribute rules ───────────────────────────

/**
 * A colour or a price band moving.
 *
 * The test is on *share*, not on volume: on a week when the whole platform is
 * busy every colour is up, and "black is up 40%" is then a fact about the week
 * rather than about black. A shift in share is the thing a buyer can act on.
 */
export function attributeFindings(input: AttributeRuleInput): InsightFinding[] {
  const shareDelta = round((input.share - input.previousShare) * 100, 2);
  const volume = input.current + input.previous;
  if (volume < 40 || Math.abs(shareDelta) < 4) return [];

  const kind =
    input.dimension === 'PRICE_BAND'
      ? TrendInsightKind.PRICE_BAND_SHIFT
      : input.dimension === 'COLOR'
        ? TrendInsightKind.COLOR_MOMENTUM
        : TrendInsightKind.RISING_DEMAND;

  const confidence = clamp(volume / (volume + 200));
  const severity =
    shareDelta > 0
      ? TrendInsightSeverity.OPPORTUNITY
      : TrendInsightSeverity.INFO;

  return [
    {
      kind,
      audience: TrendInsightAudience.ADMIN,
      severity,
      subjectKind: TrendSubjectKind.ATTRIBUTE,
      subjectKey: `${input.dimension}:${input.value}:${input.scopeKey}`,
      subjectLabel: input.labelAr,
      metrics: {
        dimension: input.dimension,
        value: input.value,
        scope: input.scopeLabelAr,
        current: input.current,
        previous: input.previous,
        growth_pct: growthPct(input.current, input.previous),
        share_pct: round(input.share * 100, 2),
        previous_share_pct: round(input.previousShare * 100, 2),
        share_delta_pct: shareDelta,
        orders: input.orders,
        window_days: input.windowDays,
      },
      confidence,
      priority: priorityOf(severity, confidence, clamp(Math.abs(shareDelta) / 20)),
      dedupeKey: `ADMIN:platform:${kind}:${input.dimension}:${input.value}:${input.scopeKey}:${input.windowDays}`,
      actionTarget: 'attribute',
    },
  ];
}

// ─────────────────────────── Search rules ───────────────────────────

export function searchFindings(input: SearchRuleInput): InsightFinding[] {
  const findings: InsightFinding[] = [];
  const base = {
    audience: TrendInsightAudience.ADMIN,
    subjectKind: TrendSubjectKind.SEARCH_TERM,
    subjectKey: input.termKey,
    subjectLabel: input.display,
    ...(input.suggestedCategoryId ? { categoryId: input.suggestedCategoryId } : {}),
    actionTarget: 'search',
  } as const;

  if (input.searches >= 8 && input.missRate >= 0.45) {
    const severity =
      input.searches >= 40
        ? TrendInsightSeverity.CRITICAL
        : TrendInsightSeverity.OPPORTUNITY;
    const confidence = clamp(input.searches / (input.searches + 20));
    findings.push({
      ...base,
      kind: TrendInsightKind.UNMET_DEMAND,
      severity,
      metrics: {
        term: input.display,
        facets: input.facetSummary,
        searches: input.searches,
        zero_results: input.zeroResults,
        miss_rate: round(input.missRate, 3),
        demand_score: round(input.demandScore, 1),
        window_days: input.windowDays,
      },
      confidence,
      priority: priorityOf(severity, confidence, clamp(input.demandScore / 100)),
      dedupeKey: `ADMIN:platform:UNMET_DEMAND:${input.termKey}:${input.windowDays}`,
    });
  }

  if (input.searches >= 25 && input.previousSearches > 0) {
    const growth = input.searches / input.previousSearches;
    if (growth >= 2) {
      const confidence = clamp(input.searches / (input.searches + 40));
      findings.push({
        ...base,
        kind: TrendInsightKind.SEARCH_SURGE,
        severity: TrendInsightSeverity.OPPORTUNITY,
        metrics: {
          term: input.display,
          facets: input.facetSummary,
          searches: input.searches,
          previous_searches: input.previousSearches,
          growth_pct: growthPct(input.searches, input.previousSearches),
          miss_rate: round(input.missRate, 3),
          orders: input.orders,
          window_days: input.windowDays,
        },
        confidence,
        priority: priorityOf(
          TrendInsightSeverity.OPPORTUNITY,
          confidence,
          clamp((growth - 1) / 4),
        ),
        dedupeKey: `ADMIN:platform:SEARCH_SURGE:${input.termKey}:${input.windowDays}`,
      });
    }
  }

  return findings;
}

// ─────────────────────────── Seller rules ───────────────────────────

export function sellerFindings(input: SellerRuleInput): InsightFinding[] {
  if (input.units + input.previousUnits < 10) return [];
  const growth = growthPct(input.units, input.previousUnits);
  const notable = Math.abs(growth) >= 25 || input.cancelRate >= 0.15;
  if (!notable) return [];

  const severity =
    input.cancelRate >= 0.15
      ? TrendInsightSeverity.WARNING
      : growth > 0
        ? TrendInsightSeverity.OPPORTUNITY
        : TrendInsightSeverity.INFO;
  const confidence = clamp(
    (input.units + input.previousUnits) / (input.units + input.previousUnits + 30),
  );

  return [
    {
      kind: TrendInsightKind.SELLER_PERFORMANCE,
      audience: TrendInsightAudience.ADMIN,
      severity,
      subjectKind: TrendSubjectKind.SELLER,
      subjectKey: input.sellerId,
      subjectLabel: input.displayName,
      metrics: {
        units: input.units,
        previous_units: input.previousUnits,
        growth_pct: growth,
        revenue_syp: round(input.revenueSyp, 2),
        cancel_rate: round(input.cancelRate, 3),
        return_rate: round(input.returnRate, 3),
        rising_products: input.risingProducts,
        declining_products: input.decliningProducts,
        window_days: input.windowDays,
      },
      confidence,
      priority: priorityOf(severity, confidence, clamp(Math.abs(growth) / 100)),
      dedupeKey: `ADMIN:platform:SELLER_PERFORMANCE:${input.sellerId}:${input.windowDays}`,
      actionTarget: 'seller',
    },
  ];
}

// ─────────────────────────── Rendering ───────────────────────────

/**
 * The Arabic. Always available, always correct, always the fallback.
 *
 * Every number in every sentence is read straight out of `finding.metrics`, so
 * a template and a model rendering of the same finding cannot disagree about
 * the facts — only about the wording.
 */
export function render(finding: InsightFinding): RenderedInsight {
  const m = finding.metrics;
  const n = (key: string): number => {
    const value = m[key];
    return typeof value === 'number' ? value : 0;
  };
  const s = (key: string): string => {
    const value = m[key];
    return value === null || value === undefined ? '' : String(value);
  };
  const days = n('window_days') || 7;
  const subject = finding.subjectLabel;

  switch (finding.kind) {
    case TrendInsightKind.EMERGING_PRODUCT:
      return {
        titleAr: `منتج صاعد مبكرًا: ${subject}`,
        bodyAr:
          `ارتفعت مشاهدات «${subject}» بنسبة ${pct(n('view_growth_pct'))} ` +
          `وإضافات السلة بنسبة ${pct(n('cart_growth_pct'))} خلال آخر ${arDays(days)}، ` +
          `بينما لا تزال المبيعات عند ${count(n('units'))} قطعة فقط. ` +
          `هذا هو نمط المنتج الذي يصبح الأكثر مبيعًا لاحقًا.`,
        actionAr: 'جهّزي المخزون وأبرزي المنتج قبل أن يتشبّع الطلب.',
      };

    case TrendInsightKind.RISING_DEMAND:
      return {
        titleAr: `الطلب يتصاعد على ${subject}`,
        bodyAr:
          `ارتفع مؤشر الترند إلى ${score(n('score'))} من ${score(n('previous_score'))} ` +
          `خلال آخر ${arDays(days)}، بنمو ${pct(n('view_growth_pct'))} في المشاهدات ` +
          `و${pct(n('units_growth_pct'))} في المبيعات.`,
        actionAr: 'حافظي على توفر المخزون واستفيدي من الزخم الحالي.',
      };

    case TrendInsightKind.DECLINING_DEMAND:
      return {
        titleAr: `تراجع الطلب على ${subject}`,
        bodyAr:
          `انخفض مؤشر الترند من ${score(n('previous_score'))} إلى ${score(n('score'))} ` +
          `خلال آخر ${arDays(days)}، مع تغيّر ${pct(n('view_growth_pct'))} في المشاهدات.`,
        actionAr: 'راجعي السعر والصور، أو خطّطي لتصريف المخزون المتبقي.',
      };

    case TrendInsightKind.HIGH_VIEW_NO_SALES:
      return {
        titleAr: `مشاهدات عالية بلا مبيعات: ${subject}`,
        bodyAr:
          `حصل «${subject}» على ${count(n('views'))} مشاهدة خلال آخر ${arDays(days)} ` +
          `دون أي طلب واحد، مع ${count(n('cart_adds'))} إضافة للسلة. ` +
          `الاهتمام موجود والمشكلة في ما بعد المشاهدة.`,
        actionAr: 'راجعي السعر، وضوح الصور، ومعلومات المقاسات والتوفر.',
      };

    case TrendInsightKind.LOW_CONVERSION:
      return {
        titleAr: `معدل تحويل منخفض: ${subject}`,
        bodyAr:
          `يحوّل «${subject}» ${pctRate(n('view_to_order_rate'))} من مشاهداته إلى طلبات، ` +
          `مقابل ${pctRate(n('peer_view_to_order_rate'))} لمنتجات مشابهة في ${s('category')}؛ ` +
          `أي أقل بـ${pct(n('gap_pct'))} من متوسط الفئة رغم ${count(n('views'))} مشاهدة.`,
        actionAr: 'قارني السعر والصور مع المنتجات الأعلى تحويلًا في الفئة نفسها.',
      };

    case TrendInsightKind.CART_ABANDONMENT:
      return {
        titleAr: `سلات متروكة: ${subject}`,
        bodyAr:
          `أُضيف «${subject}» إلى السلة ${count(n('cart_adds'))} مرة خلال آخر ${arDays(days)} ` +
          `ولم يكتمل سوى ${count(n('orders'))} طلب — ${count(n('abandoned'))} سلة متروكة.`,
        actionAr: 'تحقّقي من تكلفة التوصيل ومدة التجهيز، فهما أكثر سببين للترك.',
      };

    case TrendInsightKind.STOCK_RISK:
      return {
        titleAr: `المخزون على وشك النفاد: ${subject}`,
        bodyAr:
          `يتبقى ${count(n('stock_units'))} قطعة من «${subject}»، ` +
          `ومعدل البيع ${decimal(n('units_per_day'))} قطعة يوميًا — ` +
          `أي نفاد خلال ${decimal(n('stockout_in_days'))} يوم تقريبًا. ` +
          `التوقّع لـ${arDays(n('horizon_days'))} القادمة هو ${decimal(n('forecast_units'))} قطعة.`,
        actionAr: 'أعيدي التوريد الآن؛ الطلب قائم والمخزون هو القيد الوحيد.',
      };

    case TrendInsightKind.STOCK_OPPORTUNITY:
      return {
        titleAr: `طلب قائم ومخزون صفر: ${subject}`,
        bodyAr:
          `«${subject}» نفد من المخزون بينما مشاهداته ${count(n('views'))} ` +
          `ونموّها ${pct(n('view_growth_pct'))} خلال آخر ${arDays(days)}. ` +
          `كل مشاهدة الآن هي عملية بيع ضائعة.`,
        actionAr: 'أعيدي توفير الكمية، أو اعرضي بديلًا مشابهًا في نفس الصفحة.',
      };

    case TrendInsightKind.OVERSTOCK:
      return {
        titleAr: `مخزون راكد: ${subject}`,
        bodyAr:
          `يكفي مخزون «${subject}» الحالي (${count(n('stock_units'))} قطعة) ` +
          `لـ${decimal(n('days_of_cover'))} يومًا بمعدل البيع الحالي، والطلب في تراجع.`,
        actionAr: 'فكّري في عرض ترويجي أو حزمة لتحريك الكمية.',
      };

    case TrendInsightKind.RETURN_RISK:
      return {
        titleAr: `نسبة إرجاع مرتفعة: ${subject}`,
        bodyAr:
          `أُرجعت ${count(n('returns'))} من أصل ${count(n('units'))} قطعة مباعة ` +
          `(${pctRate(n('return_rate'))}) خلال آخر ${arDays(days)}.`,
        actionAr: 'راجعي دقّة المقاسات ومطابقة الصور للمنتج الفعلي.',
      };

    case TrendInsightKind.RATING_RISK:
      return {
        titleAr: `تقييم منخفض: ${subject}`,
        bodyAr:
          `متوسط تقييم «${subject}» هو ${decimal(n('average_rating'))} من ٥ ` +
          `عبر ${count(n('reviews'))} تقييمًا.`,
        actionAr: 'اقرئي التقييمات الأخيرة وردّي عليها؛ الرد المنشور يرفع الثقة.',
      };

    case TrendInsightKind.PRICE_OPPORTUNITY:
      return {
        titleAr: `السعر قد يكون العائق: ${subject}`,
        bodyAr:
          `سعر «${subject}» أعلى بـ${pct(n('premium_pct'))} من وسيط سعر ${s('category')}، ` +
          `ومع ${count(n('views'))} مشاهدة لم يتجاوز التحويل إلى السلة ${pctRate(n('view_to_cart_rate'))}.`,
        actionAr: 'جرّبي سعرًا أقرب إلى وسيط الفئة، أو وضّحي ما يبرّر الفارق.',
      };

    case TrendInsightKind.FORECAST_SPIKE:
      return {
        titleAr: `توقّع ارتفاع في الطلب: ${subject}`,
        bodyAr:
          `يتوقّع النموذج بيع ${decimal(n('forecast_units'))} قطعة من «${subject}» ` +
          `خلال ${arDays(n('horizon_days'))} القادمة، مقابل ${count(n('units'))} ` +
          `خلال آخر ${arDays(days)} — بارتفاع ${pct(n('uplift_pct'))}.`,
        actionAr: 'أمّني الكمية مسبقًا قبل بداية الارتفاع.',
      };

    case TrendInsightKind.CATEGORY_MOMENTUM:
      return {
        titleAr: `فئة صاعدة: ${subject}`,
        bodyAr:
          `الطلب على «${subject}» يتزايد بسرعة: ${pct(n('view_growth_pct'))} في المشاهدات ` +
          `و${pct(n('units_growth_pct'))} في المبيعات خلال آخر ${arDays(days)}، ` +
          `عبر ${count(n('live_products'))} منتجًا معروضًا.`,
        actionAr: 'وسّعي التشكيلة في هذه الفئة وأبرزيها في الصفحة الرئيسية.',
      };

    case TrendInsightKind.ASSORTMENT_GAP:
      return {
        titleAr: `طلب متزايد وتوفّر ناقص: ${subject}`,
        bodyAr:
          `${count(n('in_stock_products'))} فقط من أصل ${count(n('live_products'))} منتجًا ` +
          `في «${subject}» متوفرة فعليًا، بينما ارتفعت المشاهدات ${pct(n('view_growth_pct'))} ` +
          `خلال آخر ${arDays(days)}.`,
        actionAr: 'نبّهي البائعات في هذه الفئة، أو استقطبي بائعات جديدات لها.',
      };

    case TrendInsightKind.COLOR_MOMENTUM:
      return {
        titleAr: `اللون ${subject} في ارتفاع`,
        bodyAr:
          `ارتفع الاهتمام بـ«${subject}»${scopeSuffix(s('scope'))} بنسبة ${pct(n('growth_pct'))} ` +
          `خلال آخر ${arDays(days)}، وحصّته من الطلب انتقلت من ` +
          `${pct(n('previous_share_pct'))} إلى ${pct(n('share_pct'))}.`,
        actionAr: 'أبرزي هذا اللون في الواجهة وفي طلبات التوريد القادمة.',
      };

    case TrendInsightKind.PRICE_BAND_SHIFT:
      return {
        titleAr: `تحوّل في النطاق السعري: ${subject}`,
        bodyAr:
          `انتقلت حصّة النطاق «${subject}»${scopeSuffix(s('scope'))} من ` +
          `${pct(n('previous_share_pct'))} إلى ${pct(n('share_pct'))} من الطلب ` +
          `خلال آخر ${arDays(days)}.`,
        actionAr: 'هناك فرصة لإضافة منتجات أكثر ضمن هذا النطاق السعري.',
      };

    case TrendInsightKind.UNMET_DEMAND:
      return {
        titleAr: `طلب غير ملبّى: ${subject}`,
        bodyAr:
          `بحثت العميلات عن «${subject}» ${count(n('searches'))} مرة خلال آخر ${arDays(days)}، ` +
          `و${pctRate(n('miss_rate'))} من هذه العمليات لم تُرجع نتائج مناسبة` +
          `${s('facets') ? ` (${s('facets')})` : ''}.`,
        actionAr: 'هناك طلب واضح هنا ولا يوجد ما يقابله في التشكيلة الحالية.',
      };

    case TrendInsightKind.SEARCH_SURGE:
      return {
        titleAr: `ارتفاع مفاجئ في البحث: ${subject}`,
        bodyAr:
          `تضاعفت عمليات البحث عن «${subject}» إلى ${count(n('searches'))} ` +
          `مقابل ${count(n('previous_searches'))} في الفترة السابقة ` +
          `(${pct(n('growth_pct'))}) خلال آخر ${arDays(days)}.`,
        actionAr: 'تأكّدي من وجود نتائج قوية لهذا البحث قبل أن يهدأ الاهتمام.',
      };

    case TrendInsightKind.SELLER_PERFORMANCE:
      return {
        titleAr: `أداء البائعة: ${subject}`,
        bodyAr:
          `باعت «${subject}» ${count(n('units'))} قطعة خلال آخر ${arDays(days)} ` +
          `مقابل ${count(n('previous_units'))} في الفترة السابقة (${pct(n('growth_pct'))})، ` +
          `بنسبة إلغاء ${pctRate(n('cancel_rate'))} وإرجاع ${pctRate(n('return_rate'))}.`,
        actionAr: null,
      };

    default:
      return {
        titleAr: subject,
        bodyAr: `تغيّر ملحوظ في «${subject}» خلال آخر ${arDays(days)}.`,
        actionAr: null,
      };
  }
}

// ── Arabic number formatting ─────────────────────────────────────────────
//
// Western digits throughout. The app renders Arabic-Indic where the locale
// asks for it; a number formatted twice is a number formatted wrong.

function pct(value: number): string {
  const rounded = Math.round(value);
  return `${rounded > 0 ? '+' : ''}${rounded}٪`;
}

function pctRate(rate: number): string {
  return `${round(rate * 100, 1)}٪`;
}

function count(value: number): string {
  return String(Math.round(value));
}

function decimal(value: number): string {
  return String(round(value, 1));
}

function score(value: number): string {
  return String(round(value, 1));
}

function arDays(days: number): string {
  const n = Math.round(days);
  if (n === 1) return 'يوم';
  if (n === 2) return 'يومين';
  if (n <= 10) return `${n} أيام`;
  return `${n} يومًا`;
}

function scopeSuffix(scope: string): string {
  return scope && scope !== 'ALL' ? ` في ${scope}` : '';
}

/**
 * Percentage change, Laplace-smoothed so a jump from zero is a number and not
 * an infinity. Capped at 999 because "+41000٪" is not information.
 */
export function growthPct(current: number, previous: number): number {
  const cur = Math.max(0, Number.isFinite(current) ? current : 0);
  const prev = Math.max(0, Number.isFinite(previous) ? previous : 0);
  if (cur === 0 && prev === 0) return 0;
  const ratio = (cur + 1) / (prev + 1);
  return round(Math.max(-99, Math.min(999, (ratio - 1) * 100)), 1);
}

/** Exposed for the serializer, which labels a stage chip. */
export { STAGE_LABELS_AR };
