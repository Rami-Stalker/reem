import 'package:ohara/core/network/api_endpoints.dart';
import 'package:ohara/core/network/base_remote_datasource.dart';
import 'package:ohara/features/trends/data/datasources/trends_remote_datasource.dart';
import 'package:ohara/features/trends/data/models/trend_mappers.dart';
import 'package:ohara/features/trends/domain/entities/trend_entities.dart';

/// `/trends/*`.
///
/// The seller endpoints send no seller id — the server takes it from the token
/// and would refuse one anyway. That is worth saying here because it is the
/// reason none of these method signatures has a `sellerId` parameter that a
/// future caller could get wrong.
final class TrendsRemoteDataSourceImpl extends BaseRemoteDataSource
    implements TrendsRemoteDataSource {
  const TrendsRemoteDataSourceImpl(super.dio);

  // ── Seller ─────────────────────────────────────────────────────────────

  @override
  Future<SellerTrendOverview> sellerOverview(TrendWindow window) async {
    final json = await getJson(
      ApiEndpoints.trendsSellerOverview,
      query: {'window': window.wire},
    );
    return TrendMappers.sellerOverview(json);
  }

  @override
  Future<List<SellerTrendProduct>> sellerProducts(
    TrendWindow window, {
    TrendStage? stage,
    int limit = 50,
  }) async {
    final json = await getJson(
      ApiEndpoints.trendsSellerProducts,
      query: {
        'window': window.wire,
        'limit': limit,
        if (stage != null) 'stage': stage.wire,
      },
    );
    return _rows(json).map(TrendMappers.sellerProduct).toList();
  }

  @override
  Future<TrendForecast> sellerForecast({int horizonDays = 14}) async {
    final json = await getJson(
      ApiEndpoints.trendsSellerForecast,
      query: {'horizon_days': horizonDays},
    );
    return TrendMappers.forecast(json);
  }

  @override
  Future<List<TrendInsight>> sellerInsights({int limit = 25}) async {
    final json = await getJson(
      ApiEndpoints.trendsSellerInsights,
      query: {'limit': limit},
    );
    return _rows(json).map(TrendMappers.insight).toList();
  }

  @override
  Future<TrendInsight> updateSellerInsight(
    String id,
    InsightStatus status,
  ) async {
    final json = await patchJson(
      ApiEndpoints.trendsSellerInsight(id),
      body: {'status': status.wire},
    );
    return TrendMappers.insight(json);
  }

  // ── Admin ──────────────────────────────────────────────────────────────

  @override
  Future<AdminTrendOverview> adminOverview(TrendWindow window) async {
    final json = await getJson(
      ApiEndpoints.trendsAdminOverview,
      query: {'window': window.wire},
    );
    return TrendMappers.adminOverview(json);
  }

  @override
  Future<List<AdminTrendProduct>> adminProducts(
    TrendWindow window, {
    TrendStage? stage,
    String? categoryId,
    int limit = 50,
  }) async {
    final json = await getJson(
      ApiEndpoints.trendsAdminProducts,
      query: {
        'window': window.wire,
        'limit': limit,
        if (stage != null) 'stage': stage.wire,
        'category_id': ?categoryId,
      },
    );
    return _rows(json).map(TrendMappers.adminProduct).toList();
  }

  @override
  Future<List<CategoryTrend>> adminCategories(
    TrendWindow window, {
    int limit = 30,
  }) async {
    final json = await getJson(
      ApiEndpoints.trendsAdminCategories,
      query: {'window': window.wire, 'limit': limit},
    );
    return _rows(json).map(TrendMappers.category).toList();
  }

  @override
  Future<List<AttributeTrend>> adminAttributes({
    required String dimension,
    int days = 7,
    int limit = 20,
  }) async {
    final json = await getJson(
      ApiEndpoints.trendsAdminAttributes,
      query: {'dimension': dimension, 'days': days, 'limit': limit},
    );
    return _rows(json).map(TrendMappers.attribute).toList();
  }

  @override
  Future<List<SearchTermTrend>> adminSearchTerms({
    int days = 30,
    int limit = 50,
    bool rising = false,
  }) async {
    final json = await getJson(
      ApiEndpoints.trendsAdminSearch,
      query: {'days': days, 'limit': limit, 'rising': rising},
    );
    return _rows(json).map(TrendMappers.searchTerm).toList();
  }

  @override
  Future<List<UnmetDemand>> adminUnmetDemand({
    UnmetDemandStatus? status,
    int limit = 50,
  }) async {
    final json = await getJson(
      ApiEndpoints.trendsAdminUnmetDemand,
      query: {'limit': limit, if (status != null) 'status': status.wire},
    );
    return _rows(json).map(TrendMappers.unmet).toList();
  }

  @override
  Future<UnmetDemand> reviewUnmetDemand(
    String id,
    UnmetDemandStatus status, {
    String? note,
  }) async {
    final json = await patchJson(
      ApiEndpoints.trendsAdminUnmetDemandItem(id),
      body: {'status': status.wire, 'note': ?note},
    );
    return TrendMappers.unmet(json);
  }

  @override
  Future<List<SellerPerformanceRow>> adminSellers({
    int days = 30,
    int limit = 25,
  }) async {
    final json = await getJson(
      ApiEndpoints.trendsAdminSellers,
      query: {'days': days, 'limit': limit},
    );
    return _rows(json).map(TrendMappers.sellerPerformance).toList();
  }

  @override
  Future<List<MarketOpportunity>> adminOpportunities(
    TrendWindow window, {
    int limit = 20,
  }) async {
    final json = await getJson(
      ApiEndpoints.trendsAdminOpportunities,
      query: {'window': window.wire, 'limit': limit},
    );
    return _rows(json).map(TrendMappers.opportunity).toList();
  }

  @override
  Future<List<TrendInsight>> adminInsights({int limit = 25}) async {
    final json = await getJson(
      ApiEndpoints.trendsAdminInsights,
      query: {'limit': limit},
    );
    return _rows(json).map(TrendMappers.insight).toList();
  }

  @override
  Future<TrendInsight> updateAdminInsight(
    String id,
    InsightStatus status,
  ) async {
    final json = await patchJson(
      ApiEndpoints.trendsAdminInsight(id),
      body: {'status': status.wire},
    );
    return TrendMappers.insight(json);
  }

  @override
  Future<void> recompute({int lookbackDays = 3}) async {
    await postJson(
      ApiEndpoints.trendsAdminRecompute,
      body: {'lookback_days': lookbackDays},
    );
  }

  /// Every list endpoint wraps its rows in `{ data: [...] }`.
  List<Map<String, dynamic>> _rows(Map<String, dynamic> json) {
    final data = json['data'];
    if (data is! List) return const [];
    return [
      for (final entry in data)
        if (entry is Map) Map<String, dynamic>.from(entry),
    ];
  }
}
