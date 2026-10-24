import 'package:ohara/core/result/result.dart';
import 'package:ohara/features/seller_analytics/domain/entities/seller_analytics_report.dart';

abstract interface class SellerAnalyticsRepository {
  Future<Result<SellerAnalyticsReport>> dashboard(AnalyticsPeriod period);
}
