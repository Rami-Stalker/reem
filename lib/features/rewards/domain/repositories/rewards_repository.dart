import 'package:ohara/core/result/result.dart';

import 'package:ohara/features/rewards/domain/entities/rewards_hub.dart';

abstract interface class RewardsRepository {
  Future<Result<RewardsHub>> loadHub();

  Future<Result<RewardsHub>> applyReferralCode(String code);

  Future<Result<RewardsHub>> redeemReward(String rewardId);

  Future<Result<RewardsHub>> redeemCashback({double? amount});
}
