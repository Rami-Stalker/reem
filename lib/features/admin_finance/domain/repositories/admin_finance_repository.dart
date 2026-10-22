import 'package:reem/core/result/result.dart';
import 'package:reem/features/admin_finance/domain/entities/finance_overview.dart';
import 'package:reem/features/admin_finance/domain/entities/pending_transfer.dart';

abstract interface class AdminFinanceRepository {
  Future<Result<FinanceOverview>> loadOverview();

  Future<Result<String>> syncExchangeRate();

  Future<Result<List<PendingTransfer>>> loadPendingTransfers();

  Future<Result<void>> confirmTransfer(String paymentId);

  Future<Result<void>> rejectTransfer(String paymentId, String reason);
}
