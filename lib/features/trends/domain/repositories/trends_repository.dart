import 'package:reem/core/result/result.dart';
import 'package:reem/features/trends/domain/entities/trend_entities.dart';

/// The Trend Engine's read surface, as the app needs it.
///
/// Split by audience rather than by resource, because the two dashboards are
/// different products answering different questions — and because the seller
/// half is **always scoped to the caller**. No method here takes a seller id:
/// the server reads it from the token and would not honour one if it were
/// sent, so there is no shape of call that could ask for someone else's shop.
abstract interface class TrendsRepository {
  // ── Seller ─────────────────────────────────────────────────────────────

  Future<Result<SellerTrendOverview>> sellerOverview(TrendWindow window);

  Future<Result<List<SellerTrendProduct>>> sellerProducts(
    TrendWindow window, {
    TrendStage? stage,
    int limit,
  });

  Future<Result<TrendForecast>> sellerForecast({int horizonDays});

  Future<Result<List<TrendInsight>>> sellerInsights({int limit});

  /// Acknowledge, action or dismiss one of her own insights.
  Future<Result<TrendInsight>> updateSellerInsight(
    String id,
    InsightStatus status,
  );

  // ── Admin ──────────────────────────────────────────────────────────────

  Future<Result<AdminTrendOverview>> adminOverview(TrendWindow window);

  Future<Result<List<AdminTrendProduct>>> adminProducts(
    TrendWindow window, {
    TrendStage? stage,
    String? categoryId,
    int limit,
  });

  Future<Result<List<CategoryTrend>>> adminCategories(
    TrendWindow window, {
    int limit,
  });

  /// Colour, price band, brand — `dimension` is the facet being sliced.
  Future<Result<List<AttributeTrend>>> adminAttributes({
    required String dimension,
    int days,
    int limit,
  });

  Future<Result<List<SearchTermTrend>>> adminSearchTerms({
    int days,
    int limit,
    bool rising,
  });

  Future<Result<List<UnmetDemand>>> adminUnmetDemand({
    UnmetDemandStatus? status,
    int limit,
  });

  /// Move an unmet-demand signal along the buying team's workflow.
  Future<Result<UnmetDemand>> reviewUnmetDemand(
    String id,
    UnmetDemandStatus status, {
    String? note,
  });

  Future<Result<List<SellerPerformanceRow>>> adminSellers({
    int days,
    int limit,
  });

  Future<Result<List<MarketOpportunity>>> adminOpportunities(
    TrendWindow window, {
    int limit,
  });

  Future<Result<List<TrendInsight>>> adminInsights({int limit});

  Future<Result<TrendInsight>> updateAdminInsight(
    String id,
    InsightStatus status,
  );

  /// Re-run the nightly pipeline now. Refused by the server when one is
  /// already in flight.
  Future<Result<void>> recompute({int lookbackDays});
}
