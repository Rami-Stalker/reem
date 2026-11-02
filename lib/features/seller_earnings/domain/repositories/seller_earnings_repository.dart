import 'package:ohara/core/result/result.dart';
import 'package:ohara/features/seller_earnings/domain/entities/seller_earnings.dart';

abstract interface class SellerEarningsRepository {
  Future<Result<SellerEarnings>> load();

  Future<Result<PayoutAvailability>> payoutAvailability();

  Future<Result<PendingPayout>> requestPayout();

  Future<Result<PendingPayout>> cancelPayout(String id);

  Future<Result<List<PendingPayout>>> payoutHistory();

  Future<Result<PayoutAccount?>> payoutAccount();

  Future<Result<PayoutAccount>> savePayoutAccount({
    required PayoutMethod method,
    required String holderName,
    String? shamCashNumber,
    String? cardNumber,
  });

  Future<Result<void>> removePayoutAccount();

  Future<Result<SellerReport>> report({int months = 12});
}
