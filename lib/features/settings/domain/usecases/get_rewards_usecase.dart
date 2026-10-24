import 'package:ohara/core/result/result.dart';

import 'package:ohara/features/settings/domain/entities/rewards_entity.dart';
import 'package:ohara/features/settings/domain/repositories/settings_repository.dart';

class GetRewardsUseCase {
  const GetRewardsUseCase(this._repository);
  final SettingsRepository _repository;

  Future<Result<RewardsEntity>> call() => _repository.getRewards();
}
