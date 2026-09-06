import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:reem/core/presentation/providers/core_providers.dart';
import 'package:reem/core/result/result.dart';
import 'package:reem/features/ai_stylist/data/datasources/ai_stylist_remote_datasource.dart';
import 'package:reem/features/ai_stylist/data/datasources/impl/ai_stylist_remote_datasource_impl.dart';
import 'package:reem/features/ai_stylist/data/repositories/ai_stylist_repository_impl.dart';
import 'package:reem/features/ai_stylist/domain/entities/stylist_conversation.dart';
import 'package:reem/features/ai_stylist/domain/entities/stylist_outfit.dart';
import 'package:reem/features/ai_stylist/domain/repositories/ai_stylist_repository.dart';
import 'package:reem/features/ai_stylist/presentation/providers/stylist_chat_notifier.dart';
import 'package:reem/features/ai_stylist/presentation/providers/stylist_chat_state.dart';

// ── Infrastructure ──────────────────────────────────────────────────────

final aiStylistRemoteDataSourceProvider = Provider<AiStylistRemoteDataSource>(
  (ref) => AiStylistRemoteDataSourceImpl(ref.watch(dioProvider)),
);

final aiStylistRepositoryProvider = Provider<AiStylistRepository>(
  (ref) => AiStylistRepositoryImpl(ref.watch(aiStylistRemoteDataSourceProvider)),
);

// ── The conversation ────────────────────────────────────────────────────

/// One notifier per thread, keyed by conversation id.
///
/// The family key is nullable so a brand-new conversation and a resumed one
/// use the same notifier with the same code path — the null case simply has no
/// row on the server yet, and gets one when she sends her first message.
final stylistChatProvider = StateNotifierProvider.autoDispose
    .family<StylistChatNotifier, StylistChatState, String?>(
  (ref, conversationId) {
    // Kept alive briefly so opening a product from a card and coming back does
    // not throw away the transcript she was reading.
    //
    // The timer is held rather than fired and forgotten: an un-cancellable
    // `Future.delayed` outlives the provider, keeps the test binding's clock
    // pending, and closes a link that may have been resubscribed in the
    // meantime. Cancelling on resume and on dispose is the same idea without
    // either of those.
    final link = ref.keepAlive();
    Timer? release;
    ref.onCancel(() {
      release?.cancel();
      release = Timer(const Duration(minutes: 3), link.close);
    });
    ref.onResume(() => release?.cancel());
    ref.onDispose(() => release?.cancel());

    return StylistChatNotifier(
      ref.watch(aiStylistRepositoryProvider),
      conversationId: conversationId,
    );
  },
);

// ── Everything else ─────────────────────────────────────────────────────

final stylistBootstrapProvider =
    FutureProvider.autoDispose<StylistBootstrap>((ref) async {
  final result = await ref.watch(aiStylistRepositoryProvider).bootstrap();
  return switch (result) {
    Success(:final data) => data,
    Error(:final failure) => throw failure,
  };
});

final stylistConversationsProvider =
    FutureProvider.autoDispose<List<StylistConversation>>((ref) async {
  final result = await ref.watch(aiStylistRepositoryProvider).conversations();
  return switch (result) {
    Success(:final data) => data,
    Error() => const <StylistConversation>[],
  };
});

final stylistPreferencesProvider =
    FutureProvider.autoDispose<StylePreferences>((ref) async {
  final result = await ref.watch(aiStylistRepositoryProvider).preferences();
  return switch (result) {
    Success(:final data) => data,
    Error(:final failure) => throw failure,
  };
});

/// Her saved looks. Family-keyed by status so the wardrobe and the history are
/// separate caches rather than one list being refiltered.
final stylistOutfitsProvider = FutureProvider.autoDispose
    .family<List<StylistOutfit>, StylistOutfitStatus?>((ref, status) async {
  final result =
      await ref.watch(aiStylistRepositoryProvider).outfits(status: status);
  return switch (result) {
    Success(:final data) => data,
    Error() => const <StylistOutfit>[],
  };
});

final stylistOutfitProvider =
    FutureProvider.autoDispose.family<StylistOutfit, String>((ref, id) async {
  final result = await ref.watch(aiStylistRepositoryProvider).outfit(id);
  return switch (result) {
    Success(:final data) => data,
    Error(:final failure) => throw failure,
  };
});

/// Actions that do not belong to a single conversation.
final stylistActionsProvider = Provider<StylistActions>(
  (ref) => StylistActions(ref),
);

class StylistActions {
  const StylistActions(this._ref);

  final Ref _ref;

  AiStylistRepository get _repository => _ref.read(aiStylistRepositoryProvider);

  Future<StylistOutfit?> buildOutfit(OutfitRequest request) async {
    final result = await _repository.buildOutfit(request);
    _ref.invalidate(stylistOutfitsProvider);
    return switch (result) {
      Success(:final data) => data,
      Error() => null,
    };
  }

  Future<bool> setOutfitStatus(String id, StylistOutfitStatus status) async {
    final result = await _repository.setOutfitStatus(id, status);
    _ref.invalidate(stylistOutfitsProvider);
    _ref.invalidate(stylistOutfitProvider(id));
    return result.isSuccess;
  }

  Future<bool> updatePreferences(PreferencesPatch patch) async {
    final result = await _repository.updatePreferences(patch);
    _ref.invalidate(stylistPreferencesProvider);
    _ref.invalidate(stylistBootstrapProvider);
    return result.isSuccess;
  }

  Future<bool> refreshPreferences() async {
    final result = await _repository.refreshPreferences();
    _ref.invalidate(stylistPreferencesProvider);
    return result.isSuccess;
  }

  Future<bool> archiveConversation(String id) async {
    final result = await _repository.archiveConversation(id);
    _ref.invalidate(stylistConversationsProvider);
    _ref.invalidate(stylistBootstrapProvider);
    return result.isSuccess;
  }
}
