import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ohara/core/presentation/providers/core_providers.dart';
import 'package:ohara/features/rooms/data/datasources/rooms_remote_datasource.dart';
import 'package:ohara/features/rooms/domain/entities/room.dart';

final roomsDataSourceProvider = Provider<RoomsRemoteDataSource>(
  (ref) => RoomsRemoteDataSourceImpl(ref.watch(dioProvider)),
);

// ── Reads ───────────────────────────────────────────────────────────────

/// Her rooms, newest activity first.
final roomsProvider = FutureProvider.autoDispose<List<Room>>((ref) async {
  return ref.watch(roomsDataSourceProvider).rooms();
});

/// One room, whole: decisions, candidates, members, and the live plan.
///
/// The plan travels with the room deliberately — the "ready to buy" badge and
/// the decisions behind it are read from one payload, so they can never
/// disagree on screen.
final roomProvider =
    FutureProvider.autoDispose.family<Room, String>((ref, roomId) async {
  return ref.watch(roomsDataSourceProvider).room(roomId);
});

/// Comments on one candidate or one decision.
final roomCommentsProvider = FutureProvider.autoDispose
    .family<List<RoomComment>, ({String roomId, String? candidateId, String? decisionId})>(
        (ref, key) async {
  return ref.watch(roomsDataSourceProvider).comments(
        key.roomId,
        candidateId: key.candidateId,
        decisionId: key.decisionId,
      );
});

/// The side-by-side comparison for one decision.
final roomComparisonProvider = FutureProvider.autoDispose
    .family<RoomComparison, ({String roomId, String decisionId})>((ref, key) async {
  return ref
      .watch(roomsDataSourceProvider)
      .compare(key.roomId, key.decisionId);
});

final roomTimelineProvider = FutureProvider.autoDispose
    .family<List<RoomTimelineEvent>, String>((ref, roomId) async {
  return ref.watch(roomsDataSourceProvider).timeline(roomId);
});

// ── Writes ──────────────────────────────────────────────────────────────

/// Every mutation, in one place.
///
/// Almost all of them invalidate the whole room rather than patching state
/// locally, and that is the right trade here: a room is the first surface in
/// this app that several people write to at once, so the server's version is the
/// only one worth trusting. Optimistic local edits would show her sister's vote
/// and her own disagreeing for a second, which is exactly the moment the feature
/// has to feel solid.
class RoomActions {
  RoomActions(this._ref);

  final Ref _ref;

  RoomsRemoteDataSource get _api => _ref.read(roomsDataSourceProvider);

  void _refresh(String roomId) {
    _ref.invalidate(roomProvider(roomId));
    _ref.invalidate(roomsProvider);
  }

  Future<Room> create(RoomDraft draft) async {
    final room = await _api.create(draft);
    _ref.invalidate(roomsProvider);
    return room;
  }

  Future<void> update(String roomId, Map<String, dynamic> patch) async {
    await _api.update(roomId, patch);
    _refresh(roomId);
  }

  Future<void> remove(String roomId) async {
    await _api.remove(roomId);
    _ref.invalidate(roomsProvider);
  }

  // ── Decisions ─────────────────────────────────────────────────────────

  Future<void> addDecision(
    String roomId, {
    required String title,
    String? slot,
    int? pickCount,
    bool? isRequired,
  }) async {
    await _api.addDecision(
      roomId,
      title: title,
      slot: slot,
      pickCount: pickCount,
      isRequired: isRequired,
    );
    _refresh(roomId);
  }

  Future<void> removeDecision(String roomId, String decisionId) async {
    await _api.removeDecision(roomId, decisionId);
    _refresh(roomId);
  }

  /// Decide to buy nothing for this. A real outcome, not a deletion.
  Future<void> skipDecision(
    String roomId,
    String decisionId, {
    String? note,
  }) async {
    await _api.skipDecision(roomId, decisionId, note: note);
    _refresh(roomId);
  }

  // ── Candidates ────────────────────────────────────────────────────────

  /// Put a piece forward. Never buys anything.
  Future<void> propose(
    String roomId,
    String decisionId, {
    required String offerId,
    String? offerVariantId,
    String? note,
  }) async {
    await _api.propose(
      roomId,
      decisionId,
      offerId: offerId,
      offerVariantId: offerVariantId,
      note: note,
    );
    _refresh(roomId);
  }

  Future<void> removeCandidate(String roomId, String candidateId) async {
    await _api.removeCandidate(roomId, candidateId);
    _refresh(roomId);
  }

  /// This one. The moment an intention becomes a purchase.
  Future<void> choose(String roomId, String candidateId) async {
    await _api.choose(roomId, candidateId);
    _refresh(roomId);
  }

  Future<void> unchoose(String roomId, String candidateId) async {
    await _api.unchoose(roomId, candidateId);
    _refresh(roomId);
  }

  Future<void> reject(
    String roomId,
    String candidateId, {
    String? reason,
  }) async {
    await _api.reject(roomId, candidateId, reason: reason);
    _refresh(roomId);
  }

  Future<void> vote(String roomId, String candidateId, int value) async {
    await _api.vote(roomId, candidateId, value);
    _refresh(roomId);
  }

  Future<void> comment(
    String roomId, {
    required String body,
    String? decisionId,
    String? candidateId,
  }) async {
    await _api.comment(
      roomId,
      body: body,
      decisionId: decisionId,
      candidateId: candidateId,
    );
    _ref.invalidate(
      roomCommentsProvider((
        roomId: roomId,
        candidateId: candidateId,
        decisionId: decisionId,
      )),
    );
    _ref.invalidate(roomTimelineProvider(roomId));
  }

  // ── Sharing ───────────────────────────────────────────────────────────

  Future<String?> share(
    String roomId, [
    RoomMemberRole role = RoomMemberRole.advisor,
  ]) async {
    final slug = await _api.share(roomId, role);
    _refresh(roomId);
    return slug;
  }

  Future<void> unshare(String roomId) async {
    await _api.unshare(roomId);
    _refresh(roomId);
  }

  Future<Room> join(String slug) async {
    final room = await _api.join(slug);
    _ref.invalidate(roomsProvider);
    return room;
  }

  // ── Plan ──────────────────────────────────────────────────────────────

  /// Draw the plan. Throws when decisions are still open — the server names
  /// which, and the screen shows them.
  Future<PurchasePlan> drawPlan(String roomId) async {
    final plan = await _api.drawPlan(roomId);
    _refresh(roomId);
    return plan;
  }

  Future<void> setStage(
    String roomId,
    String planId,
    String itemId,
    PurchaseStage stage,
  ) async {
    await _api.setStage(roomId, planId, itemId, stage);
    _refresh(roomId);
  }

  Future<void> removePlanItem(
    String roomId,
    String planId,
    String itemId,
  ) async {
    await _api.removePlanItem(roomId, planId, itemId);
    _refresh(roomId);
  }

  Future<Map<String, dynamic>> checkout(
    String roomId,
    String planId,
    Map<String, dynamic> order,
  ) async {
    final result = await _api.checkoutPlan(roomId, planId, order);
    _refresh(roomId);
    return result;
  }
}

final roomActionsProvider = Provider<RoomActions>(RoomActions.new);
