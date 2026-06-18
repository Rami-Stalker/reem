import '../entities/seller_dashboard_data.dart';
import '../repositories/seller_dashboard_repository.dart';

final class GetSellerDashboardUseCase {
  const GetSellerDashboardUseCase(this._repo);

  final SellerDashboardRepository _repo;

  Future<SellerDashboardData> call() => _repo.getDashboard();
}
