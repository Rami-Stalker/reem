import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ohara/core/presentation/providers/core_providers.dart';
import 'package:ohara/core/result/result.dart';
import 'package:ohara/features/closet/data/datasources/closet_remote_datasource.dart';
import 'package:ohara/features/closet/data/datasources/impl/closet_remote_datasource_impl.dart';
import 'package:ohara/features/closet/data/repositories/closet_repository_impl.dart';
import 'package:ohara/features/closet/domain/entities/closet_gap.dart';
import 'package:ohara/features/closet/domain/entities/closet_item.dart';
import 'package:ohara/features/closet/domain/entities/closet_look.dart';
import 'package:ohara/features/closet/domain/entities/closet_overview.dart';
import 'package:ohara/features/closet/domain/repositories/closet_repository.dart';

// ── Infrastructure ──────────────────────────────────────────────────────

final closetRemoteDataSourceProvider = Provider<ClosetRemoteDataSource>(
  (ref) => ClosetRemoteDataSourceImpl(ref.watch(dioProvider)),
);

final closetRepositoryProvider = Provider<ClosetRepository>(
  (ref) => ClosetRepositoryImpl(ref.watch(closetRemoteDataSourceProvider)),
);

// ── Reads ───────────────────────────────────────────────────────────────

/// The closet's front page.
///
/// Everything that writes to the closet invalidates this, because almost every
/// write moves a number on it — the outfit count, the gap list, the slot
/// breakdown. Refetching one screen after a write is cheaper than maintaining a
/// second copy of the arithmetic on the client, and it cannot disagree with the
/// server about what her wardrobe contains.
final closetOverviewProvider = FutureProvider.autoDispose<ClosetOverview>((ref) async {
  final result = await ref.watch(closetRepositoryProvider).overview();
  return switch (result) {
    Success(:final data) => data,
    Error(:final failure) => throw failure,
  };
});

final closetItemsProvider = FutureProvider.autoDispose
    .family<ClosetItemPage, ClosetItemQuery>((ref, query) async {
  final result = await ref.watch(closetRepositoryProvider).items(query);
  return switch (result) {
    Success(:final data) => data,
    Error(:final failure) => throw failure,
  };
});

final closetItemProvider =
    FutureProvider.autoDispose.family<ClosetItem, String>((ref, id) async {
  final result = await ref.watch(closetRepositoryProvider).item(id);
  return switch (result) {
    Success(:final data) => data,
    Error(:final failure) => throw failure,
  };
});

final closetLooksProvider =
    FutureProvider.autoDispose.family<List<ClosetLook>, String?>((ref, occasion) async {
  final result = await ref.watch(closetRepositoryProvider).looks(occasion: occasion);
  return switch (result) {
    Success(:final data) => data,
    Error(:final failure) => throw failure,
  };
});

final closetLookProvider =
    FutureProvider.autoDispose.family<ClosetLook, String>((ref, id) async {
  final result = await ref.watch(closetRepositoryProvider).look(id);
  return switch (result) {
    Success(:final data) => data,
    Error(:final failure) => throw failure,
  };
});

final closetGapsProvider = FutureProvider.autoDispose<List<ClosetGap>>((ref) async {
  final result = await ref.watch(closetRepositoryProvider).gaps();
  return switch (result) {
    Success(:final data) => data,
    // An empty gap list is a valid, common state — a closet with nothing
    // missing — so a failure here degrades to "no advice" rather than to an
    // error screen over the wardrobe she came to look at.
    Error() => const <ClosetGap>[],
  };
});

final gapSuggestionsProvider =
    FutureProvider.autoDispose.family<GapSuggestions, String>((ref, gapId) async {
  final result = await ref.watch(closetRepositoryProvider).gapSuggestions(gapId);
  return switch (result) {
    Success(:final data) => data,
    Error(:final failure) => throw failure,
  };
});

/// "شو بقدر ألبس اليوم؟", optionally narrowed to an occasion.
final todayOutfitsProvider =
    FutureProvider.autoDispose.family<TodayOutfits, String?>((ref, occasion) async {
  final result = await ref.watch(closetRepositoryProvider).today(occasion: occasion);
  return switch (result) {
    Success(:final data) => data,
    Error(:final failure) => throw failure,
  };
});

/// "هل بتناسب خزانتي؟", for a product page.
///
/// Degrades to null rather than throwing: this is a panel on someone else's
/// screen, and a closet that cannot be reached must not take the product page
/// down with it.
final closetPairingProvider =
    FutureProvider.autoDispose.family<ClosetPairing?, String>((ref, productId) async {
  final result = await ref.watch(closetRepositoryProvider).pairing(productId);
  return switch (result) {
    Success(:final data) => data,
    Error() => null,
  };
});

// ── Writes ──────────────────────────────────────────────────────────────

/// Every mutation, in one place.
///
/// Each method invalidates what its write actually moved. The rule followed
/// throughout: anything that changes what she *owns* invalidates the overview
/// and the gaps, because both are computed from her pieces; anything that only
/// changes a wear invalidates the item and today, because rotation moves the
/// daily suggestion and nothing else.
class ClosetActions {
  ClosetActions(this._ref);

  final Ref _ref;

  ClosetRepository get _repository => _ref.read(closetRepositoryProvider);

  void _invalidateWardrobe() {
    _ref.invalidate(closetOverviewProvider);
    _ref.invalidate(closetGapsProvider);
    _ref.invalidate(closetItemsProvider);
    _ref.invalidate(todayOutfitsProvider);
  }

  Future<Result<ClosetItem>> addFromCatalog({
    required String productId,
    String? offerId,
    String? variantId,
  }) async {
    final result = await _repository.addFromCatalog(
      productId: productId,
      offerId: offerId,
      variantId: variantId,
    );
    if (result is Success<ClosetItem>) {
      _invalidateWardrobe();
      _ref.invalidate(closetPairingProvider(productId));
    }
    return result;
  }

  Future<Result<ClosetItem>> addPersonal(PersonalItemDraft draft) async {
    final result = await _repository.addPersonal(draft);
    if (result is Success<ClosetItem>) _invalidateWardrobe();
    return result;
  }

  Future<Result<ClosetItem>> updateItem(String id, ClosetItemPatch patch) async {
    final result = await _repository.updateItem(id, patch);
    if (result is Success<ClosetItem>) {
      _ref.invalidate(closetItemProvider(id));
      // A descriptor edit changes what the closet is short of; a favourite
      // toggle does not, but distinguishing them here would duplicate a rule
      // the server already applies.
      _invalidateWardrobe();
    }
    return result;
  }

  Future<Result<ClosetItem>> setStatus(String id, ClosetItemStatus status) async {
    final result = await _repository.setItemStatus(id, status);
    if (result is Success<ClosetItem>) {
      _ref.invalidate(closetItemProvider(id));
      _invalidateWardrobe();
    }
    return result;
  }

  Future<Result<void>> removeItem(String id) async {
    final result = await _repository.removeItem(id);
    if (result is Success) _invalidateWardrobe();
    return result;
  }

  Future<Result<ClosetItem>> logWear(String id, {DateTime? wornOn}) async {
    final result = await _repository.logWear(id, wornOn: wornOn);
    if (result is Success<ClosetItem>) {
      _ref.invalidate(closetItemProvider(id));
      _ref.invalidate(closetOverviewProvider);
      // Rotation is the whole input to the daily pick, so a wear changes
      // tomorrow's answer.
      _ref.invalidate(todayOutfitsProvider);
    }
    return result;
  }

  Future<Result<ClosetLook>> createLook(LookDraft draft) async {
    final result = await _repository.createLook(draft);
    if (result is Success<ClosetLook>) {
      _ref.invalidate(closetLooksProvider);
      _invalidateWardrobe();
    }
    return result;
  }

  Future<Result<ClosetLook>> updateLook(String id, LookPatch patch) async {
    final result = await _repository.updateLook(id, patch);
    if (result is Success<ClosetLook>) {
      _ref.invalidate(closetLookProvider(id));
      _ref.invalidate(closetLooksProvider);
      _invalidateWardrobe();
    }
    return result;
  }

  Future<Result<ClosetLook>> setLookItems(
    String id,
    List<LookSlotDraft> items,
  ) async {
    final result = await _repository.setLookItems(id, items);
    if (result is Success<ClosetLook>) {
      _ref.invalidate(closetLookProvider(id));
      _ref.invalidate(closetLooksProvider);
      _invalidateWardrobe();
    }
    return result;
  }

  Future<Result<void>> removeLook(String id) async {
    final result = await _repository.removeLook(id);
    if (result is Success) {
      _ref.invalidate(closetLooksProvider);
      _invalidateWardrobe();
    }
    return result;
  }

  Future<Result<ClosetLook>> logLookWear(
    String id, {
    DateTime? wornOn,
    String? occasionNote,
  }) async {
    final result = await _repository.logLookWear(
      id,
      wornOn: wornOn,
      occasionNote: occasionNote,
    );
    if (result is Success<ClosetLook>) {
      _ref.invalidate(closetLookProvider(id));
      _ref.invalidate(closetLooksProvider);
      _ref.invalidate(closetOverviewProvider);
      _ref.invalidate(todayOutfitsProvider);
    }
    return result;
  }

  Future<Result<ClosetLook>> promoteStylistOutfit(String outfitId) async {
    final result = await _repository.promoteStylistOutfit(outfitId);
    if (result is Success<ClosetLook>) {
      _ref.invalidate(closetLooksProvider);
      _invalidateWardrobe();
    }
    return result;
  }

  Future<Result<ClosetGap>> dismissGap(String gapId) async {
    final result = await _repository.dismissGap(gapId);
    if (result is Success<ClosetGap>) {
      _ref.invalidate(closetGapsProvider);
      _ref.invalidate(closetOverviewProvider);
    }
    return result;
  }

  Future<Result<List<ClosetGap>>> refreshGaps() async {
    final result = await _repository.refreshGaps();
    if (result is Success<List<ClosetGap>>) {
      _ref.invalidate(closetGapsProvider);
      _ref.invalidate(closetOverviewProvider);
    }
    return result;
  }

  Future<Result<ClosetSettings>> updateSettings({
    bool? autoAddPurchases,
    bool? suggestionsEnabled,
  }) async {
    final result = await _repository.updateSettings(
      autoAddPurchases: autoAddPurchases,
      suggestionsEnabled: suggestionsEnabled,
    );
    if (result is Success<ClosetSettings>) _invalidateWardrobe();
    return result;
  }

  /// Pull her delivered orders in. The single most effective thing an empty
  /// closet can offer, so it is one button rather than a settings toggle.
  Future<Result<int>> backfill() async {
    final result = await _repository.backfill();
    if (result is Success<int>) _invalidateWardrobe();
    return result;
  }
}

final closetActionsProvider = Provider<ClosetActions>(ClosetActions.new);
