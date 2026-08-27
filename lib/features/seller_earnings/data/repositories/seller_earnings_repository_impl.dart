import 'package:reem/core/base/repository_handler.dart';
import 'package:reem/core/result/result.dart';

import '../../domain/entities/seller_earnings.dart';
import '../../domain/repositories/seller_earnings_repository.dart';
import '../datasources/seller_earnings_remote_datasource.dart';

class SellerEarningsRepositoryImpl
    with RepositoryHandler
    implements SellerEarningsRepository {
  const SellerEarningsRepositoryImpl(this.remote);

  final SellerEarningsRemoteDataSource remote;

  @override
  Future<Result<SellerEarnings>> load() => guard(() => remote.load());
}
