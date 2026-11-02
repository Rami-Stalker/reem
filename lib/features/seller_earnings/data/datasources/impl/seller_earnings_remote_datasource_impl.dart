import 'package:ohara/core/errors/app_exception.dart';
import 'package:ohara/core/network/api_endpoints.dart';
import 'package:ohara/core/network/base_remote_datasource.dart';
import 'package:ohara/features/seller_earnings/data/datasources/seller_earnings_remote_datasource.dart';
import 'package:ohara/features/seller_earnings/data/models/seller_earnings_model.dart';
import 'package:ohara/features/seller_earnings/domain/entities/seller_earnings.dart';

final class SellerEarningsRemoteDataSourceImpl extends BaseRemoteDataSource
    implements SellerEarningsRemoteDataSource {
  const SellerEarningsRemoteDataSourceImpl(super.dio);

  @override
  Future<SellerEarningsModel> load() async {
    final json = await getJson(ApiEndpoints.sellerEarnings);
    return SellerEarningsModel.fromJson(json);
  }

  @override
  Future<PayoutAvailability> payoutAvailability() async =>
      SellerEarningsModel.availabilityFromJson(
        await getJson(ApiEndpoints.sellerPayoutAvailability),
      );

  @override
  Future<PendingPayout> requestPayout() async =>
      SellerEarningsModel.payoutFromJson(
        await postJson(ApiEndpoints.sellerPayouts),
      );

  @override
  Future<PendingPayout> cancelPayout(String id) async =>
      SellerEarningsModel.payoutFromJson(
        await postJson(ApiEndpoints.sellerPayoutCancel(id)),
      );

  @override
  Future<List<PendingPayout>> payoutHistory() async => [
    for (final row in (await getList(
      ApiEndpoints.sellerPayouts,
    )).whereType<Map>())
      SellerEarningsModel.payoutFromJson(row.cast<String, dynamic>()),
  ];

  @override
  Future<PayoutAccount?> payoutAccount() async {
    final json = await getJson(ApiEndpoints.sellerPayoutAccount);
    return SellerEarningsModel.accountFromJson(json['account']);
  }

  @override
  Future<PayoutAccount> savePayoutAccount({
    required PayoutMethod method,
    required String holderName,
    String? shamCashNumber,
    String? cardNumber,
  }) async {
    final json = await putJson(
      ApiEndpoints.sellerPayoutAccount,
      body: {
        'method': method.wire,
        'holder_name': holderName,
        'sham_cash_number': ?shamCashNumber,
        'card_number': ?cardNumber,
      },
    );
    final account = SellerEarningsModel.accountFromJson(json);
    if (account == null) {
      throw const ServerException('Invalid response format from server.');
    }
    return account;
  }

  @override
  Future<void> removePayoutAccount() =>
      deleteRequest(ApiEndpoints.sellerPayoutAccount);

  @override
  Future<SellerReport> report({int months = 12}) async =>
      SellerEarningsModel.reportFromJson(
        await getJson(
          ApiEndpoints.sellerReports,
          query: {'months': months},
        ),
      );
}
