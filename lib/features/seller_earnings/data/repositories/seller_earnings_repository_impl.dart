import 'package:reem/core/base/repository_handler.dart';
import 'package:reem/core/result/result.dart';
import 'package:reem/features/seller_earnings/data/datasources/seller_earnings_remote_datasource.dart';
import 'package:reem/features/seller_earnings/domain/entities/seller_earnings.dart';
import 'package:reem/features/seller_earnings/domain/repositories/seller_earnings_repository.dart';

class SellerEarningsRepositoryImpl
    with RepositoryHandler
    implements SellerEarningsRepository {
  const SellerEarningsRepositoryImpl(this.remote);

  final SellerEarningsRemoteDataSource remote;

  @override
  Future<Result<SellerEarnings>> load() => guard(() => remote.load());
}
