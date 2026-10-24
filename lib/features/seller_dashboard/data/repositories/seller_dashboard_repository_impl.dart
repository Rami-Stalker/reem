import 'package:ohara/features/seller_dashboard/data/datasources/seller_dashboard_datasource.dart';
import 'package:ohara/features/seller_dashboard/domain/entities/seller_dashboard_data.dart';
import 'package:ohara/features/seller_dashboard/domain/repositories/seller_dashboard_repository.dart';

final class SellerDashboardRepositoryImpl
    implements SellerDashboardRepository {
  const SellerDashboardRepositoryImpl({required this.source});

  final SellerDashboardDataSource source;

  @override
  Future<SellerDashboardData> getDashboard() => source.getDashboard();
}
