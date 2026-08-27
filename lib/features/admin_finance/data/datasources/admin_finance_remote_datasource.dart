import '../models/finance_overview_model.dart';

abstract interface class AdminFinanceRemoteDataSource {
  Future<FinanceOverviewModel> loadOverview();

  /// Pulls the exchange rate now instead of waiting for the morning run.
  Future<String> syncExchangeRate();
}
