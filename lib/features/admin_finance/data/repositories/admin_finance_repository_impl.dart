import 'package:reem/core/base/repository_handler.dart';
import 'package:reem/core/result/result.dart';
import 'package:reem/features/admin_finance/data/datasources/admin_finance_remote_datasource.dart';
import 'package:reem/features/admin_finance/domain/entities/finance_overview.dart';
import 'package:reem/features/admin_finance/domain/repositories/admin_finance_repository.dart';

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
}
