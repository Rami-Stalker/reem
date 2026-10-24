import 'package:ohara/features/onboarding/domain/repositories/onboarding_repository.dart';

class IsOnboardingCompleteUseCase {
  const IsOnboardingCompleteUseCase(this._repository);
  final OnboardingRepository _repository;

  Future<bool> call() => _repository.isComplete();
}
