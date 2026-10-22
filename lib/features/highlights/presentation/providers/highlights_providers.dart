import 'package:flutter/foundation.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import 'package:reem/core/base/repository_handler.dart';
import 'package:reem/core/presentation/providers/core_providers.dart';
import 'package:reem/core/result/result.dart';
import 'package:reem/core/shared/entities/story.dart';
import 'package:reem/features/auth/presentation/providers/auth_provider.dart';
import 'package:reem/features/highlights/data/datasources/highlights_remote_datasource.dart';
import 'package:reem/features/highlights/domain/entities/highlight.dart';

final highlightsDataSourceProvider = Provider<HighlightsRemoteDataSource>(
  (ref) => HighlightsRemoteDataSource(ref.watch(dioProvider)),
);

/// One page's rail.
///
/// Keyed by the owner's id, with the empty string meaning "mine" — a family
/// rather than one notifier because her own profile and a boutique she is
/// looking at are on screen at the same time whenever she opens a storefront
/// from her own page.
///
/// Rebuilt when the account changes, because `is_mine` — the one thing that
/// decides whether the edit affordances are drawn — is a fact about who is
/// looking.
final highlightsProvider = StateNotifierProvider.autoDispose
    .family<HighlightsNotifier, HighlightsState, String>((ref, ownerId) {
      ref.watch(authNotifierProvider.select((s) => s.user?.id));
      return HighlightsNotifier(
        ref.watch(highlightsDataSourceProvider),
        ownerId: ownerId.isEmpty ? null : ownerId,
      )..load();
    });

/// Her own stories, live and expired — what a shelf can be filled from.
final highlightArchiveProvider = FutureProvider.autoDispose<List<Story>>((
  ref,
) async {
  return ref.watch(highlightsDataSourceProvider).archive();
});

@immutable
class HighlightsState {
  const HighlightsState({
    this.highlights = const [],
    this.isLoading = true,
    this.isMutating = false,
    this.error,
  });

  final List<Highlight> highlights;
  final bool isLoading;
  final bool isMutating;
  final String? error;

  bool get isEmpty => highlights.isEmpty;

  HighlightsState copyWith({
    List<Highlight>? highlights,
    bool? isLoading,
    bool? isMutating,
    String? error,
    bool clearError = false,
  }) => HighlightsState(
    highlights: highlights ?? this.highlights,
    isLoading: isLoading ?? this.isLoading,
    isMutating: isMutating ?? this.isMutating,
    error: clearError ? null : (error ?? this.error),
  );
}

class HighlightsNotifier extends StateNotifier<HighlightsState>
    with RepositoryHandler {
  HighlightsNotifier(this._remote, {String? ownerId})
    : _ownerId = ownerId,
      super(const HighlightsState());

  final HighlightsRemoteDataSource _remote;

  /// Null means "the signed-in account's own rail".
  final String? _ownerId;

  Future<void> load() async {
    state = state.copyWith(isLoading: true, clearError: true);
    final result = await guard(() => _remote.listFor(_ownerId));
    if (!mounted) return;
    state = switch (result) {
      Success(:final data) => state.copyWith(
        isLoading: false,
        highlights: data,
      ),
      // A private page, or no connection. Either way the rail simply is not
      // drawn — a page that shouts about a shelf you may not see is worse
      // than one that does not mention it.
      Error(:final failure) => state.copyWith(
        isLoading: false,
        highlights: const [],
        error: failure.message,
      ),
    };
  }

  Future<Highlight?> create({
    required String title,
    List<String> contentIds = const [],
  }) async {
    final result = await _mutate(
      () => _remote.create(title: title, contentIds: contentIds),
    );
    return result;
  }

  Future<Highlight?> rename(String id, String title) =>
      _mutate(() => _remote.update(id, title: title));

  Future<Highlight?> addStory(String id, String contentId) =>
      _mutate(() => _remote.addItem(id, contentId));

  Future<Highlight?> removeStory(String id, String contentId) =>
      _mutate(() => _remote.removeItem(id, contentId));

  Future<bool> remove(String id) async {
    state = state.copyWith(isMutating: true, clearError: true);
    final result = await guard(() => _remote.remove(id));
    if (!mounted) return false;
    if (result case Error(:final failure)) {
      state = state.copyWith(isMutating: false, error: failure.message);
      return false;
    }
    state = state.copyWith(isMutating: false);
    await load();
    return true;
  }

  /// The detail read, which is the only one that carries the stories.
  Future<Highlight?> detail(String id) async {
    final result = await guard(() => _remote.detail(id));
    return switch (result) {
      Success(:final data) => data,
      Error() => null,
    };
  }

  Future<Highlight?> _mutate(Future<Highlight> Function() action) async {
    state = state.copyWith(isMutating: true, clearError: true);
    final result = await guard(action);
    if (!mounted) return null;
    switch (result) {
      case Success(:final data):
        state = state.copyWith(isMutating: false);
        await load();
        return data;
      case Error(:final failure):
        state = state.copyWith(isMutating: false, error: failure.message);
        return null;
    }
  }
}
