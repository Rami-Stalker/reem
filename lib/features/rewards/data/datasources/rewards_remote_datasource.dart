import 'package:ohara/features/rewards/data/models/rewards_hub_model.dart';

abstract interface class RewardsRemoteDataSource {
  Future<RewardsHubModel> loadHub();

  Future<RewardsHubModel> applyReferralCode(String code);

  Future<RewardsHubModel> redeemReward(String rewardId);

  Future<RewardsHubModel> redeemCashback({double? amount});
}
