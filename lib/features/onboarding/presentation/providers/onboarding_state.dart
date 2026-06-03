class OnboardingState {
  const OnboardingState({
    this.isComplete = false,
    this.isLoading = false,
    this.error,
  });

  final bool isComplete;
  final bool isLoading;
  final String? error;

  OnboardingState copyWith({
    bool? isComplete,
    bool? isLoading,
    String? error,
    bool clearError = false,
  }) {
    return OnboardingState(
      isComplete: isComplete ?? this.isComplete,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
    );
  }
}
