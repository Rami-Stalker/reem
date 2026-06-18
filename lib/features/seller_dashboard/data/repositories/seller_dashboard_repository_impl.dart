import '../../domain/entities/seller_dashboard_data.dart';
import '../../domain/repositories/seller_dashboard_repository.dart';
import '../datasources/seller_dashboard_datasource.dart';

final class SellerDashboardRepositoryImpl
    implements SellerDashboardRepository {
  const SellerDashboardRepositoryImpl({required this.source});

  final SellerDashboardDataSource source;

  @override
  Future<SellerDashboardData> getDashboard() => source.getDashboard();
}
