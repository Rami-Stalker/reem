import 'package:reem/core/base/repository_handler.dart';
import 'package:reem/core/result/result.dart';

import '../../domain/entities/rewards_hub.dart';
import '../../domain/repositories/rewards_repository.dart';
import '../datasources/rewards_remote_datasource.dart';

class RewardsRepositoryImpl
    with RepositoryHandler
    implements RewardsRepository {
  const RewardsRepositoryImpl(this.remote);

  final RewardsRemoteDataSource remote;

  @override
  Future<Result<RewardsHub>> loadHub() => guard(() => remote.loadHub());

  @override
  Future<Result<RewardsHub>> applyReferralCode(String code) =>
      guard(() => remote.applyReferralCode(code));

  @override
  Future<Result<RewardsHub>> redeemCashback({double? amount}) =>
      guard(() => remote.redeemCashback(amount: amount));

  @override
  Future<Result<RewardsHub>> redeemReward(String rewardId) =>
      guard(() => remote.redeemReward(rewardId));
}
