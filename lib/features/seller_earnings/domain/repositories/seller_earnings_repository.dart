import 'package:reem/core/result/result.dart';
import 'package:reem/features/seller_earnings/domain/entities/seller_earnings.dart';

abstract interface class SellerEarningsRepository {
  Future<Result<SellerEarnings>> load();
}
