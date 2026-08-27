import '../models/seller_earnings_model.dart';

abstract interface class SellerEarningsRemoteDataSource {
  Future<SellerEarningsModel> load();
}
