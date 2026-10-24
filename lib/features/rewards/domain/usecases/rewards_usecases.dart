import 'package:ohara/core/result/result.dart';

import 'package:ohara/features/rewards/domain/entities/rewards_hub.dart';
import 'package:ohara/features/rewards/domain/repositories/rewards_repository.dart';

class LoadRewardsHubUseCase {
  const LoadRewardsHubUseCase(this.repository);

  final RewardsRepository repository;

  Future<Result<RewardsHub>> call() => repository.loadHub();
}

class ApplyReferralCodeUseCase {
  const ApplyReferralCodeUseCase(this.repository);

  final RewardsRepository repository;

  Future<Result<RewardsHub>> call(String code) =>
      repository.applyReferralCode(code);
}

class RedeemLoyaltyRewardUseCase {
  const RedeemLoyaltyRewardUseCase(this.repository);

  final RewardsRepository repository;

  Future<Result<RewardsHub>> call(String rewardId) =>
      repository.redeemReward(rewardId);
}

class RedeemCashbackUseCase {
  const RedeemCashbackUseCase(this.repository);

  final RewardsRepository repository;

  Future<Result<RewardsHub>> call({double? amount}) =>
      repository.redeemCashback(amount: amount);
}
