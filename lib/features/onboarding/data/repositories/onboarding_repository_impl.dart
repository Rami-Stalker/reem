import 'package:ohara/features/onboarding/data/datasources/onboarding_local_datasource.dart';
import 'package:ohara/features/onboarding/domain/repositories/onboarding_repository.dart';

class OnboardingRepositoryImpl implements OnboardingRepository {
  const OnboardingRepositoryImpl(this._local);

  final OnboardingLocalDataSource _local;

  @override
  Future<bool> isComplete() => _local.isOnboardingComplete();

  @override
  Future<void> complete() => _local.setOnboardingComplete();
}
