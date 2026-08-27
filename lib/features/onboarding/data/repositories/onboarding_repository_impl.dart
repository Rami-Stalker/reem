import '../../domain/repositories/onboarding_repository.dart';
import '../datasources/onboarding_local_datasource.dart';

class OnboardingRepositoryImpl implements OnboardingRepository {
  const OnboardingRepositoryImpl(this._local);

  final OnboardingLocalDataSource _local;

  @override
  Future<bool> isComplete() => _local.isOnboardingComplete();

  @override
  Future<void> complete() => _local.setOnboardingComplete();
}
