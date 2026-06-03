import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../../data/datasources/impl/onboarding_local_datasource_impl.dart';
import '../../data/datasources/onboarding_local_datasource.dart';
import '../../domain/usecases/complete_onboarding_usecase.dart';
import '../../domain/usecases/is_onboarding_complete_usecase.dart';
import 'onboarding_notifier.dart';
import 'onboarding_state.dart';

final onboardingLocalDataSourceProvider = Provider<OnboardingLocalDataSource>(
  (ref) => OnboardingLocalDataSourceImpl(),
);

final completeOnboardingUseCaseProvider = Provider(
  (ref) => CompleteOnboardingUseCase(
    ref.watch(onboardingLocalDataSourceProvider),
  ),
);

final isOnboardingCompleteUseCaseProvider = Provider(
  (ref) => IsOnboardingCompleteUseCase(
    ref.watch(onboardingLocalDataSourceProvider),
  ),
);

final onboardingNotifierProvider =
    StateNotifierProvider<OnboardingNotifier, OnboardingState>((ref) {
  return OnboardingNotifier(
    completeOnboardingUseCase: ref.watch(completeOnboardingUseCaseProvider),
    isOnboardingCompleteUseCase:
        ref.watch(isOnboardingCompleteUseCaseProvider),
  );
});
