import 'package:ohara/features/trends/domain/entities/trend_entities.dart';

/// The HTTP surface of the Trend Engine.
///
/// Mirrors `TrendsRepository` one for one; the repository's only job on top of
/// this is turning a thrown `AppException` into a `Result`.
abstract interface class TrendsRemoteDataSource {
  Future<SellerTrendOverview> sellerOverview(TrendWindow window);

  Future<List<SellerTrendProduct>> sellerProducts(
    TrendWindow window, {
    TrendStage? stage,
    int limit,
  });

  Future<TrendForecast> sellerForecast({int horizonDays});

  Future<List<TrendInsight>> sellerInsights({int limit});

  Future<TrendInsight> updateSellerInsight(String id, InsightStatus status);

  Future<AdminTrendOverview> adminOverview(TrendWindow window);

  Future<List<AdminTrendProduct>> adminProducts(
    TrendWindow window, {
    TrendStage? stage,
    String? categoryId,
    int limit,
  });

  Future<List<CategoryTrend>> adminCategories(TrendWindow window, {int limit});

  Future<List<AttributeTrend>> adminAttributes({
    required String dimension,
    int days,
    int limit,
  });

  Future<List<SearchTermTrend>> adminSearchTerms({
    int days,
    int limit,
    bool rising,
  });

  Future<List<UnmetDemand>> adminUnmetDemand({
    UnmetDemandStatus? status,
    int limit,
  });

  Future<UnmetDemand> reviewUnmetDemand(
    String id,
    UnmetDemandStatus status, {
    String? note,
  });

  Future<List<SellerPerformanceRow>> adminSellers({int days, int limit});

  Future<List<MarketOpportunity>> adminOpportunities(
    TrendWindow window, {
    int limit,
  });

  Future<List<TrendInsight>> adminInsights({int limit});

  Future<TrendInsight> updateAdminInsight(String id, InsightStatus status);

  Future<void> recompute({int lookbackDays});
}
