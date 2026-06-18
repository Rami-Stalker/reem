import '../../domain/entities/seller_dashboard_data.dart';

abstract interface class SellerDashboardDataSource {
  Future<SellerDashboardData> getDashboard();
}
