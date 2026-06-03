import '../../data/datasources/onboarding_local_datasource.dart';

class CompleteOnboardingUseCase {
  const CompleteOnboardingUseCase(this._local);
  final OnboardingLocalDataSource _local;

  Future<void> call() => _local.setOnboardingComplete();
}
