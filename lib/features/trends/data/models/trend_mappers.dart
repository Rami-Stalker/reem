import 'package:reem/core/shared/value_objects/money.dart';
import 'package:reem/features/trends/domain/entities/trend_entities.dart';

/// Parses `/trends/*`.
///
/// Every reader here is total: a missing key, a null, a string where a number
/// was expected or a whole absent section produces a zero or an empty list
/// rather than an exception. That is not defensiveness for its own sake — a
/// dashboard has fifteen independent panels, and one malformed field should
/// cost the reader that panel's number, not the whole page.
///
/// Money arrives as `{ amount, currency }` with the amount as a **string**,
/// because SYP figures run into the millions and a JSON parser is free to
/// round a large float. The string is kept verbatim.
abstract final class TrendMappers {
  // ── Overviews ──────────────────────────────────────────────────────────

  static SellerTrendOverview sellerOverview(Map<String, dynamic> json) {
    final headline = _map(json['headline']);
    final signals = _map(json['demand_signals']);

    return SellerTrendOverview(
      asOf: _date(json['as_of']) ?? DateTime.now(),
      window: TrendWindow.fromWire(json['window'] as String?),
      headline: SellerTrendHeadline(
        units: _int(headline['units']),
        previousUnits: _int(headline['previous_units']),
        revenue: _money(headline['revenue']),
        previousRevenue: _money(headline['previous_revenue']),
        views: _int(headline['views']),
        averageScore: _double(headline['average_score']),
        risingProducts: _int(headline['rising_products']),
        decliningProducts: _int(headline['declining_products']),
      ),
      demandSignals: DemandSignals(
        views: _int(signals['views']),
        previousViews: _int(signals['previous_views']),
        searchHits: _int(signals['search_hits']),
        cartAdds: _int(signals['cart_adds']),
        favorites: _int(signals['favorites']),
        units: _int(signals['units']),
      ),
      trending: _list(json['trending_products']).map(sellerProduct).toList(),
      emerging: _list(json['emerging_products']).map(sellerProduct).toList(),
      lowConversion: _list(
        json['low_conversion_alerts'],
      ).map(sellerProduct).toList(),
      stockOpportunities: _list(
        json['stock_opportunities'],
      ).map(sellerProduct).toList(),
      forecast: forecast(_map(json['forecast'])),
      series: _list(json['series']).map(seriesPoint).toList(),
      recommendedActions: _list(
        json['recommended_actions'],
      ).map(insight).toList(),
      productCount: _int(json['product_count']),
    );
  }

  static AdminTrendOverview adminOverview(Map<String, dynamic> json) {
    final headline = _map(json['headline']);

    return AdminTrendOverview(
      asOf: _date(json['as_of']) ?? DateTime.now(),
      window: TrendWindow.fromWire(json['window'] as String?),
      headline: AdminTrendHeadline(
        views: _int(headline['views']),
        viewsGrowthPct: _double(headline['views_growth_pct']),
        searches: _int(headline['searches']),
        searchGrowthPct: _double(headline['search_growth_pct']),
        cartAdds: _int(headline['cart_adds']),
        cartGrowthPct: _double(headline['cart_growth_pct']),
        orders: _int(headline['orders']),
        ordersGrowthPct: _double(headline['orders_growth_pct']),
        units: _int(headline['units']),
        revenue: _money(headline['revenue']),
        revenueGrowthPct: _double(headline['revenue_growth_pct']),
        viewToCartRate: _double(headline['view_to_cart_rate']),
        cartToOrderRate: _double(headline['cart_to_order_rate']),
        stages: {
          for (final entry in _map(headline['stages']).entries)
            entry.key: _int(entry.value),
        },
      ),
      series: _list(json['series']).map(seriesPoint).toList(),
      categoryTrends: _list(json['category_trends']).map(category).toList(),
      colourTrends: _list(json['colour_trends']).map(attribute).toList(),
      priceTrends: _list(json['price_trends']).map(attribute).toList(),
      emergingProducts: _list(
        json['emerging_products'],
      ).map(adminProduct).toList(),
      decliningProducts: _list(
        json['declining_products'],
      ).map(adminProduct).toList(),
      searchTrends: _list(json['search_trends']).map(searchTerm).toList(),
      unmetDemand: _list(json['unmet_demand']).map(unmet).toList(),
      unmetDemandTotal: _int(json['unmet_demand_total']),
      forecast: forecast(_map(json['forecast'])),
      insights: _list(json['insights']).map(insight).toList(),
    );
  }

  // ── Products ───────────────────────────────────────────────────────────

  static SellerTrendProduct sellerProduct(Map<String, dynamic> json) {
    final demand = _map(json['demand']);
    final mine = _map(json['mine']);
    final forecastJson = _map(json['forecast']);
    final alerts = _map(json['alerts']);

    return SellerTrendProduct(
      productId: _string(json['product_id']),
      title: _string(json['title']),
      slug: _string(json['slug']),
      imageUrl: json['image_url'] as String?,
      categoryNameAr: _string(json['category_name_ar']),
      score: _double(json['trend_score']),
      previousScore: _doubleOrNull(json['previous_score']),
      delta: _double(json['delta']),
      stage: stage(json['stage']),
      confidence: _double(json['confidence']),
      rank: _intOrNull(json['rank']),
      components: _list(json['components']).map(component).toList(),
      demand: ProductDemand(
        views: _int(demand['views']),
        previousViews: _int(demand['previous_views']),
        searchHits: _int(demand['search_hits']),
        cartAdds: _int(demand['cart_adds']),
        favorites: _int(demand['favorites']),
        viewToCartRate: _double(demand['view_to_cart_rate']),
        cartToOrderRate: _double(demand['cart_to_order_rate']),
        viewToOrderRate: _double(demand['view_to_order_rate']),
      ),
      mine: SellerProductOutcome(
        units: _int(mine['units']),
        orders: _int(mine['orders']),
        revenue: _money(mine['revenue']),
        lifetimeUnits: _int(mine['lifetime_units']),
        returns: _int(mine['returns']),
        stockUnits: _int(mine['stock_units']),
        price: _money(mine['price']),
      ),
      forecastUnits: _doubleOrNull(forecastJson['units']),
      forecastHorizonDays: _intOrNull(forecastJson['horizon_days']),
      stockoutInDays: _doubleOrNull(forecastJson['stockout_in_days']),
      alerts: TrendAlerts(
        lowConversion: _bool(alerts['low_conversion']),
        weakCartThrough: _bool(alerts['weak_cart_through']),
        stockRisk: _bool(alerts['stock_risk']),
        soldOutWithDemand: _bool(alerts['sold_out_with_demand']),
        overstock: _bool(alerts['overstock']),
      ),
    );
  }

  static AdminTrendProduct adminProduct(Map<String, dynamic> json) =>
      AdminTrendProduct(
        productId: _string(json['product_id']),
        title: _string(json['title']),
        imageUrl: json['image_url'] as String?,
        categoryNameAr: _string(json['category_name_ar']),
        sellers: [
          for (final seller in _list(json['sellers']))
            if (seller['name'] is String) seller['name'] as String,
        ],
        score: _double(json['trend_score']),
        delta: _double(json['delta']),
        stage: stage(json['stage']),
        confidence: _double(json['confidence']),
        rank: _intOrNull(json['rank']),
        views: _int(json['views']),
        viewsGrowthPct: _double(json['views_growth_pct']),
        searchHits: _int(json['search_hits']),
        cartAdds: _int(json['cart_adds']),
        units: _int(json['units']),
        unitsGrowthPct: _double(json['units_growth_pct']),
        revenue: _money(json['revenue']),
        viewToOrderRate: _double(json['view_to_order_rate']),
        stockUnits: _int(json['stock_units']),
        daysOfCover: _doubleOrNull(json['days_of_cover']),
        components: _list(json['components']).map(component).toList(),
      );

  // ── Pieces ─────────────────────────────────────────────────────────────

  /// The stage chip.
  ///
  /// The Arabic label is taken from the server rather than switched on here,
  /// so a stage this build has never heard of still renders as readable text
  /// instead of an enum name leaking into the UI.
  static TrendStageLabel stage(dynamic value) {
    final json = _map(value);
    final key = json['key'] as String?;
    if (key == null) return TrendStageLabel.unknown;
    return TrendStageLabel(
      stage: TrendStage.fromWire(key),
      labelAr: _string(json['label_ar'], fallback: key),
    );
  }

  static TrendComponent component(Map<String, dynamic> json) => TrendComponent(
    key: _string(json['key']),
    labelAr: _string(json['label_ar']),
    value: _double(json['value']),
    weight: _double(json['weight']),
  );

  static CategoryTrend category(Map<String, dynamic> json) => CategoryTrend(
    categoryId: _string(json['category_id']),
    nameAr: _string(json['name_ar']),
    level: _int(json['level']),
    score: _double(json['trend_score']),
    delta: _double(json['delta']),
    stage: stage(json['stage']),
    views: _int(json['views']),
    viewsGrowthPct: _double(json['views_growth_pct']),
    units: _int(json['units']),
    unitsGrowthPct: _double(json['units_growth_pct']),
    revenue: _money(json['revenue']),
    liveProducts: _int(json['live_products']),
    inStockProducts: _int(json['in_stock_products']),
    medianPrice: _money(json['median_price']),
  );

  static AttributeTrend attribute(Map<String, dynamic> json) => AttributeTrend(
    dimension: _string(json['dimension']),
    value: _string(json['value']),
    labelAr: _string(json['label_ar'], fallback: _string(json['value'])),
    demand: _int(json['demand']),
    growthPct: _double(json['growth_pct']),
    sharePct: _double(json['share_pct']),
    previousSharePct: _double(json['previous_share_pct']),
    shareDeltaPct: _double(json['share_delta_pct']),
    orders: _int(json['orders']),
    units: _int(json['units']),
    revenue: _money(json['revenue']),
    products: _int(json['products']),
  );

  static SearchTermTrend searchTerm(Map<String, dynamic> json) =>
      SearchTermTrend(
        termKey: _string(json['term_key']),
        display: _string(json['display']),
        facetsAr: _string(json['facets_ar']),
        searches: _int(json['searches']),
        previousSearches: _int(json['previous_searches']),
        zeroResults: _int(json['zero_results']),
        missRate: _double(json['miss_rate']),
        clickRate: _double(json['click_rate']),
        orders: _int(json['orders']),
      );

  static UnmetDemand unmet(Map<String, dynamic> json) => UnmetDemand(
    id: _string(json['id']),
    termKey: _string(json['term_key']),
    display: _string(json['display']),
    searches: _int(json['searches']),
    zeroResults: _int(json['zero_results']),
    missRate: _double(json['miss_rate']),
    demandScore: _double(json['demand_score']),
    suggestionAr: json['suggestion_ar'] as String?,
    suggestedCategoryNameAr:
        _map(json['suggested_category'])['name_ar'] as String?,
    status: UnmetDemandStatus.fromWire(json['status'] as String?),
  );

  static TrendInsight insight(Map<String, dynamic> json) {
    final subject = _map(json['subject']);
    final product = _map(subject['product']);
    final category = _map(subject['category']);

    return TrendInsight(
      id: _string(json['id']),
      kind: _string(json['kind']),
      severity: InsightSeverity.fromWire(json['severity'] as String?),
      status: InsightStatus.fromWire(json['status'] as String?),
      titleAr: _string(json['title_ar']),
      bodyAr: _string(json['body_ar']),
      actionAr: json['action_ar'] as String?,
      actionTarget: json['action_target'] as String?,
      productId: product['id'] as String?,
      productTitle: product['title'] as String?,
      categoryId: category['id'] as String?,
      categoryNameAr: category['name_ar'] as String?,
      metrics: _map(json['metrics']),
      confidence: _double(json['confidence']),
      priority: _double(json['priority']),
      narrator: _string(json['narrator'], fallback: 'reem-trend-templates-v1'),
    );
  }

  static TrendForecast forecast(Map<String, dynamic> json) => TrendForecast(
    horizonDays: _int(json['horizon_days']),
    totalUnits: _double(json['total_units']),
    totalRevenue: _money(json['total_revenue']),
    confidence: _double(json['confidence']),
    method: json['method'] as String?,
    points: [
      for (final point in _list(json['points']))
        if (_date(point['date']) case final DateTime date)
          ForecastPoint(
            date: date,
            units: _double(point['units']),
            low: _double(point['low']),
            high: _double(point['high']),
          ),
    ],
    generatedOn: _date(json['generated_on']),
  );

  static TrendSeriesPoint seriesPoint(Map<String, dynamic> json) =>
      TrendSeriesPoint(
        date: _date(json['date']) ?? DateTime.now(),
        units: _int(json['units']),
        orders: _int(json['orders']),
        revenue: _money(json['revenue']),
        views: _int(json['views']),
        searchHits: _int(json['search_hits']),
        cartAdds: _int(json['cart_adds']),
      );

  static SellerPerformanceRow sellerPerformance(Map<String, dynamic> json) =>
      SellerPerformanceRow(
        sellerId: _string(json['seller_id']),
        name: _string(json['name']),
        imageUrl: json['image_url'] as String?,
        units: _int(json['units']),
        unitsGrowthPct: _double(json['units_growth_pct']),
        orders: _int(json['orders']),
        revenue: _money(json['revenue']),
        revenueGrowthPct: _double(json['revenue_growth_pct']),
        cancelRate: _double(json['cancel_rate']),
        returnRate: _double(json['return_rate']),
        liveProducts: _int(json['live_products']),
      );

  static MarketOpportunity opportunity(Map<String, dynamic> json) =>
      MarketOpportunity(
        kind: _string(json['kind']),
        titleAr: _string(json['title_ar']),
        detailAr: _string(json['detail_ar']),
        score: _double(json['score']),
        subjectId: json['subject_id'] as String?,
      );

  // ── Readers ────────────────────────────────────────────────────────────

  static Map<String, dynamic> _map(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return const {};
  }

  static List<Map<String, dynamic>> _list(dynamic value) {
    if (value is! List) return const [];
    return [
      for (final entry in value)
        if (entry is Map) Map<String, dynamic>.from(entry),
    ];
  }

  static String _string(dynamic value, {String fallback = ''}) =>
      value is String && value.isNotEmpty ? value : fallback;

  static int _int(dynamic value) => switch (value) {
    final int v => v,
    final double v => v.round(),
    final String v => int.tryParse(v) ?? double.tryParse(v)?.round() ?? 0,
    _ => 0,
  };

  static int? _intOrNull(dynamic value) => value == null ? null : _int(value);

  static double _double(dynamic value) => switch (value) {
    final double v => v.isFinite ? v : 0,
    final int v => v.toDouble(),
    final String v => double.tryParse(v) ?? 0,
    _ => 0,
  };

  static double? _doubleOrNull(dynamic value) =>
      value == null ? null : _double(value);

  static bool _bool(dynamic value) =>
      value is bool ? value : value == 'true' || value == 1;

  /// Accepts both `2026-08-31` and a full ISO instant.
  static DateTime? _date(dynamic value) {
    if (value is! String || value.isEmpty) return null;
    return DateTime.tryParse(value)?.toLocal();
  }

  static Money? _money(dynamic value) {
    final json = _map(value);
    final amount = json['amount'];
    if (amount == null) return null;
    return Money(
      raw: amount is String ? amount : amount.toString(),
      currency: Currency.fromWire(json['currency'] as String?),
    );
  }
}
