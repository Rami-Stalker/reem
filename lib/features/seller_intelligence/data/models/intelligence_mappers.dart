import 'package:reem/features/seller_intelligence/domain/entities/intelligence.dart';

/// Wire → domain.
///
/// Every field is read defensively because these payloads are mostly *nullable
/// by design*: a score the server could not measure arrives as `null`, and the
/// one thing this file must never do is turn that into a zero. A zero on a
/// health screen is an accusation; a null is an honest gap the UI renders as
/// "not measured yet".
class IntelligenceMappers {
  const IntelligenceMappers._();

  // ── Primitives ─────────────────────────────────────────────────────────

  static double _double(Object? v, [double fallback = 0]) =>
      v is num ? v.toDouble() : fallback;

  /// Null stays null. The whole design depends on this.
  static double? _maybeDouble(Object? v) => v is num ? v.toDouble() : null;

  static int _int(Object? v, [int fallback = 0]) =>
      v is num ? v.toInt() : fallback;

  static int? _maybeInt(Object? v) => v is num ? v.toInt() : null;

  static String _string(Object? v, [String fallback = '']) =>
      v is String ? v : fallback;

  static bool _bool(Object? v, [bool fallback = false]) =>
      v is bool ? v : fallback;

  static DateTime _day(Object? v) =>
      DateTime.tryParse(_string(v)) ?? DateTime.now();

  static List<Map<String, dynamic>> _rows(Object? v) => v is List
      ? v.whereType<Map<String, dynamic>>().toList(growable: false)
      : const [];

  static Map<String, num?> _facts(Object? v) {
    if (v is! Map) return const {};
    return {
      for (final entry in v.entries)
        if (entry.key is String)
          entry.key as String: entry.value is num ? entry.value as num : null,
    };
  }

  // ── Advice ─────────────────────────────────────────────────────────────

  static Advice advice(Map<String, dynamic> json, {String? subjectKey}) {
    return Advice(
      code: _string(json['code']),
      severity: AdviceSeverity.parse(json['severity'] as String?),
      gainPoints: _double(json['gain_points']),
      ar: _string(json['ar']),
      subject: subjectKey == null ? null : json[subjectKey] as String?,
    );
  }

  // ── Seller health ──────────────────────────────────────────────────────

  static HealthDimension dimension(Map<String, dynamic> json) {
    return HealthDimension(
      key: _string(json['key']),
      label: _string(json['label']),
      blurb: _string(json['blurb']),
      score: _maybeDouble(json['score']),
      weight: _double(json['weight']),
      evidence: _double(json['evidence']),
      sample: _int(json['sample']),
      value: _maybeDouble(json['value']),
      counted: _bool(json['counted']),
    );
  }

  static SellerHealth sellerHealth(Map<String, dynamic> json) {
    return SellerHealth(
      score: _double(json['score']),
      band: HealthBand.parse(json['band'] as String?),
      bandLabel: _string(json['band_label']),
      isProvisional: _bool(json['is_provisional']),
      confidence: _double(json['confidence']),
      momentum: _double(json['momentum']),
      windowDays: _int(json['window_days'], 90),
      dimensions: _rows(json['dimensions']).map(dimension).toList(growable: false),
      advice: _rows(json['advice'])
          .map((row) => advice(row, subjectKey: 'dimension'))
          .toList(growable: false),
      facts: _facts(json['facts']),
    );
  }

  static List<HealthPoint> healthHistory(Map<String, dynamic> json) {
    return _rows(json['rows'])
        .map(
          (row) => HealthPoint(
            day: _day(row['day']),
            score: _double(row['score']),
            band: HealthBand.parse(row['band'] as String?),
          ),
        )
        .toList(growable: false);
  }

  // ── Product intelligence ───────────────────────────────────────────────

  static HealthAxis axis(Map<String, dynamic> json) {
    return HealthAxis(
      key: _string(json['key']),
      label: _string(json['label']),
      score: _maybeDouble(json['score']),
      weight: _double(json['weight']),
      evidence: _string(json['evidence'], 'measured'),
      counted: _bool(json['counted']),
    );
  }

  static PeerPosition? peers(Object? v) {
    if (v is! Map<String, dynamic>) return null;
    return PeerPosition(
      peers: _int(v['peers']),
      pricePremiumBps: _maybeInt(v['price_premium_bps']),
      conversion: _double(v['conversion']),
      medianConversion: _double(v['median_conversion']),
    );
  }

  /// A row from the list endpoint, which carries one piece of advice.
  static ProductHealth productRow(Map<String, dynamic> json) {
    final top = json['top_advice'];
    return ProductHealth(
      productId: _string(json['product_id']),
      title: _string(json['title']),
      imageUrl: json['image_url'] as String?,
      score: _double(json['score']),
      confidence: _double(json['confidence']),
      axes: _rows(json['axes']).map(axis).toList(growable: false),
      peers: peers(json['peers']),
      advice: top is Map<String, dynamic>
          ? [advice(top, subjectKey: 'axis')]
          : const [],
      views: _int(json['views']),
      orders: _int(json['orders']),
      inStock: _bool(json['in_stock'], true),
      adviceCount: _int(json['advice_count']),
    );
  }

  /// The detail endpoint, which carries all of it.
  static ProductHealth productDetail(Map<String, dynamic> json) {
    return ProductHealth(
      productId: _string(json['product_id']),
      title: _string(json['title']),
      imageUrl: json['image_url'] as String?,
      score: _double(json['score']),
      confidence: _double(json['confidence']),
      axes: _rows(json['axes']).map(axis).toList(growable: false),
      peers: peers(json['peers']),
      advice: _rows(json['advice'])
          .map((row) => advice(row, subjectKey: 'axis'))
          .toList(growable: false),
      adviceCount: _rows(json['advice']).length,
      facts: _facts(json['facts']),
      views: _int(_facts(json['facts'])['views']),
      orders: _int(_facts(json['facts'])['orders']),
      inStock: _bool((json['facts'] as Map?)?['in_stock'], true),
    );
  }

  static ProductHealthList productList(Map<String, dynamic> json) {
    return ProductHealthList(
      windowDays: _int(json['window_days'], 30),
      averageScore: _maybeDouble(json['average_score']),
      rows: _rows(json['rows']).map(productRow).toList(growable: false),
    );
  }

  // ── Demand radar ───────────────────────────────────────────────────────

  static DemandRadar radar(Map<String, dynamic> json) {
    return DemandRadar(
      asOf: _day(json['as_of']),
      windowDays: _int(json['window_days'], 28),
      categoryCount: _int(json['category_count']),
      opportunities: _rows(json['opportunities'])
          .map(
            (row) => Opportunity(
              kind: OpportunityKind.parse(row['code'] as String?),
              score: _double(row['score']),
              ar: _string(row['ar']),
              categoryId: row['category_id'] as String?,
              productId: row['product_id'] as String?,
              termKey: row['term_key'] as String?,
            ),
          )
          .toList(growable: false),
      rising: _rows(json['rising'])
          .map(
            (row) => RisingCategory(
              categoryId: _string(row['category_id']),
              name: _string(row['name']),
              growth: _double(row['growth']),
              recent: _int(row['recent']),
              isSelling: _string(row['presence']) == 'selling',
              relevance: _double(row['relevance']),
            ),
          )
          .toList(growable: false),
      unmet: _rows(json['unmet'])
          .map(
            (row) => UnmetDemand(
              termKey: _string(row['term_key']),
              display: _string(row['display']),
              searches: _int(row['searches']),
              missRate: _double(row['miss_rate']),
              inHerCategories: _bool(row['in_her_categories']),
              opportunity: _double(row['opportunity']),
            ),
          )
          .toList(growable: false),
      stockAlerts: _rows(json['stock_alerts'])
          .map(
            (row) => StockAlert(
              productId: _string(row['product_id']),
              title: _string(row['title']),
              stockUnits: _int(row['stock_units']),
              coverDays: _maybeDouble(row['cover_days']),
              severity: AdviceSeverity.parse(row['severity'] as String?),
              ar: _string(row['ar']),
            ),
          )
          .toList(growable: false),
      priceTrends: _rows(json['price_trends'])
          .map(
            (row) => PriceTrend(
              categoryId: _string(row['category_id']),
              name: _string(row['name']),
              changeBps: _int(row['change_bps']),
              sellerPremiumBps: _maybeInt(row['seller_premium_bps']),
              ar: _string(row['ar']),
            ),
          )
          .toList(growable: false),
    );
  }
}
