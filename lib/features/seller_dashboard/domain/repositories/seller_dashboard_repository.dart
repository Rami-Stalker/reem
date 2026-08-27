import 'package:reem/features/seller_dashboard/domain/entities/seller_dashboard_data.dart';

abstract interface class SellerDashboardRepository {
  Future<SellerDashboardData> getDashboard();
}
