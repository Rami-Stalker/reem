import 'package:reem/core/result/result.dart';

import '../entities/rewards_entity.dart';
import '../repositories/settings_repository.dart';

class GetRewardsUseCase {
  const GetRewardsUseCase(this._repository);
  final SettingsRepository _repository;

  Future<Result<RewardsEntity>> call() => _repository.getRewards();
}
