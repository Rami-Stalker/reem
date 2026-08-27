import 'package:reem/core/result/result.dart';
import 'package:reem/features/admin_finance/domain/entities/finance_overview.dart';

abstract interface class AdminFinanceRepository {
  Future<Result<FinanceOverview>> loadOverview();

  Future<Result<String>> syncExchangeRate();
}
