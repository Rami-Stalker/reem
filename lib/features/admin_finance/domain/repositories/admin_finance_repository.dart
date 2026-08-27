import '../../../../core/result/result.dart';
import '../entities/finance_overview.dart';

abstract interface class AdminFinanceRepository {
  Future<Result<FinanceOverview>> loadOverview();

  Future<Result<String>> syncExchangeRate();
}
