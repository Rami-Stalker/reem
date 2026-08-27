import 'package:reem/core/network/api_endpoints.dart';
import 'package:reem/core/network/base_remote_datasource.dart';

import '../../models/seller_earnings_model.dart';
import '../seller_earnings_remote_datasource.dart';

final class SellerEarningsRemoteDataSourceImpl extends BaseRemoteDataSource
    implements SellerEarningsRemoteDataSource {
  const SellerEarningsRemoteDataSourceImpl(super.dio);

  @override
  Future<SellerEarningsModel> load() async {
    final json = await getJson(ApiEndpoints.sellerEarnings);
    return SellerEarningsModel.fromJson(json);
  }
}
