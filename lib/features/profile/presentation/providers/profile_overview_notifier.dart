import 'package:flutter_riverpod/legacy.dart';

import 'package:reem/core/result/result.dart';
import 'package:reem/features/profile/domain/usecases/get_profile_overview_usecase.dart';
import 'package:reem/features/profile/presentation/providers/profile_overview_state.dart';

/// Loads and refreshes the profile-centre overview, keeping the last good data
/// on screen during a refresh.
class ProfileOverviewNotifier extends StateNotifier<ProfileOverviewState> {
  ProfileOverviewNotifier(this._getOverview)
      : super(const ProfileOverviewState());

  final GetProfileOverviewUseCase _getOverview;

  Future<void> load() async {
    state = state.copyWith(isLoading: true, clearError: true);
    final result = await _getOverview();
    if (!mounted) return;
    switch (result) {
      case Success(:final data):
        state = ProfileOverviewState(isLoading: false, overview: data);
      case Error(:final failure):
        state = state.copyWith(isLoading: false, error: failure.message);
    }
  }

  Future<void> refresh() => load();
}
