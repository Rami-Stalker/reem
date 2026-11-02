import 'package:ohara/core/base/repository_handler.dart';
import 'package:ohara/core/result/result.dart';
import 'package:ohara/features/seller_earnings/data/datasources/seller_earnings_remote_datasource.dart';
import 'package:ohara/features/seller_earnings/domain/entities/seller_earnings.dart';
import 'package:ohara/features/seller_earnings/domain/repositories/seller_earnings_repository.dart';

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

  @override
  Future<Result<PayoutAccount?>> payoutAccount() => guard(remote.payoutAccount);

  @override
  Future<Result<PayoutAccount>> savePayoutAccount({
    required PayoutMethod method,
    required String holderName,
    String? shamCashNumber,
    String? cardNumber,
  }) => guard(
    () => remote.savePayoutAccount(
      method: method,
      holderName: holderName,
      shamCashNumber: shamCashNumber,
      cardNumber: cardNumber,
    ),
  );

  @override
  Future<Result<void>> removePayoutAccount() =>
      guard(remote.removePayoutAccount);

  @override
  Future<Result<SellerReport>> report({int months = 12}) =>
      guard(() => remote.report(months: months));
}
