import {
  TrendAttributeDimension,
  TrendEngineRun,
  TrendInsight,
  TrendStage,
  UnmetDemandSignal,
} from '@prisma/client';
import { Money } from '../../common/money';
import { STAGE_LABELS_AR } from './kernel/trend-score';
import { SCORE_WEIGHTS } from './trend.constants';

/**
 * Everything the Trend Engine puts on the wire.
 *
 * Two conventions, both the platform's and both load-bearing:
 *
 *  - **snake_case keys**, because that is the contract every other module and
 *    the whole Flutter client already speak.
 *  - **money as `{ amount, currency }`**, never a bare number, so a figure
 *    cannot be rendered without its unit. Everything here is SYP because the
 *    fact tables normalise on the way in, but the shape says so out loud.
 *
 * The third convention is specific to this module: **every score travels with
 * its evidence.** A trend score is a judgement, and a judgement a seller
 * cannot take apart is one she is entitled to distrust — so the components,
 * the raw window figures and the confidence go out beside the number, and the
 * app can always show its working.
 */

const syp = (amount: number | null | undefined) =>
  amount === null || amount === undefined ? null : Money.of(amount, 'SYP').toJSON();

const iso = (date: Date | null | undefined) =>
  date ? date.toISOString() : null;

const day = (date: Date | null | undefined) =>
  date ? date.toISOString().slice(0, 10) : null;

// ── Score components ─────────────────────────────────────────────────────

export interface ComponentBag {
  viewGrowth: number;
  searchGrowth: number;
  cartGrowth: number;
  conversion: number;
  salesVelocity: number;
  acceleration: number;
  engagement: number;
  quality: number;
  availability: number;
}

/**
 * The breakdown, with each component's weight beside it.
 *
 * Shipping the weights rather than hard-coding them in the client is what
 * keeps the explanation honest across a kernel version bump: the app renders
 * whatever the server says the score was made of, so a re-weighting cannot
 * leave the UI quietly describing the old formula.
 */
export function serializeComponents(components: ComponentBag) {
  return [
    { key: 'view_growth', value: components.viewGrowth, weight: SCORE_WEIGHTS.viewGrowth, label_ar: 'نمو المشاهدات' },
    { key: 'search_growth', value: components.searchGrowth, weight: SCORE_WEIGHTS.searchGrowth, label_ar: 'نمو البحث' },
    { key: 'cart_growth', value: components.cartGrowth, weight: SCORE_WEIGHTS.cartGrowth, label_ar: 'نمو الإضافة للسلة' },
    { key: 'conversion', value: components.conversion, weight: SCORE_WEIGHTS.conversion, label_ar: 'معدل التحويل' },
    { key: 'sales_velocity', value: components.salesVelocity, weight: SCORE_WEIGHTS.salesVelocity, label_ar: 'سرعة البيع' },
    { key: 'acceleration', value: components.acceleration, weight: SCORE_WEIGHTS.acceleration, label_ar: 'تسارع الطلب' },
    { key: 'engagement', value: components.engagement, weight: SCORE_WEIGHTS.engagement, label_ar: 'التفاعل' },
    { key: 'quality', value: components.quality, weight: SCORE_WEIGHTS.quality, label_ar: 'جودة التقييمات' },
    { key: 'availability', value: components.availability, weight: SCORE_WEIGHTS.availability, label_ar: 'توفّر المخزون' },
  ];
}

export function serializeStage(stage: TrendStage) {
  return { key: stage, label_ar: STAGE_LABELS_AR[stage] };
}

// ── Products ─────────────────────────────────────────────────────────────

type SellerProductRow = {
  productId: string;
  title: string;
  slug: string;
  imageUrl: string | null;
  categoryId: string;
  categoryNameAr: string;
  capturedOn: Date;
  score: number;
  previousScore: number | null;
  delta: number;
  stage: TrendStage;
  confidence: number;
  rank: number | null;
  categoryRank: number | null;
  components: ComponentBag;
  views: number;
  previousViews: number;
  searchHits: number;
  cartAdds: number;
  favorites: number;
  viewToCartRate: number;
  cartToOrderRate: number;
  viewToOrderRate: number;
  myUnits: number;
  myOrders: number;
  myRevenueSyp: number;
  lifetimeUnits: number;
  returns: number;
  stockUnits: number;
  priceSyp: number | null;
  forecastUnits: number | null;
  forecastHorizonDays: number | null;
  forecastConfidence: number | null;
  stockoutInDays: number | null;
  alerts: Record<string, boolean>;
};

export function serializeSellerProduct(row: SellerProductRow) {
  return {
    product_id: row.productId,
    title: row.title,
    slug: row.slug,
    image_url: row.imageUrl,
    category_id: row.categoryId,
    category_name_ar: row.categoryNameAr,
    captured_on: day(row.capturedOn),

    trend_score: row.score,
    previous_score: row.previousScore,
    delta: row.delta,
    stage: serializeStage(row.stage),
    confidence: row.confidence,
    rank: row.rank,
    category_rank: row.categoryRank,
    components: serializeComponents(row.components),

    // Market-wide demand for the product…
    demand: {
      views: row.views,
      previous_views: row.previousViews,
      search_hits: row.searchHits,
      cart_adds: row.cartAdds,
      favorites: row.favorites,
      view_to_cart_rate: row.viewToCartRate,
      cart_to_order_rate: row.cartToOrderRate,
      view_to_order_rate: row.viewToOrderRate,
    },
    // …and what she personally sold.
    mine: {
      units: row.myUnits,
      orders: row.myOrders,
      revenue: syp(row.myRevenueSyp),
      lifetime_units: row.lifetimeUnits,
      returns: row.returns,
      stock_units: row.stockUnits,
      price: syp(row.priceSyp),
    },
    forecast: {
      units: row.forecastUnits,
      horizon_days: row.forecastHorizonDays,
      confidence: row.forecastConfidence,
      stockout_in_days: row.stockoutInDays,
    },
    alerts: {
      low_conversion: row.alerts.lowConversion ?? false,
      weak_cart_through: row.alerts.weakCartThrough ?? false,
      stock_risk: row.alerts.stockRisk ?? false,
      sold_out_with_demand: row.alerts.soldOutWithDemand ?? false,
      overstock: row.alerts.overstock ?? false,
    },
  };
}

type AdminProductRow = {
  productId: string;
  title: string;
  slug: string;
  imageUrl: string | null;
  categoryId: string;
  categoryNameAr: string;
  sellers: Array<{ id: string; name: string }>;
  score: number;
  previousScore: number | null;
  delta: number;
  stage: TrendStage;
  confidence: number;
  rank: number | null;
  categoryRank: number | null;
  views: number;
  viewsGrowthPct: number;
  searchHits: number;
  cartAdds: number;
  units: number;
  unitsGrowthPct: number;
  revenueSyp: number;
  viewToOrderRate: number;
  stockUnits: number;
  daysOfCover: number | null;
  components: ComponentBag;
};

export function serializeAdminProduct(row: AdminProductRow) {
  return {
    product_id: row.productId,
    title: row.title,
    slug: row.slug,
    image_url: row.imageUrl,
    category_id: row.categoryId,
    category_name_ar: row.categoryNameAr,
    sellers: row.sellers.map((seller) => ({ id: seller.id, name: seller.name })),
    trend_score: row.score,
    previous_score: row.previousScore,
    delta: row.delta,
    stage: serializeStage(row.stage),
    confidence: row.confidence,
    rank: row.rank,
    category_rank: row.categoryRank,
    views: row.views,
    views_growth_pct: row.viewsGrowthPct,
    search_hits: row.searchHits,
    cart_adds: row.cartAdds,
    units: row.units,
    units_growth_pct: row.unitsGrowthPct,
    revenue: syp(row.revenueSyp),
    view_to_order_rate: row.viewToOrderRate,
    stock_units: row.stockUnits,
    days_of_cover: row.daysOfCover,
    components: serializeComponents(row.components),
  };
}

// ── Categories and attributes ────────────────────────────────────────────

export function serializeCategoryTrend(row: {
  categoryId: string;
  nameAr: string;
  nameEn: string;
  slug: string;
  level: number;
  parentId: string | null;
  score: number;
  previousScore: number | null;
  delta: number;
  stage: TrendStage;
  confidence: number;
  rank: number | null;
  views: number;
  viewsGrowthPct: number;
  units: number;
  unitsGrowthPct: number;
  revenueSyp: number;
  liveProducts: number;
  inStockProducts: number;
  medianPriceSyp: number | null;
}) {
  return {
    category_id: row.categoryId,
    name_ar: row.nameAr,
    name_en: row.nameEn,
    slug: row.slug,
    level: row.level,
    parent_id: row.parentId,
    trend_score: row.score,
    previous_score: row.previousScore,
    delta: row.delta,
    stage: serializeStage(row.stage),
    confidence: row.confidence,
    rank: row.rank,
    views: row.views,
    views_growth_pct: row.viewsGrowthPct,
    units: row.units,
    units_growth_pct: row.unitsGrowthPct,
    revenue: syp(row.revenueSyp),
    live_products: row.liveProducts,
    in_stock_products: row.inStockProducts,
    median_price: syp(row.medianPriceSyp),
  };
}

export function serializeAttributeTrend(row: {
  dimension: TrendAttributeDimension;
  value: string;
  labelAr: string;
  scopeKey: string;
  views: number;
  cartAdds: number;
  orders: number;
  units: number;
  revenueSyp: number;
  products: number;
  demand: number;
  previousDemand: number;
  growthPct: number;
  sharePct: number;
  previousSharePct: number;
  shareDeltaPct: number;
  windowDays: number;
}) {
  return {
    dimension: row.dimension,
    value: row.value,
    label_ar: row.labelAr,
    scope_key: row.scopeKey,
    views: row.views,
    cart_adds: row.cartAdds,
    orders: row.orders,
    units: row.units,
    revenue: syp(row.revenueSyp),
    products: row.products,
    demand: row.demand,
    previous_demand: row.previousDemand,
    growth_pct: row.growthPct,
    // The two numbers that separate "this colour moved" from "everything did".
    share_pct: row.sharePct,
    previous_share_pct: row.previousSharePct,
    share_delta_pct: row.shareDeltaPct,
    window_days: row.windowDays,
  };
}

// ── Search intelligence ──────────────────────────────────────────────────

export function serializeSearchTerm(row: {
  termKey: string;
  display: string;
  facetSummary: string;
  searches: number;
  previousSearches: number;
  growth: number;
  zeroResults: number;
  missRate: number;
  averageResults: number;
  clicks: number;
  clickRate: number;
  orders: number;
  windowDays: number;
}) {
  return {
    term_key: row.termKey,
    display: row.display,
    facets_ar: row.facetSummary,
    searches: row.searches,
    previous_searches: row.previousSearches,
    growth: row.growth,
    zero_results: row.zeroResults,
    miss_rate: row.missRate,
    average_results: row.averageResults,
    clicks: row.clicks,
    click_rate: row.clickRate,
    orders: row.orders,
    window_days: row.windowDays,
  };
}

export function serializeUnmetDemand(
  row: UnmetDemandSignal & {
    suggestedCategory?: { id: string; nameAr: string; slug: string } | null;
  },
) {
  return {
    id: row.id,
    term_key: row.termKey,
    display: row.display,
    facets: row.facets,
    searches: row.searches,
    zero_results: row.zeroResults,
    clicks: row.clicks,
    orders: row.orders,
    miss_rate: row.missRate,
    demand_score: row.demandScore,
    growth: row.growth,
    suggested_category: row.suggestedCategory
      ? {
          id: row.suggestedCategory.id,
          name_ar: row.suggestedCategory.nameAr,
          slug: row.suggestedCategory.slug,
        }
      : null,
    suggestion_ar: row.suggestionAr,
    status: row.status,
    note: row.note,
    first_seen_at: iso(row.firstSeenAt),
    last_seen_at: iso(row.lastSeenAt),
  };
}

// ── Insights ─────────────────────────────────────────────────────────────

export function serializeInsight(
  row: TrendInsight & {
    product?: { id: string; title: string; slug: string } | null;
    category?: { id: string; nameAr: string; slug: string } | null;
  },
) {
  return {
    id: row.id,
    audience: row.audience,
    kind: row.kind,
    severity: row.severity,
    status: row.status,
    title_ar: row.titleAr,
    body_ar: row.bodyAr,
    action_ar: row.actionAr,
    action_target: row.actionTarget,
    subject: {
      kind: row.subjectKind,
      key: row.subjectKey,
      product: row.product
        ? { id: row.product.id, title: row.product.title, slug: row.product.slug }
        : null,
      category: row.category
        ? { id: row.category.id, name_ar: row.category.nameAr, slug: row.category.slug }
        : null,
    },
    // The evidence. Always present, so the app can show the numbers under the
    // sentence and a reader can check the claim rather than trust it.
    metrics: row.metrics,
    confidence: row.confidence,
    priority: row.priority,
    /// `reem-trend-templates-v1`, or the model that phrased this row.
    narrator: row.narrator,
    generated_on: day(row.generatedOn),
    expires_at: iso(row.expiresAt),
  };
}

// ── Forecast ─────────────────────────────────────────────────────────────

export function serializeForecast(row: {
  horizonDays: number;
  totalUnits: number;
  totalRevenueSyp: number;
  confidence: number;
  method?: string | null;
  backtestMae?: number | null;
  points: Array<{ date: string; units: number; low: number; high: number }>;
  generatedOn?: Date | null;
  products?: number;
}) {
  return {
    horizon_days: row.horizonDays,
    total_units: row.totalUnits,
    total_revenue: syp(row.totalRevenueSyp),
    confidence: row.confidence,
    method: row.method ?? null,
    backtest_mae: row.backtestMae ?? null,
    products: row.products ?? null,
    points: row.points.map((point) => ({
      date: point.date,
      units: point.units,
      low: point.low,
      high: point.high,
    })),
    generated_on: day(row.generatedOn ?? null),
  };
}

// ── Ops ──────────────────────────────────────────────────────────────────

export function serializeRun(run: TrendEngineRun) {
  return {
    id: run.id,
    kind: run.kind,
    status: run.status,
    from_day: day(run.fromDay),
    to_day: day(run.toDay),
    started_at: iso(run.startedAt),
    finished_at: iso(run.finishedAt),
    duration_ms: run.durationMs,
    rows_written: run.rowsWritten,
    stats: run.stats,
    error: run.error,
  };
}

export { syp as serializeSyp };
