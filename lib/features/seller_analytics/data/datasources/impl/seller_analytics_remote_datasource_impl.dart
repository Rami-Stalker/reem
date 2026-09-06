import 'package:reem/core/network/api_endpoints.dart';
import 'package:reem/core/network/base_remote_datasource.dart';
import 'package:reem/features/seller_analytics/data/datasources/seller_analytics_remote_datasource.dart';
import 'package:reem/features/seller_analytics/data/models/seller_analytics_report_model.dart';
import 'package:reem/features/seller_analytics/domain/entities/seller_analytics_report.dart';

/// `/analytics/*` accepts the SELLER role and scopes every query to the caller
/// on the server, so no seller id is sent — and none would be honoured. The
/// endpoints have been there all along with nothing in the app reading them.
final class SellerAnalyticsRemoteDataSourceImpl extends BaseRemoteDataSource
    implements SellerAnalyticsRemoteDataSource {
  const SellerAnalyticsRemoteDataSourceImpl(super.dio);

  @override
  Future<SellerAnalyticsReport> dashboard(AnalyticsPeriod period) async {
    final end = DateTime.now();
    final json = await getJson(
      ApiEndpoints.analyticsDashboard,
      query: {
        'start_date': period.startFrom(end).toUtc().toIso8601String(),
        'end_date': end.toUtc().toIso8601String(),
      },
    );
    return SellerAnalyticsReportMapper.fromJson(json);
  }
}
