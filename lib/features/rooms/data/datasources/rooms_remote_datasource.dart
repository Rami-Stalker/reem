import 'package:reem/core/network/api_endpoints.dart';
import 'package:reem/core/network/base_remote_datasource.dart';
import 'package:reem/features/rooms/data/models/room_models.dart';
import 'package:reem/features/rooms/domain/entities/room.dart';

/// A new room, as she describes it.
class RoomDraft {
  final String title;
  final RoomKind kind;
  final String? note;
  final String? occasion;
  final DateTime? targetDate;
  final num? budgetMinSyp;
  final num? budgetMaxSyp;
  final String? recipientName;
  final String? recipientUserId;
  final bool isSurprise;

  const RoomDraft({
    required this.title,
    this.kind = RoomKind.solo,
    this.note,
    this.occasion,
    this.targetDate,
    this.budgetMinSyp,
    this.budgetMaxSyp,
    this.recipientName,
    this.recipientUserId,
    this.isSurprise = false,
  });

  Map<String, dynamic> toJson() => {
        'title': title,
        'kind': kind.wire,
        if (note != null && note!.isNotEmpty) 'note': note,
        if (occasion != null) 'occasion': occasion,
        if (targetDate != null) 'target_date': targetDate!.toIso8601String(),
        'budget_min_syp': ?budgetMinSyp,
        'budget_max_syp': ?budgetMaxSyp,
        if (recipientName != null && recipientName!.isNotEmpty)
          'recipient_name': recipientName,
        'recipient_user_id': ?recipientUserId,
        if (isSurprise) 'is_surprise': true,
      };
}

abstract interface class RoomsRemoteDataSource {
  Future<List<Room>> rooms({RoomStatus? status, RoomKind? kind});

  Future<Room> room(String id);

  Future<Room> create(RoomDraft draft);

  Future<Room> update(String id, Map<String, dynamic> patch);

  Future<void> remove(String id);

  Future<List<RoomTimelineEvent>> timeline(String id);

  // ── Membership ────────────────────────────────────────────────────────
  Future<List<RoomMember>> members(String id);

  Future<RoomMember> invite(String id, String userId, RoomMemberRole role);

  Future<void> removeMember(String id, String memberId);

  Future<String?> share(String id, RoomMemberRole role);

  Future<void> unshare(String id);

  Future<Room> join(String slug);

  // ── Decisions ─────────────────────────────────────────────────────────
  Future<void> addDecision(
    String id, {
    required String title,
    String? slot,
    int? pickCount,
    bool? isRequired,
  });

  Future<void> removeDecision(String id, String decisionId);

  Future<void> skipDecision(String id, String decisionId, {String? note});

  // ── Candidates ────────────────────────────────────────────────────────
  Future<void> propose(
    String id,
    String decisionId, {
    required String offerId,
    String? offerVariantId,
    int? quantity,
    String? note,
  });

  Future<void> removeCandidate(String id, String candidateId);

  Future<void> choose(String id, String candidateId);

  Future<void> unchoose(String id, String candidateId);

  Future<void> reject(String id, String candidateId, {String? reason});

  Future<void> shortlist(String id, String candidateId);

  Future<void> vote(String id, String candidateId, int value, {String? note});

  /// Put the options side by side. `only` narrows to a shortlist.
  Future<RoomComparison> compare(
    String id,
    String decisionId, {
    List<String>? only,
  });

  // ── Voice ─────────────────────────────────────────────────────────────
  Future<List<RoomComment>> comments(
    String id, {
    String? decisionId,
    String? candidateId,
  });

  Future<void> comment(
    String id, {
    required String body,
    String? decisionId,
    String? candidateId,
  });

  // ── Plan ──────────────────────────────────────────────────────────────
  Future<PurchasePlan?> plan(String id);

  Future<PurchasePlan> drawPlan(String id);

  Future<PurchasePlan> setStage(
    String id,
    String planId,
    String itemId,
    PurchaseStage stage,
  );

  Future<PurchasePlan> removePlanItem(String id, String planId, String itemId);

  Future<Map<String, dynamic>> checkoutPlan(
    String id,
    String planId,
    Map<String, dynamic> order,
  );
}

final class RoomsRemoteDataSourceImpl extends BaseRemoteDataSource
    implements RoomsRemoteDataSource {
  const RoomsRemoteDataSourceImpl(super.dio);

  @override
  Future<List<Room>> rooms({RoomStatus? status, RoomKind? kind}) async =>
      roomsFromJson(
        await getList(
          ApiEndpoints.rooms,
          query: {'status': ?status?.wire, 'kind': ?kind?.wire},
        ),
      );

  @override
  Future<Room> room(String id) async =>
      roomFromJson(await getJson(ApiEndpoints.room(id)));

  @override
  Future<Room> create(RoomDraft draft) async =>
      roomFromJson(await postJson(ApiEndpoints.rooms, body: draft.toJson()));

  @override
  Future<Room> update(String id, Map<String, dynamic> patch) async =>
      roomFromJson(await patchJson(ApiEndpoints.room(id), body: patch));

  @override
  Future<void> remove(String id) => deleteRequest(ApiEndpoints.room(id));

  @override
  Future<List<RoomTimelineEvent>> timeline(String id) async =>
      timelineFromJson(await getList(ApiEndpoints.roomTimeline(id)));

  // ── Membership ────────────────────────────────────────────────────────

  @override
  Future<List<RoomMember>> members(String id) async {
    final list = await getList(ApiEndpoints.roomMembers(id));
    return list
        .whereType<Map>()
        .map((e) => memberFromJson(Map<String, dynamic>.from(e)))
        .toList(growable: false);
  }

  @override
  Future<RoomMember> invite(
    String id,
    String userId,
    RoomMemberRole role,
  ) async =>
      memberFromJson(
        await postJson(
          ApiEndpoints.roomMembers(id),
          body: {'user_id': userId, 'role': role.wire},
        ),
      );

  @override
  Future<void> removeMember(String id, String memberId) =>
      deleteRequest(ApiEndpoints.roomMember(id, memberId));

  @override
  Future<String?> share(String id, RoomMemberRole role) async {
    final json = await postJson(
      ApiEndpoints.roomShare(id),
      body: {'role': role.wire},
    );
    return json['share_slug'] as String?;
  }

  @override
  Future<void> unshare(String id) => deleteRequest(ApiEndpoints.roomShare(id));

  @override
  Future<Room> join(String slug) async =>
      roomFromJson(await postJson(ApiEndpoints.roomJoin(slug)));

  // ── Decisions ─────────────────────────────────────────────────────────

  @override
  Future<void> addDecision(
    String id, {
    required String title,
    String? slot,
    int? pickCount,
    bool? isRequired,
  }) async {
    await postJson(
      ApiEndpoints.roomDecisions(id),
      body: {
        'title': title,
        'slot': ?slot,
        'pick_count': ?pickCount,
        'is_required': ?isRequired,
      },
    );
  }

  @override
  Future<void> removeDecision(String id, String decisionId) =>
      deleteRequest(ApiEndpoints.roomDecision(id, decisionId));

  @override
  Future<void> skipDecision(String id, String decisionId, {String? note}) async {
    await postJson(
      ApiEndpoints.roomDecisionSkip(id, decisionId),
      body: {'note': ?note},
    );
  }

  // ── Candidates ────────────────────────────────────────────────────────

  @override
  Future<void> propose(
    String id,
    String decisionId, {
    required String offerId,
    String? offerVariantId,
    int? quantity,
    String? note,
  }) async {
    await postJson(
      ApiEndpoints.roomCandidates(id, decisionId),
      body: {
        'offer_id': offerId,
        'offer_variant_id': ?offerVariantId,
        'quantity': ?quantity,
        'note': ?note,
      },
    );
  }

  @override
  Future<void> removeCandidate(String id, String candidateId) =>
      deleteRequest(ApiEndpoints.roomCandidate(id, candidateId));

  @override
  Future<void> choose(String id, String candidateId) async {
    await postJson(ApiEndpoints.roomCandidateChoose(id, candidateId));
  }

  @override
  Future<void> unchoose(String id, String candidateId) async {
    await postJson(ApiEndpoints.roomCandidateUnchoose(id, candidateId));
  }

  @override
  Future<void> reject(String id, String candidateId, {String? reason}) async {
    await postJson(
      ApiEndpoints.roomCandidateReject(id, candidateId),
      body: {'reason': ?reason},
    );
  }

  @override
  Future<void> shortlist(String id, String candidateId) async {
    await postJson(ApiEndpoints.roomCandidateShortlist(id, candidateId));
  }

  @override
  Future<void> vote(
    String id,
    String candidateId,
    int value, {
    String? note,
  }) async {
    await postJson(
      ApiEndpoints.roomCandidateVote(id, candidateId),
      body: {'value': value, 'note': ?note},
    );
  }

  @override
  Future<RoomComparison> compare(
    String id,
    String decisionId, {
    List<String>? only,
  }) async =>
      comparisonFromJson(
        await getJson(
          ApiEndpoints.roomCompare(id, decisionId),
          query: {if (only != null && only.isNotEmpty) 'candidate_ids': only},
        ),
      );

  // ── Voice ─────────────────────────────────────────────────────────────

  @override
  Future<List<RoomComment>> comments(
    String id, {
    String? decisionId,
    String? candidateId,
  }) async =>
      commentsFromJson(
        await getList(
          ApiEndpoints.roomComments(id),
          query: {'decision_id': ?decisionId, 'candidate_id': ?candidateId},
        ),
      );

  @override
  Future<void> comment(
    String id, {
    required String body,
    String? decisionId,
    String? candidateId,
  }) async {
    await postJson(
      ApiEndpoints.roomComments(id),
      body: {
        'body': body,
        'decision_id': ?decisionId,
        'candidate_id': ?candidateId,
      },
    );
  }

  // ── Plan ──────────────────────────────────────────────────────────────

  @override
  Future<PurchasePlan?> plan(String id) async =>
      planFromJson(await getJson(ApiEndpoints.roomPlan(id)));

  @override
  Future<PurchasePlan> drawPlan(String id) async {
    final json = await postJson(ApiEndpoints.roomPlan(id));
    final plan = planFromJson(json);
    if (plan == null) throw StateError('The plan came back empty');
    return plan;
  }

  @override
  Future<PurchasePlan> setStage(
    String id,
    String planId,
    String itemId,
    PurchaseStage stage,
  ) async {
    final json = await patchJson(
      ApiEndpoints.roomPlanItemStage(id, planId, itemId),
      body: {'stage': stage.wire},
    );
    return planFromJson(json)!;
  }

  @override
  Future<PurchasePlan> removePlanItem(
    String id,
    String planId,
    String itemId,
  ) async {
    final json = await deleteJson(ApiEndpoints.roomPlanItem(id, planId, itemId));
    return planFromJson(json)!;
  }

  @override
  Future<Map<String, dynamic>> checkoutPlan(
    String id,
    String planId,
    Map<String, dynamic> order,
  ) =>
      postJson(ApiEndpoints.roomPlanCheckout(id, planId), body: order);
}
