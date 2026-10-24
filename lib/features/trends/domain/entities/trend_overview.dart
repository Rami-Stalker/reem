import 'package:ohara/core/shared/value_objects/money.dart';
import 'package:ohara/features/trends/domain/entities/trend_insight.dart';
import 'package:ohara/features/trends/domain/entities/trend_score.dart';

/// The two dashboards, and the forecast and series they are built from.

// ── Forecast ─────────────────────────────────────────────────────────────

class ForecastPoint {
  const ForecastPoint({
    required this.date,
    required this.units,
    required this.low,
    required this.high,
  });

  final DateTime date;
  final double units;
  final double low;
  final double high;
}

/// How much will sell, over a horizon.
///
/// [confidence] and [method] are shown rather than hidden. A forecast the
/// model itself does not believe should not be presented with the same
/// authority as one it does — and `INSUFFICIENT_DATA` is a real answer that
/// the UI is expected to say out loud rather than dress up as a zero.
class TrendForecast {
  const TrendForecast({
    required this.horizonDays,
    required this.totalUnits,
    required this.totalRevenue,
    required this.confidence,
    required this.method,
    required this.points,
    required this.generatedOn,
  });

  final int horizonDays;
  final double totalUnits;
  final Money? totalRevenue;

  /// 0–1.
  final double confidence;

  /// `HOLT_DAMPED`, `SEASONAL_NAIVE`, `MOVING_AVERAGE`, `INSUFFICIENT_DATA`.
  final String? method;
  final List<ForecastPoint> points;
  final DateTime? generatedOn;

  bool get hasData =>
      points.isNotEmpty && method != 'INSUFFICIENT_DATA' && totalUnits > 0;

  static const TrendForecast empty = TrendForecast(
    horizonDays: 0,
    totalUnits: 0,
    totalRevenue: null,
    confidence: 0,
    method: null,
    points: [],
    generatedOn: null,
  );
}

// ── Series ───────────────────────────────────────────────────────────────

/// One day on a chart.
class TrendSeriesPoint {
  const TrendSeriesPoint({
    required this.date,
    required this.units,
    required this.orders,
    required this.revenue,
    this.views = 0,
    this.searchHits = 0,
    this.cartAdds = 0,
  });

  final DateTime date;
  final int units;
  final int orders;
  final Money? revenue;
  final int views;
  final int searchHits;
  final int cartAdds;
}

// ── Overviews ────────────────────────────────────────────────────────────

/// The seller's headline row.
class SellerTrendHeadline {
  const SellerTrendHeadline({
    required this.units,
    required this.previousUnits,
    required this.revenue,
    required this.previousRevenue,
    required this.views,
    required this.averageScore,
    required this.risingProducts,
    required this.decliningProducts,
  });

  final int units;
  final int previousUnits;
  final Money? revenue;
  final Money? previousRevenue;
  final int views;
  final double averageScore;
  final int risingProducts;
  final int decliningProducts;

  static const SellerTrendHeadline empty = SellerTrendHeadline(
    units: 0,
    previousUnits: 0,
    revenue: null,
    previousRevenue: null,
    views: 0,
    averageScore: 0,
    risingProducts: 0,
    decliningProducts: 0,
  );
}

/// Interest in her shop, separately from what it sold.
///
/// The two are different questions and are routinely confused. A week where
/// views climbed and units did not is a conversion problem; a week where both
/// fell is a demand problem, and they call for opposite responses.
class DemandSignals {
  const DemandSignals({
    required this.views,
    required this.previousViews,
    required this.searchHits,
    required this.cartAdds,
    required this.favorites,
    required this.units,
  });

  final int views;
  final int previousViews;
  final int searchHits;
  final int cartAdds;
  final int favorites;
  final int units;

  static const DemandSignals empty = DemandSignals(
    views: 0,
    previousViews: 0,
    searchHits: 0,
    cartAdds: 0,
    favorites: 0,
    units: 0,
  );
}

class SellerTrendOverview {
  const SellerTrendOverview({
    required this.asOf,
    required this.window,
    required this.headline,
    required this.demandSignals,
    required this.trending,
    required this.emerging,
    required this.lowConversion,
    required this.stockOpportunities,
    required this.forecast,
    required this.series,
    required this.recommendedActions,
    required this.productCount,
  });

  final DateTime asOf;
  final TrendWindow window;
  final SellerTrendHeadline headline;
  final DemandSignals demandSignals;
  final List<SellerTrendProduct> trending;
  final List<SellerTrendProduct> emerging;
  final List<SellerTrendProduct> lowConversion;
  final List<SellerTrendProduct> stockOpportunities;
  final TrendForecast forecast;
  final List<TrendSeriesPoint> series;
  final List<TrendInsight> recommendedActions;
  final int productCount;

  /// True when the engine has run but found nothing to say about her shop yet
  /// — a new seller, or a quiet fortnight. Distinct from a failed load.
  bool get isEmpty =>
      productCount == 0 && trending.isEmpty && recommendedActions.isEmpty;
}

/// The platform's headline row.
class AdminTrendHeadline {
  const AdminTrendHeadline({
    required this.views,
    required this.viewsGrowthPct,
    required this.searches,
    required this.searchGrowthPct,
    required this.cartAdds,
    required this.cartGrowthPct,
    required this.orders,
    required this.ordersGrowthPct,
    required this.units,
    required this.revenue,
    required this.revenueGrowthPct,
    required this.viewToCartRate,
    required this.cartToOrderRate,
    required this.stages,
  });

  final int views;
  final double viewsGrowthPct;
  final int searches;
  final double searchGrowthPct;
  final int cartAdds;
  final double cartGrowthPct;
  final int orders;
  final double ordersGrowthPct;
  final int units;
  final Money? revenue;
  final double revenueGrowthPct;
  final double viewToCartRate;
  final double cartToOrderRate;

  /// How the catalogue is spread across the curve, by stage name.
  final Map<String, int> stages;

  static const AdminTrendHeadline empty = AdminTrendHeadline(
    views: 0,
    viewsGrowthPct: 0,
    searches: 0,
    searchGrowthPct: 0,
    cartAdds: 0,
    cartGrowthPct: 0,
    orders: 0,
    ordersGrowthPct: 0,
    units: 0,
    revenue: null,
    revenueGrowthPct: 0,
    viewToCartRate: 0,
    cartToOrderRate: 0,
    stages: {},
  );
}

/// Where the money is not being made.
class MarketOpportunity {
  const MarketOpportunity({
    required this.kind,
    required this.titleAr,
    required this.detailAr,
    required this.score,
    required this.subjectId,
  });

  /// `CATEGORY_GAP`, `UNMET_SEARCH`, `PRICE_BAND_GAP`.
  final String kind;
  final String titleAr;
  final String detailAr;
  final double score;
  final String? subjectId;
}

class SellerPerformanceRow {
  const SellerPerformanceRow({
    required this.sellerId,
    required this.name,
    required this.imageUrl,
    required this.units,
    required this.unitsGrowthPct,
    required this.orders,
    required this.revenue,
    required this.revenueGrowthPct,
    required this.cancelRate,
    required this.returnRate,
    required this.liveProducts,
  });

  final String sellerId;
  final String name;
  final String? imageUrl;
  final int units;
  final double unitsGrowthPct;
  final int orders;
  final Money? revenue;
  final double revenueGrowthPct;
  final double cancelRate;
  final double returnRate;
  final int liveProducts;
}

class AdminTrendOverview {
  const AdminTrendOverview({
    required this.asOf,
    required this.window,
    required this.headline,
    required this.series,
    required this.categoryTrends,
    required this.colourTrends,
    required this.priceTrends,
    required this.emergingProducts,
    required this.decliningProducts,
    required this.searchTrends,
    required this.unmetDemand,
    required this.unmetDemandTotal,
    required this.forecast,
    required this.insights,
  });

  final DateTime asOf;
  final TrendWindow window;
  final AdminTrendHeadline headline;
  final List<TrendSeriesPoint> series;
  final List<CategoryTrend> categoryTrends;
  final List<AttributeTrend> colourTrends;
  final List<AttributeTrend> priceTrends;
  final List<AdminTrendProduct> emergingProducts;
  final List<AdminTrendProduct> decliningProducts;
  final List<SearchTermTrend> searchTrends;
  final List<UnmetDemand> unmetDemand;
  final int unmetDemandTotal;
  final TrendForecast forecast;
  final List<TrendInsight> insights;

  /// True when the pipeline has not produced anything yet — before the first
  /// nightly run, or on a platform with no traffic. Distinct from a failure.
  bool get isEmpty =>
      headline.views == 0 &&
      categoryTrends.isEmpty &&
      emergingProducts.isEmpty &&
      insights.isEmpty;
}
