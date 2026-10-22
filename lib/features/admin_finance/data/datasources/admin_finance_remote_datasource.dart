import 'package:reem/features/admin_finance/data/models/finance_overview_model.dart';
import 'package:reem/features/admin_finance/data/models/pending_transfer_model.dart';

abstract interface class AdminFinanceRemoteDataSource {
  Future<FinanceOverviewModel> loadOverview();

  /// Pulls the exchange rate now instead of waiting for the morning run.
  Future<String> syncExchangeRate();

  /// Q51 — transfers waiting for finance to match them.
  Future<List<PendingTransferModel>> loadPendingTransfers();

  Future<void> confirmTransfer(String paymentId);

  Future<void> rejectTransfer(String paymentId, String reason);
}
