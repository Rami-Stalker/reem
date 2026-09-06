import 'package:reem/core/network/api_endpoints.dart';
import 'package:reem/core/network/base_remote_datasource.dart';
import 'package:reem/features/seller_earnings/data/datasources/seller_earnings_remote_datasource.dart';
import 'package:reem/features/seller_earnings/data/models/seller_earnings_model.dart';
import 'package:reem/features/seller_earnings/domain/entities/seller_earnings.dart';

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
}
