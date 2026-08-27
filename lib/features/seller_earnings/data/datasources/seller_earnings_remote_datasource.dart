import 'package:reem/features/seller_earnings/data/models/seller_earnings_model.dart';

abstract interface class SellerEarningsRemoteDataSource {
  Future<SellerEarningsModel> load();
}
