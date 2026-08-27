import '../models/wallet_models.dart';

abstract interface class WalletRemoteDataSource {
  /// Balance plus the first page of the statement.
  Future<WalletSummaryModel> load({int take});

  /// Q43 — converts loyalty points into spendable credit.
  Future<WalletSummaryModel> convertPoints(int points);
}
