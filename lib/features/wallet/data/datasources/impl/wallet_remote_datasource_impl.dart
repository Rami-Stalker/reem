import 'package:ohara/core/network/api_endpoints.dart';
import 'package:ohara/core/network/base_remote_datasource.dart';
import 'package:ohara/features/wallet/data/datasources/wallet_remote_datasource.dart';
import 'package:ohara/features/wallet/data/models/wallet_models.dart';

final class WalletRemoteDataSourceImpl extends BaseRemoteDataSource
    implements WalletRemoteDataSource {
  const WalletRemoteDataSourceImpl(super.dio);

  @override
  Future<WalletSummaryModel> load({int take = 30}) async {
    // Two calls because the balance is authoritative on its own — a statement
    // that fails to page must not blank out the figure she came to see.
    final balance = await getJson(ApiEndpoints.wallet);

    Map<String, dynamic>? statement;
    try {
      statement = await getJson(
        ApiEndpoints.walletTransactions,
        query: {'take': take},
      );
    } catch (_) {
      statement = null;
    }

    return WalletSummaryModel.from(
      balanceJson: balance,
      statementJson: statement,
    );
  }

  @override
  Future<WalletSummaryModel> convertPoints(int points) async {
    await postJson(ApiEndpoints.loyaltyConvert, body: {'points': points});
    return load();
  }
}
