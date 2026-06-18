import '../entities/seller_dashboard_data.dart';

abstract interface class SellerDashboardRepository {
  Future<SellerDashboardData> getDashboard();
}
