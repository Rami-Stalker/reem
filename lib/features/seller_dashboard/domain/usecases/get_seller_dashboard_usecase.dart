import 'package:reem/features/seller_dashboard/domain/entities/seller_dashboard_data.dart';
import 'package:reem/features/seller_dashboard/domain/repositories/seller_dashboard_repository.dart';

final class GetSellerDashboardUseCase {
  const GetSellerDashboardUseCase(this._repo);

  final SellerDashboardRepository _repo;

  Future<SellerDashboardData> call() => _repo.getDashboard();
}
