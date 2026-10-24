import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import 'package:ohara/features/onboarding/data/datasources/impl/onboarding_local_datasource_impl.dart';
import 'package:ohara/features/onboarding/data/datasources/onboarding_local_datasource.dart';
import 'package:ohara/features/onboarding/data/repositories/onboarding_repository_impl.dart';
import 'package:ohara/features/onboarding/domain/repositories/onboarding_repository.dart';
import 'package:ohara/features/onboarding/domain/usecases/complete_onboarding_usecase.dart';
import 'package:ohara/features/onboarding/domain/usecases/is_onboarding_complete_usecase.dart';
import 'package:ohara/features/onboarding/presentation/providers/onboarding_notifier.dart';
import 'package:ohara/features/onboarding/presentation/providers/onboarding_state.dart';

final onboardingLocalDataSourceProvider = Provider<OnboardingLocalDataSource>(
  (ref) => OnboardingLocalDataSourceImpl(),
);

final onboardingRepositoryProvider = Provider<OnboardingRepository>(
  (ref) => OnboardingRepositoryImpl(ref.watch(onboardingLocalDataSourceProvider)),
);

final completeOnboardingUseCaseProvider = Provider(
  (ref) => CompleteOnboardingUseCase(
    ref.watch(onboardingRepositoryProvider),
  ),
);

final isOnboardingCompleteUseCaseProvider = Provider(
  (ref) => IsOnboardingCompleteUseCase(
    ref.watch(onboardingRepositoryProvider),
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
