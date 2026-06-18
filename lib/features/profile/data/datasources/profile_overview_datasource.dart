import '../../domain/entities/profile_overview.dart';

/// Boundary for the profile-centre overview. Fulfilled today by
/// [ProfileOverviewMockDataSource]; swap to a remote implementation in
/// `profile_overview_provider.dart` with no change above this interface.
abstract interface class ProfileOverviewDataSource {
  Future<ProfileOverview> getOverview();
}
