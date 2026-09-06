/**
 * snake_case on the wire, Arabic rendered here.
 *
 * Two rules the rest of the codebase already follows and this module keeps.
 * Codes travel *alongside* their Arabic rather than instead of it: the client
 * needs the code to choose an icon and a route, and the sentence has to be
 * written where the weights live so a change to one cannot leave the other
 * describing arithmetic that no longer happens.
 */

import { SellerHealthBand } from '@prisma/client';
import { HEALTH_BAND_AR } from './intelligence.constants';
import {
  HealthAdvice,
  HealthDimension,
  SellerHealthResult,
} from './kernel/seller-health';
import {
  HealthAxis,
  PeerPosition,
  ProductAdvice,
  ProductHealthResult,
} from './kernel/product-health';
import {
  Opportunity,
  PriceTrend,
  RisingCategory,
  SellerUnmet,
  StockAlert,
} from './kernel/demand-radar';

const day = (d: Date): string => d.toISOString().slice(0, 10);

// ── Seller health ────────────────────────────────────────────────────────

export function serializeDimension(dimension: HealthDimension) {
  return {
    key: dimension.key,
    label: dimension.label,
    blurb: dimension.blurb,
    score: dimension.score,
    weight: dimension.weight,
    evidence: dimension.evidence,
    sample: dimension.sample,
    value: dimension.value,
    /// Whether this dimension is currently doing anything to her score. The
    /// screen greys these rather than hiding them: "not measured yet" is
    /// information, and a dimension that silently vanished would read as a
    /// bug.
    counted: dimension.weight > 0,
  };
}

export function serializeHealthAdvice(advice: HealthAdvice) {
  return {
    code: advice.code,
    dimension: advice.dimension,
    severity: advice.severity,
    gain_points: advice.gainPoints,
    ar: advice.ar,
  };
}

export function serializeSellerHealth(input: {
  result: SellerHealthResult;
  advice: HealthAdvice[];
  bandAr: string;
  momentum: number;
  windowDays: number;
}) {
  return {
    score: input.result.score,
    band: input.result.band,
    band_label: input.bandAr,
    /// A number she has not earned yet is not shown as a verdict.
    is_provisional: input.result.band === SellerHealthBand.BUILDING,
    confidence: input.result.confidence,
    momentum: input.momentum,
    window_days: input.windowDays,
    dimensions: input.result.dimensions.map(serializeDimension),
    weakest: input.result.weakest,
    advice: input.advice.map(serializeHealthAdvice),
  };
}

export function serializeHealthHistory(
  rows: ReadonlyArray<{
    day: Date;
    score: number;
    band: SellerHealthBand;
    confidence: number;
  }>,
) {
  return rows.map((row) => ({
    day: day(row.day),
    score: row.score,
    band: row.band,
    band_label: HEALTH_BAND_AR[row.band],
    confidence: row.confidence,
  }));
}

// ── Product health ───────────────────────────────────────────────────────

export function serializeAxis(axis: HealthAxis) {
  return {
    key: axis.key,
    label: axis.label,
    score: axis.score,
    weight: axis.weight,
    evidence: axis.evidence,
    counted: axis.weight > 0,
  };
}

export function serializePeers(peers: PeerPosition | null) {
  if (!peers) return null;
  return {
    peers: peers.peers,
    price_premium_bps: peers.pricePremiumBps,
    conversion: peers.conversion,
    median_conversion: peers.medianConversion,
    conversion_percentile: peers.conversionPercentile,
  };
}

export function serializeProductAdvice(advice: ProductAdvice) {
  return {
    code: advice.code,
    axis: advice.axis,
    severity: advice.severity,
    gain_points: advice.gainPoints,
    ar: advice.ar,
  };
}

export function serializeProductHealth(input: {
  product: { id: string; title: string; imageUrl: string | null };
  result: ProductHealthResult;
  advice: ProductAdvice[];
}) {
  return {
    product_id: input.product.id,
    title: input.product.title,
    image_url: input.product.imageUrl,
    score: input.result.score,
    confidence: input.result.confidence,
    axes: input.result.axes.map(serializeAxis),
    peers: serializePeers(input.result.peers),
    advice: input.advice.map(serializeProductAdvice),
  };
}

// ── Demand radar ─────────────────────────────────────────────────────────

export function serializeOpportunity(o: Opportunity) {
  return {
    code: o.code,
    score: o.score,
    ar: o.ar,
    category_id: o.categoryId ?? null,
    product_id: o.productId ?? null,
    term_key: o.termKey ?? null,
  };
}

export function serializeRising(row: RisingCategory) {
  return {
    category_id: row.categoryId,
    name: row.name,
    growth: row.growth,
    recent: row.recent,
    trend_score: row.trendScore,
    presence: row.presence,
    relevance: row.relevance,
  };
}

export function serializeUnmet(row: SellerUnmet) {
  return {
    term_key: row.termKey,
    display: row.display,
    searches: row.searches,
    zero_results: row.zeroResults,
    miss_rate: row.missRate,
    growth: row.growth,
    in_her_categories: row.inHerCategories,
    opportunity: row.opportunity,
    suggested_category_id: row.suggestedCategoryId,
    suggestion_ar: row.suggestionAr,
  };
}

export function serializeStockAlert(row: StockAlert) {
  return {
    product_id: row.productId,
    title: row.title,
    stock_units: row.stockUnits,
    cover_days: row.coverDays,
    demand_growth: row.demandGrowth,
    severity: row.severity,
    ar: row.ar,
  };
}

export function serializePriceTrend(row: PriceTrend) {
  return {
    category_id: row.categoryId,
    name: row.name,
    recent_median: row.recentMedian,
    change_bps: row.changeBps,
    seller_premium_bps: row.sellerPremiumBps,
    ar: row.ar,
  };
}

export function serializeRadar(data: {
  windowDays: number;
  asOf: Date;
  opportunities: Opportunity[];
  rising: RisingCategory[];
  unmet: SellerUnmet[];
  stockAlerts: StockAlert[];
  priceTrends: PriceTrend[];
  categoryCount: number;
}) {
  return {
    as_of: day(data.asOf),
    window_days: data.windowDays,
    category_count: data.categoryCount,
    opportunities: data.opportunities.map(serializeOpportunity),
    rising: data.rising.map(serializeRising),
    unmet: data.unmet.map(serializeUnmet),
    stock_alerts: data.stockAlerts.map(serializeStockAlert),
    price_trends: data.priceTrends.map(serializePriceTrend),
  };
}
