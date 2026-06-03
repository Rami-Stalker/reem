abstract interface class OnboardingLocalDataSource {
  Future<bool> isOnboardingComplete();

  Future<void> setOnboardingComplete();
}
