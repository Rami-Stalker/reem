import '../../../../core/result/result.dart';
import '../entities/seller_earnings.dart';

abstract interface class SellerEarningsRepository {
  Future<Result<SellerEarnings>> load();
}
