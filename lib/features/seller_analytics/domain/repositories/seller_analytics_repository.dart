import 'package:reem/core/result/result.dart';
import 'package:reem/features/seller_analytics/domain/entities/seller_analytics_report.dart';

abstract interface class SellerAnalyticsRepository {
  Future<Result<SellerAnalyticsReport>> dashboard(AnalyticsPeriod period);
}
