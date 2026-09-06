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

  @override
  Future<Result<PayoutAvailability>> payoutAvailability() =>
      guard(remote.payoutAvailability);

  @override
  Future<Result<PendingPayout>> requestPayout() => guard(remote.requestPayout);

  @override
  Future<Result<PendingPayout>> cancelPayout(String id) =>
      guard(() => remote.cancelPayout(id));

  @override
  Future<Result<List<PendingPayout>>> payoutHistory() =>
      guard(remote.payoutHistory);
}
