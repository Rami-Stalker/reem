import '../../data/datasources/onboarding_local_datasource.dart';

class IsOnboardingCompleteUseCase {
  const IsOnboardingCompleteUseCase(this._local);
  final OnboardingLocalDataSource _local;

  Future<bool> call() => _local.isOnboardingComplete();
}
