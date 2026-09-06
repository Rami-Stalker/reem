import 'package:reem/core/base/repository_handler.dart';
import 'package:reem/core/result/result.dart';
import 'package:reem/features/seller_analytics/data/datasources/seller_analytics_remote_datasource.dart';
import 'package:reem/features/seller_analytics/domain/entities/seller_analytics_report.dart';
import 'package:reem/features/seller_analytics/domain/repositories/seller_analytics_repository.dart';

class SellerAnalyticsRepositoryImpl
    with RepositoryHandler
    implements SellerAnalyticsRepository {
  const SellerAnalyticsRepositoryImpl(this.remote);

  final SellerAnalyticsRemoteDataSource remote;

  @override
  Future<Result<SellerAnalyticsReport>> dashboard(AnalyticsPeriod period) =>
      guard(() => remote.dashboard(period));
}
