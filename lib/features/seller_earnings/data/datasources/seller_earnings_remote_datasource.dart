import 'package:reem/features/seller_earnings/data/models/seller_earnings_model.dart';
import 'package:reem/features/seller_earnings/domain/entities/seller_earnings.dart';

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
}
