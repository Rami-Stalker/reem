import '../../domain/entities/profile_overview.dart';

/// State for the aggregated profile-centre overview.
class ProfileOverviewState {
  const ProfileOverviewState({
    this.isLoading = true,
    this.overview,
    this.error,
  });

  final bool isLoading;
  final ProfileOverview? overview;
  final String? error;

  bool get hasOverview => overview != null;
  bool get isInitialLoading => isLoading && overview == null;

  ProfileOverviewState copyWith({
    bool? isLoading,
    ProfileOverview? overview,
    String? error,
    bool clearError = false,
  }) {
    return ProfileOverviewState(
      isLoading: isLoading ?? this.isLoading,
      overview: overview ?? this.overview,
      error: clearError ? null : (error ?? this.error),
    );
  }
}
