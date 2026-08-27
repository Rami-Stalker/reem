import 'package:reem/features/onboarding/domain/repositories/onboarding_repository.dart';

class CompleteOnboardingUseCase {
  const CompleteOnboardingUseCase(this._repository);
  final OnboardingRepository _repository;

  Future<void> call() => _repository.complete();
}
