import 'package:flutter_riverpod/legacy.dart';

import '../../domain/usecases/complete_onboarding_usecase.dart';
import '../../domain/usecases/is_onboarding_complete_usecase.dart';
import 'onboarding_state.dart';

class OnboardingNotifier extends StateNotifier<OnboardingState> {
  OnboardingNotifier({
    required CompleteOnboardingUseCase completeOnboardingUseCase,
    required IsOnboardingCompleteUseCase isOnboardingCompleteUseCase,
  })  : _complete = completeOnboardingUseCase,
        _isComplete = isOnboardingCompleteUseCase,
        super(const OnboardingState()) {
    checkStatus();
  }

  final CompleteOnboardingUseCase _complete;
  final IsOnboardingCompleteUseCase _isComplete;

  Future<void> checkStatus() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final complete = await _isComplete();
      state = state.copyWith(isLoading: false, isComplete: complete);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<bool> checkComplete() async {
    await checkStatus();
    return state.isComplete;
  }

  Future<void> complete() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      await _complete();
      state = state.copyWith(isLoading: false, isComplete: true);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }
}
