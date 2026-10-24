import 'package:ohara/core/base/repository_handler.dart';
import 'package:ohara/core/result/result.dart';
import 'package:ohara/features/trends/data/datasources/trends_remote_datasource.dart';
import 'package:ohara/features/trends/domain/entities/trend_entities.dart';
import 'package:ohara/features/trends/domain/repositories/trends_repository.dart';

class TrendsRepositoryImpl with RepositoryHandler implements TrendsRepository {
  const TrendsRepositoryImpl(this.remote);

  final TrendsRemoteDataSource remote;

  // ── Seller ─────────────────────────────────────────────────────────────

  @override
  Future<Result<SellerTrendOverview>> sellerOverview(TrendWindow window) =>
      guard(() => remote.sellerOverview(window), operation: 'seller trends');

  @override
  Future<Result<List<SellerTrendProduct>>> sellerProducts(
    TrendWindow window, {
    TrendStage? stage,
    int limit = 50,
  }) => guard(
    () => remote.sellerProducts(window, stage: stage, limit: limit),
    operation: 'seller trend products',
  );

  @override
  Future<Result<TrendForecast>> sellerForecast({int horizonDays = 14}) => guard(
    () => remote.sellerForecast(horizonDays: horizonDays),
    operation: 'seller forecast',
  );

  @override
  Future<Result<List<TrendInsight>>> sellerInsights({int limit = 25}) => guard(
    () => remote.sellerInsights(limit: limit),
    operation: 'seller insights',
  );

  @override
  Future<Result<TrendInsight>> updateSellerInsight(
    String id,
    InsightStatus status,
  ) => guard(
    () => remote.updateSellerInsight(id, status),
    operation: 'insight update',
  );

  // ── Admin ──────────────────────────────────────────────────────────────

  @override
  Future<Result<AdminTrendOverview>> adminOverview(TrendWindow window) =>
      guard(() => remote.adminOverview(window), operation: 'market trends');

  @override
  Future<Result<List<AdminTrendProduct>>> adminProducts(
    TrendWindow window, {
    TrendStage? stage,
    String? categoryId,
    int limit = 50,
  }) => guard(
    () => remote.adminProducts(
      window,
      stage: stage,
      categoryId: categoryId,
      limit: limit,
    ),
    operation: 'market products',
  );

  @override
  Future<Result<List<CategoryTrend>>> adminCategories(
    TrendWindow window, {
    int limit = 30,
  }) => guard(
    () => remote.adminCategories(window, limit: limit),
    operation: 'category trends',
  );

  @override
  Future<Result<List<AttributeTrend>>> adminAttributes({
    required String dimension,
    int days = 7,
    int limit = 20,
  }) => guard(
    () =>
        remote.adminAttributes(dimension: dimension, days: days, limit: limit),
    operation: 'attribute trends',
  );

  @override
  Future<Result<List<SearchTermTrend>>> adminSearchTerms({
    int days = 30,
    int limit = 50,
    bool rising = false,
  }) => guard(
    () => remote.adminSearchTerms(days: days, limit: limit, rising: rising),
    operation: 'search trends',
  );

  @override
  Future<Result<List<UnmetDemand>>> adminUnmetDemand({
    UnmetDemandStatus? status,
    int limit = 50,
  }) => guard(
    () => remote.adminUnmetDemand(status: status, limit: limit),
    operation: 'unmet demand',
  );

  @override
  Future<Result<UnmetDemand>> reviewUnmetDemand(
    String id,
    UnmetDemandStatus status, {
    String? note,
  }) => guard(
    () => remote.reviewUnmetDemand(id, status, note: note),
    operation: 'unmet demand review',
  );

  @override
  Future<Result<List<SellerPerformanceRow>>> adminSellers({
    int days = 30,
    int limit = 25,
  }) => guard(
    () => remote.adminSellers(days: days, limit: limit),
    operation: 'seller performance',
  );

  @override
  Future<Result<List<MarketOpportunity>>> adminOpportunities(
    TrendWindow window, {
    int limit = 20,
  }) => guard(
    () => remote.adminOpportunities(window, limit: limit),
    operation: 'market opportunities',
  );

  @override
  Future<Result<List<TrendInsight>>> adminInsights({int limit = 25}) => guard(
    () => remote.adminInsights(limit: limit),
    operation: 'market insights',
  );

  @override
  Future<Result<TrendInsight>> updateAdminInsight(
    String id,
    InsightStatus status,
  ) => guard(
    () => remote.updateAdminInsight(id, status),
    operation: 'insight update',
  );

  @override
  Future<Result<void>> recompute({int lookbackDays = 3}) => guard(
    () => remote.recompute(lookbackDays: lookbackDays),
    operation: 'trend recompute',
  );
}
