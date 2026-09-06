import 'package:reem/features/seller_analytics/domain/entities/seller_analytics_report.dart';

abstract interface class SellerAnalyticsRemoteDataSource {
  Future<SellerAnalyticsReport> dashboard(AnalyticsPeriod period);
}
