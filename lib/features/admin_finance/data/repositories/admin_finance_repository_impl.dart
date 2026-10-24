import 'package:ohara/core/base/repository_handler.dart';
import 'package:ohara/core/result/result.dart';
import 'package:ohara/features/admin_finance/data/datasources/admin_finance_remote_datasource.dart';
import 'package:ohara/features/admin_finance/domain/entities/finance_overview.dart';
import 'package:ohara/features/admin_finance/domain/entities/pending_transfer.dart';
import 'package:ohara/features/admin_finance/domain/repositories/admin_finance_repository.dart';

class AdminFinanceRepositoryImpl
    with RepositoryHandler
    implements AdminFinanceRepository {
  const AdminFinanceRepositoryImpl(this.remote);

  final AdminFinanceRemoteDataSource remote;

  @override
  Future<Result<FinanceOverview>> loadOverview() =>
      guard(() => remote.loadOverview());

  @override
  Future<Result<String>> syncExchangeRate() =>
      guard(() => remote.syncExchangeRate());

  @override
  Future<Result<List<PendingTransfer>>> loadPendingTransfers() =>
      guard(() => remote.loadPendingTransfers());

  @override
  Future<Result<void>> confirmTransfer(String paymentId) =>
      guard(() => remote.confirmTransfer(paymentId));

  @override
  Future<Result<void>> rejectTransfer(String paymentId, String reason) =>
      guard(() => remote.rejectTransfer(paymentId, reason));
}
