import 'package:flutter_riverpod/legacy.dart';

import 'package:ohara/core/result/result.dart';
import 'package:ohara/features/home/domain/usecases/get_home_content_usecase.dart';
import 'package:ohara/features/home/presentation/providers/home_content_state.dart';

/// Loads and refreshes the home page's bespoke merchandising content. Keeps the
/// last successful content on screen during a refresh so pull-to-refresh never
/// blanks the page.
class HomeContentNotifier extends StateNotifier<HomeContentState> {
  HomeContentNotifier(this._getHomeContent) : super(const HomeContentState());

  final GetHomeContentUseCase _getHomeContent;

  Future<void> load() async {
    state = state.copyWith(isLoading: true, clearError: true);
    final result = await _getHomeContent();
    if (!mounted) return;
    switch (result) {
      case Success(:final data):
        state = HomeContentState(isLoading: false, content: data);
      case Error(:final failure):
        state = state.copyWith(isLoading: false, error: failure.message);
    }
  }

  Future<void> refresh() => load();
}
