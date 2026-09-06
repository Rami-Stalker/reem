import 'package:reem/core/shared/value_objects/money.dart';
import 'package:reem/features/rooms/domain/entities/room.dart';

/// Wire decoding for Reem Rooms.
///
/// Free functions rather than model subclasses, matching the rest of the app.
/// Every decoder is total — a missing field yields the empty value rather than
/// throwing — because a room is read by several people at once and a malformed
/// candidate should cost one card, not the argument.

Map<String, dynamic> _map(Object? value) =>
    value is Map ? Map<String, dynamic>.from(value) : const {};

List<Map<String, dynamic>> _maps(Object? value) => value is List
    ? value.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList()
    : const [];

List<String> _strings(Object? value) => value is List
    ? value.map((e) => e?.toString() ?? '').where((e) => e.isNotEmpty).toList()
    : const [];

int _int(Object? value) => switch (value) {
      final num n => n.toInt(),
      final String s => int.tryParse(s) ?? 0,
      _ => 0,
    };

double _double(Object? value) => switch (value) {
      final num n => n.toDouble(),
      final String s => double.tryParse(s) ?? 0,
      _ => 0,
    };

DateTime? _date(Object? value) =>
    value is String ? DateTime.tryParse(value) : null;

// ── Pieces ──────────────────────────────────────────────────────────────

RoomMember memberFromJson(Map<String, dynamic> json) => RoomMember(
      id: json['id']?.toString() ?? '',
      userId: json['user_id']?.toString() ?? '',
      name: json['name'] as String?,
      role: RoomMemberRole.fromWire(json['role'] as String?),
      roleLabel: json['role_label']?.toString() ?? '',
    );

Consensus consensusFromJson(Map<String, dynamic> json) => Consensus(
      leaderId: json['leader_id'] as String?,
      runnerUpId: json['runner_up_id'] as String?,
      margin: _int(json['margin']),
      voters: _int(json['voters']),
      contested: json['contested'] == true,
      // Absent means nobody has voted, which is the safe reading: it renders as
      // "no opinions yet" rather than as a winner.
      silent: json['silent'] != false,
    );

RoomCandidate candidateFromJson(Map<String, dynamic> json) {
  final seller = _map(json['seller']);
  return RoomCandidate(
    id: json['id']?.toString() ?? '',
    status: CandidateStatus.fromWire(json['status'] as String?),
    statusLabel: json['status_label']?.toString() ?? '',
    position: _int(json['position']),
    quantity: _int(json['quantity']),
    offerId: json['offer_id']?.toString() ?? '',
    offerVariantId: json['offer_variant_id'] as String?,
    productId: json['product_id']?.toString() ?? '',
    title: json['title']?.toString() ?? '',
    image: json['image'] as String?,
    variant: json['variant'] as String?,
    sellerId: seller['id']?.toString() ?? '',
    sellerName: seller['name']?.toString() ?? '',
    price: Money.tryFromJson(json['price']),
    available: json['available'] != false,
    votesUp: _int(json['votes_up']),
    votesDown: _int(json['votes_down']),
    voteScore: _int(json['vote_score']),
    addedById: json['added_by_id'] as String?,
    note: json['note'] as String?,
    rejectionNote: json['rejection_note'] as String?,
  );
}

RoomDecision decisionFromJson(Map<String, dynamic> json) => RoomDecision(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      note: json['note'] as String?,
      slot: json['slot'] as String?,
      slotLabel: json['slot_label'] as String?,
      status: DecisionStatus.fromWire(json['status'] as String?),
      pickCount: _int(json['pick_count']),
      position: _int(json['position']),
      isRequired: json['is_required'] != false,
      isSuggested: json['is_suggested'] == true,
      remaining: _int(json['remaining']),
      settled: json['settled'] == true,
      blockers: _strings(json['blockers']),
      consensus: consensusFromJson(_map(json['consensus'])),
      candidates:
          _maps(json['candidates']).map(candidateFromJson).toList(growable: false),
    );

RoomBlocker blockerFromJson(Map<String, dynamic> json) => RoomBlocker(
      code: json['code']?.toString() ?? '',
      decisionId: json['decision_id'] as String?,
      decisionTitle: json['decision_title'] as String?,
    );

RoomReadiness? readinessFromJson(Object? value) {
  if (value is! Map) return null;
  final json = Map<String, dynamic>.from(value);
  return RoomReadiness(
    ready: json['ready'] == true,
    progress: _double(json['progress']),
    settledRequired: _int(json['settled_required']),
    totalRequired: _int(json['total_required']),
    blockers: _maps(json['blockers']).map(blockerFromJson).toList(growable: false),
  );
}

// ── Plan ────────────────────────────────────────────────────────────────

PlanItem planItemFromJson(Map<String, dynamic> json) {
  final decision = _map(json['decision']);
  final seller = _map(json['seller']);
  return PlanItem(
    id: json['id']?.toString() ?? '',
    stage: PurchaseStage.fromWire(json['stage'] as String?),
    quantity: _int(json['quantity']),
    decisionId: decision['id'] as String?,
    decisionTitle: decision['title'] as String?,
    offerId: json['offer_id']?.toString() ?? '',
    offerVariantId: json['offer_variant_id'] as String?,
    title: json['title']?.toString() ?? '',
    image: json['image'] as String?,
    variant: json['variant'] as String?,
    sellerName: seller['name']?.toString() ?? '',
    unitPrice: Money.tryFromJson(json['unit_price']),
    lineTotal: Money.tryFromJson(json['line_total']),
  );
}

PlanBudget budgetFromJson(Map<String, dynamic> json) => PlanBudget(
      verdict: json['verdict']?.toString() ?? 'unknown',
      min: Money.tryFromJson(json['min']),
      max: Money.tryFromJson(json['max']),
      overBy: Money.tryFromJson(json['over_by']),
      unpricedCount: _int(json['unpriced_count']),
    );

PurchasePlan? planFromJson(Object? value) {
  if (value is! Map) return null;
  final json = Map<String, dynamic>.from(value);
  if (json['id'] == null) return null;

  return PurchasePlan(
    id: json['id'].toString(),
    roomId: json['room_id']?.toString() ?? '',
    status: json['status']?.toString() ?? 'DRAFT',
    version: _int(json['version']),
    orderId: json['order_id'] as String?,
    now: _maps(json['now']).map(planItemFromJson).toList(growable: false),
    later: _maps(json['later']).map(planItemFromJson).toList(growable: false),
    total: Money.tryFromJson(json['total']),
    budget: budgetFromJson(_map(json['budget'])),
    unavailableItemIds: _strings(json['unavailable_item_ids']),
  );
}

// ── Rooms ───────────────────────────────────────────────────────────────

Room roomFromJson(Map<String, dynamic> json) => Room(
      id: json['id']?.toString() ?? '',
      kind: RoomKind.fromWire(json['kind'] as String?),
      status: RoomStatus.fromWire(json['status'] as String?),
      title: json['title']?.toString() ?? '',
      note: json['note'] as String?,
      occasion: json['occasion'] as String?,
      occasionLabel: json['occasion_label'] as String?,
      targetDate: _date(json['target_date']),
      coverUrl: json['cover_url'] as String?,
      budgetMin: Money.tryFromJson(json['budget_min']),
      budgetMax: Money.tryFromJson(json['budget_max']),
      recipientName: json['recipient_name'] as String?,
      isSurprise: json['is_surprise'] == true,
      shareSlug: json['share_slug'] as String?,
      shareRole: RoomMemberRole.fromWire(json['share_role'] as String?),
      decisionsCount: _int(json['decisions_count']),
      candidatesCount: _int(json['candidates_count']),
      membersCount: _int(json['members_count']),
      lastActivityAt: _date(json['last_activity_at']),
      readiness: readinessFromJson(json['readiness']),
      members: _maps(json['members']).map(memberFromJson).toList(growable: false),
      decisions:
          _maps(json['decisions']).map(decisionFromJson).toList(growable: false),
      plan: planFromJson(json['plan']),
    );

List<Room> roomsFromJson(Object? value) =>
    _maps(value).map(roomFromJson).toList(growable: false);

RoomComment commentFromJson(Map<String, dynamic> json) {
  final member = _map(json['member']);
  return RoomComment(
    id: json['id']?.toString() ?? '',
    body: json['body']?.toString() ?? '',
    decisionId: json['decision_id'] as String?,
    candidateId: json['candidate_id'] as String?,
    memberId: member['id']?.toString() ?? '',
    memberName: member['name']?.toString() ?? '',
    memberImage: member['image'] as String?,
    memberRole: RoomMemberRole.fromWire(member['role'] as String?),
    memberRoleLabel: member['role_label']?.toString() ?? '',
    createdAt: _date(json['created_at']) ?? DateTime.now(),
  );
}

List<RoomComment> commentsFromJson(Object? value) =>
    _maps(value).map(commentFromJson).toList(growable: false);

RoomTimelineEvent eventFromJson(Map<String, dynamic> json) {
  final actor = _map(json['actor']);
  return RoomTimelineEvent(
    id: json['id']?.toString() ?? '',
    kind: json['kind']?.toString() ?? '',
    label: json['label']?.toString() ?? '',
    actorName: actor['name'] as String?,
    actorImage: actor['image'] as String?,
    createdAt: _date(json['created_at']) ?? DateTime.now(),
  );
}

List<RoomTimelineEvent> timelineFromJson(Object? value) =>
    _maps(value).map(eventFromJson).toList(growable: false);

// ── Comparison ──────────────────────────────────────────────────────────

CompareRow compareRowFromJson(Map<String, dynamic> json) => CompareRow(
      key: json['key']?.toString() ?? '',
      label: json['label']?.toString() ?? '',
      direction: json['direction']?.toString() ?? 'none',
      differs: json['differs'] == true,
      values: {
        for (final entry in _map(json['values']).entries)
          entry.key: CompareCell(
            display: _map(entry.value)['display']?.toString() ?? '—',
            best: _map(entry.value)['best'] == true,
          ),
      },
    );

RoomComparison comparisonFromJson(Map<String, dynamic> json) {
  final verdict = _map(json['verdict']);
  return RoomComparison(
    decisionId: json['decision_id']?.toString() ?? '',
    decisionTitle: json['decision_title']?.toString() ?? '',
    candidateIds: _strings(json['candidate_ids']),
    rows: _maps(json['rows']).map(compareRowFromJson).toList(growable: false),
    consensus: consensusFromJson(_map(json['consensus'])),
    verdict: CompareVerdict(
      code: verdict['code']?.toString() ?? 'TRADE_OFF',
      label: verdict['label']?.toString() ?? '',
      candidateId: verdict['candidate_id'] as String?,
    ),
    commentCounts: {
      for (final entry in _map(json['comment_counts']).entries)
        entry.key: _int(entry.value),
    },
  );
}
