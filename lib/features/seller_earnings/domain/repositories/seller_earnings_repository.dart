import 'package:ohara/core/result/result.dart';
import 'package:ohara/features/seller_earnings/domain/entities/seller_earnings.dart';

abstract interface class SellerEarningsRepository {
  Future<Result<SellerEarnings>> load();

  Future<Result<PayoutAvailability>> payoutAvailability();

  Future<Result<PendingPayout>> requestPayout();

  Future<Result<PendingPayout>> cancelPayout(String id);

  Future<Result<List<PendingPayout>>> payoutHistory();
}
