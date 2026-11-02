import 'package:ohara/features/seller_earnings/data/models/seller_earnings_model.dart';
import 'package:ohara/features/seller_earnings/domain/entities/seller_earnings.dart';

abstract interface class SellerEarningsRemoteDataSource {
  Future<SellerEarningsModel> load();

  /// What a withdrawal request would be worth right now, and what blocks one.
  Future<PayoutAvailability> payoutAvailability();

  /// Asks to be paid everything released. Creates a request; moves no money.
  Future<PendingPayout> requestPayout();

  /// Withdraws a request that nobody has approved yet.
  Future<PendingPayout> cancelPayout(String id);

  /// Her withdrawal history, newest first.
  Future<List<PendingPayout>> payoutHistory();

  /// Where she is paid, or null before she has said.
  Future<PayoutAccount?> payoutAccount();

  Future<PayoutAccount> savePayoutAccount({
    required PayoutMethod method,
    required String holderName,
    String? shamCashNumber,
    String? cardNumber,
  });

  Future<void> removePayoutAccount();

  /// «التقارير المالية» over the last [months] months.
  Future<SellerReport> report({int months = 12});
}
