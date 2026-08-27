import 'package:reem/core/network/api_endpoints.dart';
import 'package:reem/core/network/base_remote_datasource.dart';
import 'package:reem/features/admin_finance/data/datasources/admin_finance_remote_datasource.dart';
import 'package:reem/features/admin_finance/data/models/finance_overview_model.dart';

final class AdminFinanceRemoteDataSourceImpl extends BaseRemoteDataSource
    implements AdminFinanceRemoteDataSource {
  const AdminFinanceRemoteDataSourceImpl(super.dio);

  @override
  Future<FinanceOverviewModel> loadOverview() async {
    final json = await getJson(ApiEndpoints.adminFinanceOverview);
    return FinanceOverviewModel.fromJson(json);
  }

  @override
  Future<String> syncExchangeRate() async {
    final json = await postJson(ApiEndpoints.adminFxSync);
    // The endpoint reports *why* a rate was not published rather than failing,
    // so a refused sync is a message to show, not an error to throw.
    if (json['published'] == true) {
      return json['rate'] as String? ?? '';
    }
    return (json['detail'] as String?) ??
        (json['reason'] as String?) ??
        'unchanged';
  }
}
