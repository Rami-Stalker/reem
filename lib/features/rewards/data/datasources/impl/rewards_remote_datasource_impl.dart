import 'package:reem/core/network/api_endpoints.dart';
import 'package:reem/core/network/base_remote_datasource.dart';

import '../../models/rewards_hub_model.dart';
import '../rewards_remote_datasource.dart';

final class RewardsRemoteDataSourceImpl extends BaseRemoteDataSource
    implements RewardsRemoteDataSource {
  const RewardsRemoteDataSourceImpl(super.dio);

  @override
  Future<RewardsHubModel> loadHub() async {
    final rewardsJson = await getJson(ApiEndpoints.rewards);
    final referralJson = await getJson(ApiEndpoints.referralsMe);
    return RewardsHubModel.fromJson(
      rewardsJson: rewardsJson,
      referralJson: referralJson,
    );
  }

  @override
  Future<RewardsHubModel> applyReferralCode(String code) async {
    await postJson(ApiEndpoints.referralsApply, body: {'code': code});
    return loadHub();
  }

  @override
  Future<RewardsHubModel> redeemCashback({double? amount}) async {
    await postJson(
      ApiEndpoints.cashbackRedeem,
      body: amount == null ? null : {'amount': amount},
    );
    return loadHub();
  }

  @override
  Future<RewardsHubModel> redeemReward(String rewardId) async {
    await postJson(ApiEndpoints.membershipRewardRedeem(rewardId));
    return loadHub();
  }
}
