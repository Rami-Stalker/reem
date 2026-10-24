import 'dart:typed_data';

import 'package:flutter_riverpod/legacy.dart';
import 'package:ohara/core/result/result.dart';
import 'package:ohara/features/ai_stylist/domain/entities/stylist_recommendation.dart';
import 'package:ohara/features/visual_search/domain/entities/visual_search_session.dart';
import 'package:ohara/features/visual_search/domain/repositories/visual_search_repository.dart';
import 'package:ohara/features/visual_search/presentation/providers/visual_search_state.dart';

/// Drives one search-by-image.
///
/// Nothing here is optimistic. The stylist can show her own bubble the instant
/// she taps send, because that text is hers and cannot be wrong; a visual
/// search has no such half. Every chip, every percentage and every card comes
/// from the server, so the screen shows her photograph and an honest "عم
/// بدوّر" until it does. A guessed chip that the server then contradicts would
/// undermine the one thing this feature has to be trusted about.
class VisualSearchNotifier extends StateNotifier<VisualSearchState> {
  VisualSearchNotifier(this._repository, {String? sessionId})
    : super(VisualSearchState.initial) {
    _load(sessionId);
  }

  final VisualSearchRepository _repository;

  Future<void> _load(String? sessionId) async {
    final bootstrap = await _repository.bootstrap();
    if (!mounted) return;

    state = switch (bootstrap) {
      Success(:final data) => state.copyWith(
        isLoadingBootstrap: false,
        bootstrap: data,
        clearFailure: true,
      ),
      // A failed bootstrap is not a failed screen: she can still pick a
      // photograph, and the limits fall back to the compiled defaults. The
      // failure is surfaced only if the search itself then fails.
      Error() => state.copyWith(isLoadingBootstrap: false),
    };

    if (sessionId != null) await openSession(sessionId);
  }

  /// Refresh the readiness figures — used when she pulls to refresh a screen
  /// that told her the index was still building.
  Future<void> refreshBootstrap() async {
    final result = await _repository.bootstrap();
    if (!mounted) return;
    if (result case Success(:final data)) {
      state = state.copyWith(bootstrap: data);
    }
  }

  /// Upload a photograph and search with it.
  Future<void> searchWithImage({
    required Uint8List bytes,
    required String filename,
    required VisualSearchSource source,
    String? note,
  }) async {
    if (state.isBusy) return;

    state = state.copyWith(
      phase: VisualSearchPhase.uploading,
      uploadProgress: 0,
      clearFailure: true,
      clearSession: true,
      clearSelectedRegion: true,
    );

    final result = await _repository.search(
      bytes: bytes,
      filename: filename,
      source: source,
      note: note,
      onProgress: (progress) {
        if (!mounted) return;
        // The last byte leaving the phone is not the answer arriving. Flip to
        // "analysing" at 100% so the ring stops pretending to make progress
        // while the server decodes, describes and searches.
        state = state.copyWith(
          uploadProgress: progress,
          phase: progress >= 1
              ? VisualSearchPhase.analysing
              : VisualSearchPhase.uploading,
        );
      },
    );
    if (!mounted) return;

    state = switch (result) {
      Success(:final data) => state.copyWith(
        phase: VisualSearchPhase.ready,
        session: data,
        uploadProgress: 1,
        clearFailure: true,
        clearSelectedRegion: true,
      ),
      Error(:final failure) => state.copyWith(
        phase: VisualSearchPhase.idle,
        failure: failure,
        uploadProgress: 0,
      ),
    };
  }

  /// Fold one typed sentence onto the current search.
  ///
  /// Works after her photograph has been deleted by the retention clock: the
  /// server refines against the descriptor it stored, not against the image.
  Future<void> refine(String text) async {
    final trimmed = text.trim();
    final session = state.session;
    if (trimmed.isEmpty || session == null || state.isBusy) return;

    state = state.copyWith(
      phase: VisualSearchPhase.refining,
      clearFailure: true,
    );

    final result = await _repository.refine(
      sessionId: session.id,
      text: trimmed,
    );
    if (!mounted) return;

    state = switch (result) {
      Success(:final data) => state.copyWith(
        phase: VisualSearchPhase.ready,
        session: data,
        clearFailure: true,
        clearSelectedRegion: true,
      ),
      // The previous results stay on screen. She asked for a change and did
      // not get one; taking away what she already had as well would be two
      // losses for one failure.
      Error(:final failure) => state.copyWith(
        phase: VisualSearchPhase.ready,
        failure: failure,
        failedRefinement: trimmed,
      ),
    };
  }

  Future<void> openSession(String sessionId) async {
    state = state.copyWith(
      phase: VisualSearchPhase.analysing,
      clearFailure: true,
    );

    final result = await _repository.session(sessionId);
    if (!mounted) return;

    state = switch (result) {
      Success(:final data) => state.copyWith(
        phase: VisualSearchPhase.ready,
        session: data,
        clearFailure: true,
        clearSelectedRegion: true,
      ),
      Error(:final failure) => state.copyWith(
        phase: VisualSearchPhase.idle,
        failure: failure,
      ),
    };
  }

  void selectRegion(String regionId) {
    if (state.session == null) return;
    state = state.copyWith(selectedRegionId: regionId);
  }

  /// Back to the empty screen, keeping the bootstrap she already fetched.
  void reset() {
    state = state.copyWith(
      phase: VisualSearchPhase.idle,
      uploadProgress: 0,
      clearSession: true,
      clearSelectedRegion: true,
      clearFailure: true,
    );
  }

  /// Delete this search and the photograph behind it.
  Future<bool> forgetCurrent() async {
    final session = state.session;
    if (session == null) return false;

    final result = await _repository.forget(session.id);
    if (!mounted) return false;

    if (result case Error(:final failure)) {
      state = state.copyWith(failure: failure);
      return false;
    }

    reset();
    await refreshBootstrap();
    return true;
  }

  /// Record what she did with a card.
  ///
  /// Applied locally first because it is her own action on her own screen and
  /// cannot be contradicted — unlike anything the search itself produces. A
  /// failure rolls it back rather than leaving a heart lit that the server
  /// never heard about.
  Future<void> sendFeedback(String resultId, StylistFeedback feedback) async {
    final session = state.session;
    if (session == null) return;

    final previous = session;
    state = state.copyWith(session: _applyFeedback(session, resultId, feedback));

    final result = await _repository.sendFeedback(
      resultId: resultId,
      feedback: feedback,
    );
    if (!mounted) return;

    if (result case Error(:final failure)) {
      state = state.copyWith(session: previous, failure: failure);
    }
  }

  VisualSearchSession _applyFeedback(
    VisualSearchSession session,
    String resultId,
    StylistFeedback feedback,
  ) => session.copyWithRegions(
    session.regions
        .map(
          (region) => region.withMatches(
            region.matches
                .map(
                  (match) =>
                      match.id == resultId ? match.withFeedback(feedback) : match,
                )
                .toList(growable: false),
          ),
        )
        .toList(growable: false),
  );
}
