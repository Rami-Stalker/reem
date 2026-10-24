import 'package:equatable/equatable.dart';
import 'package:ohara/core/shared/value_objects/money.dart';

/// What a room is for.
enum RoomKind {
  solo,
  group,
  gift,
  occasion;

  static RoomKind fromWire(String? value) => switch (value) {
        'GROUP' => RoomKind.group,
        'GIFT' => RoomKind.gift,
        'OCCASION' => RoomKind.occasion,
        _ => RoomKind.solo,
      };

  String get wire => switch (this) {
        RoomKind.solo => 'SOLO',
        RoomKind.group => 'GROUP',
        RoomKind.gift => 'GIFT',
        RoomKind.occasion => 'OCCASION',
      };
}

enum RoomStatus {
  planning,
  deciding,
  ready,
  purchased,
  archived;

  static RoomStatus fromWire(String? value) => switch (value) {
        'DECIDING' => RoomStatus.deciding,
        'READY' => RoomStatus.ready,
        'PURCHASED' => RoomStatus.purchased,
        'ARCHIVED' => RoomStatus.archived,
        _ => RoomStatus.planning,
      };

  String get wire => switch (this) {
        RoomStatus.planning => 'PLANNING',
        RoomStatus.deciding => 'DECIDING',
        RoomStatus.ready => 'READY',
        RoomStatus.purchased => 'PURCHASED',
        RoomStatus.archived => 'ARCHIVED',
      };
}

/// Who somebody is inside a room.
///
/// The split that matters is [advisor] against [coShopper]: an opinion and a
/// wallet are different things, and the UI hides the deciding controls from
/// anyone who does not hold the second.
enum RoomMemberRole {
  owner,
  coShopper,
  advisor,
  viewer;

  static RoomMemberRole fromWire(String? value) => switch (value) {
        'OWNER' => RoomMemberRole.owner,
        'CO_SHOPPER' => RoomMemberRole.coShopper,
        'VIEWER' => RoomMemberRole.viewer,
        _ => RoomMemberRole.advisor,
      };

  String get wire => switch (this) {
        RoomMemberRole.owner => 'OWNER',
        RoomMemberRole.coShopper => 'CO_SHOPPER',
        RoomMemberRole.advisor => 'ADVISOR',
        RoomMemberRole.viewer => 'VIEWER',
      };

  /// May resolve decisions and edit the plan.
  bool get canDecide =>
      this == RoomMemberRole.owner || this == RoomMemberRole.coShopper;

  /// May put a piece forward. An advisor can — that is most of what asking a
  /// friend is for.
  bool get canPropose => this != RoomMemberRole.viewer;

  bool get canVote => this != RoomMemberRole.viewer;

  bool get canBuy => this == RoomMemberRole.owner;
}

enum DecisionStatus {
  open,
  resolved,
  skipped;

  static DecisionStatus fromWire(String? value) => switch (value) {
        'RESOLVED' => DecisionStatus.resolved,
        'SKIPPED' => DecisionStatus.skipped,
        _ => DecisionStatus.open,
      };
}

enum CandidateStatus {
  candidate,
  shortlisted,
  chosen,
  rejected;

  static CandidateStatus fromWire(String? value) => switch (value) {
        'SHORTLISTED' => CandidateStatus.shortlisted,
        'CHOSEN' => CandidateStatus.chosen,
        'REJECTED' => CandidateStatus.rejected,
        _ => CandidateStatus.candidate,
      };
}

class RoomMember extends Equatable {
  final String id;
  final String userId;
  final String? name;
  final RoomMemberRole role;
  final String roleLabel;

  const RoomMember({
    required this.id,
    required this.userId,
    required this.role,
    this.name,
    this.roleLabel = '',
  });

  @override
  List<Object?> get props => [id, userId, role];
}

/// What the room leans towards, and how firmly.
///
/// Never a verdict. [contested] and [silent] exist so the screen can say «الآراء
/// منقسمة» or «ما صوّت حدا بعد» instead of crowning a candidate half the room
/// voted against — votes advise, the woman paying decides.
class Consensus extends Equatable {
  final String? leaderId;
  final String? runnerUpId;
  final int margin;
  final int voters;
  final bool contested;
  final bool silent;

  const Consensus({
    this.leaderId,
    this.runnerUpId,
    this.margin = 0,
    this.voters = 0,
    this.contested = false,
    this.silent = true,
  });

  @override
  List<Object?> get props => [leaderId, margin, contested, silent];
}

/// An offer proposed as an answer to a decision.
class RoomCandidate extends Equatable {
  final String id;
  final CandidateStatus status;
  final String statusLabel;
  final int position;
  final int quantity;

  final String offerId;
  final String? offerVariantId;
  final String productId;
  final String title;
  final String? image;
  final String? variant;
  final String sellerId;
  final String sellerName;
  final Money? price;

  /// False when the offer has gone or run out. Shown where the argument is
  /// happening rather than at the payment step.
  final bool available;

  final int votesUp;
  final int votesDown;
  final int voteScore;

  final String? addedById;

  /// Why she put it forward, and — when rejected — why it lost.
  final String? note;
  final String? rejectionNote;

  const RoomCandidate({
    required this.id,
    required this.status,
    required this.offerId,
    required this.productId,
    required this.title,
    required this.sellerId,
    required this.sellerName,
    this.statusLabel = '',
    this.position = 0,
    this.quantity = 1,
    this.offerVariantId,
    this.image,
    this.variant,
    this.price,
    this.available = true,
    this.votesUp = 0,
    this.votesDown = 0,
    this.voteScore = 0,
    this.addedById,
    this.note,
    this.rejectionNote,
  });

  bool get isChosen => status == CandidateStatus.chosen;
  bool get isRejected => status == CandidateStatus.rejected;

  @override
  List<Object?> get props => [id, status, voteScore, available];
}

/// One question the room has to answer.
///
/// The object a cart does not have. [pickCount] is how many pieces it resolves
/// to; [remaining] is how many more must be chosen.
class RoomDecision extends Equatable {
  final String id;
  final String title;
  final String? note;
  final String? slot;
  final String? slotLabel;
  final DecisionStatus status;
  final int pickCount;
  final int position;
  final bool isRequired;

  /// The room proposed this from the occasion; she did not. Rendered more
  /// quietly, and it never blocks readiness.
  final bool isSuggested;

  final int remaining;
  final bool settled;
  final List<String> blockers;

  final Consensus consensus;
  final List<RoomCandidate> candidates;

  const RoomDecision({
    required this.id,
    required this.title,
    required this.status,
    this.note,
    this.slot,
    this.slotLabel,
    this.pickCount = 1,
    this.position = 0,
    this.isRequired = true,
    this.isSuggested = false,
    this.remaining = 1,
    this.settled = false,
    this.blockers = const [],
    this.consensus = const Consensus(),
    this.candidates = const [],
  });

  List<RoomCandidate> get live =>
      candidates.where((c) => !c.isRejected).toList(growable: false);

  List<RoomCandidate> get chosen =>
      candidates.where((c) => c.isChosen).toList(growable: false);

  bool get isSkipped => status == DecisionStatus.skipped;

  /// More than one live option and nothing chosen — the state the compare view
  /// exists for.
  bool get isContest => !settled && live.length > 1;

  @override
  List<Object?> get props => [id, status, remaining, candidates.length];
}

/// How close the room is to being buyable.
class RoomReadiness extends Equatable {
  final bool ready;
  final double progress;
  final int settledRequired;
  final int totalRequired;

  /// What is holding it, named — because "you cannot buy yet" without saying
  /// what is missing is the least useful sentence a shopping app can produce.
  final List<RoomBlocker> blockers;

  const RoomReadiness({
    this.ready = false,
    this.progress = 0,
    this.settledRequired = 0,
    this.totalRequired = 0,
    this.blockers = const [],
  });

  @override
  List<Object?> get props => [ready, progress, blockers.length];
}

class RoomBlocker extends Equatable {
  final String code;
  final String? decisionId;
  final String? decisionTitle;

  const RoomBlocker({required this.code, this.decisionId, this.decisionTitle});

  @override
  List<Object?> get props => [code, decisionId];
}

/// A shopping intent, made durable.
class Room extends Equatable {
  final String id;
  final RoomKind kind;
  final RoomStatus status;
  final String title;
  final String? note;
  final String? occasion;
  final String? occasionLabel;
  final DateTime? targetDate;
  final String? coverUrl;

  final Money? budgetMin;
  final Money? budgetMax;

  final String? recipientName;
  final bool isSurprise;

  final String? shareSlug;
  final RoomMemberRole shareRole;

  final int decisionsCount;
  final int candidatesCount;
  final int membersCount;
  final DateTime? lastActivityAt;

  final RoomReadiness? readiness;
  final List<RoomMember> members;
  final List<RoomDecision> decisions;
  final PurchasePlan? plan;

  const Room({
    required this.id,
    required this.kind,
    required this.status,
    required this.title,
    this.note,
    this.occasion,
    this.occasionLabel,
    this.targetDate,
    this.coverUrl,
    this.budgetMin,
    this.budgetMax,
    this.recipientName,
    this.isSurprise = false,
    this.shareSlug,
    this.shareRole = RoomMemberRole.advisor,
    this.decisionsCount = 0,
    this.candidatesCount = 0,
    this.membersCount = 1,
    this.lastActivityAt,
    this.readiness,
    this.members = const [],
    this.decisions = const [],
    this.plan,
  });

  bool get isShared => shareSlug != null;
  bool get isGroup => membersCount > 1;

  /// Her own role, when the members list carries her.
  RoomMemberRole roleFor(String userId) =>
      members
          .firstWhere(
            (member) => member.userId == userId,
            orElse: () => const RoomMember(
              id: '',
              userId: '',
              role: RoomMemberRole.viewer,
            ),
          )
          .role;

  @override
  List<Object?> get props => [id, status, decisionsCount, candidatesCount];
}

// ── The plan ────────────────────────────────────────────────────────────

enum PurchaseStage {
  now,
  later;

  static PurchaseStage fromWire(String? value) =>
      value == 'LATER' ? PurchaseStage.later : PurchaseStage.now;

  String get wire => this == PurchaseStage.later ? 'LATER' : 'NOW';
}

class PlanItem extends Equatable {
  final String id;
  final PurchaseStage stage;
  final int quantity;

  /// Which question this line answers. A plan line that could not say what it
  /// was decided *for* would be a cart line again.
  final String? decisionId;
  final String? decisionTitle;

  final String offerId;
  final String? offerVariantId;
  final String title;
  final String? image;
  final String? variant;
  final String sellerName;
  final Money? unitPrice;
  final Money? lineTotal;

  const PlanItem({
    required this.id,
    required this.stage,
    required this.offerId,
    required this.title,
    required this.sellerName,
    this.quantity = 1,
    this.decisionId,
    this.decisionTitle,
    this.offerVariantId,
    this.image,
    this.variant,
    this.unitPrice,
    this.lineTotal,
  });

  @override
  List<Object?> get props => [id, stage, quantity];
}

class PlanBudget extends Equatable {
  /// `under`, `inside`, `over`, or `unknown` when she set no budget.
  final String verdict;
  final Money? min;
  final Money? max;
  final Money? overBy;
  final int unpricedCount;

  const PlanBudget({
    this.verdict = 'unknown',
    this.min,
    this.max,
    this.overBy,
    this.unpricedCount = 0,
  });

  bool get isOver => verdict == 'over';
  bool get hasBudget => verdict != 'unknown';

  @override
  List<Object?> get props => [verdict, overBy];
}

/// What the room decided, as something buyable.
class PurchasePlan extends Equatable {
  final String id;
  final String roomId;
  final String status;
  final int version;
  final String? orderId;

  /// Split by stage, because that is how the screen reads and because "now" and
  /// "later" are the plan's whole reason for existing.
  final List<PlanItem> now;
  final List<PlanItem> later;

  final Money? total;
  final PlanBudget budget;

  /// Lines whose offer has since gone or run out.
  final List<String> unavailableItemIds;

  const PurchasePlan({
    required this.id,
    required this.roomId,
    required this.status,
    this.version = 1,
    this.orderId,
    this.now = const [],
    this.later = const [],
    this.total,
    this.budget = const PlanBudget(),
    this.unavailableItemIds = const [],
  });

  bool get canBuy => now.isNotEmpty && unavailableItemIds.isEmpty;
  bool get hasLater => later.isNotEmpty;

  @override
  List<Object?> get props => [id, version, now.length, later.length];
}

class RoomComment extends Equatable {
  final String id;
  final String body;
  final String? decisionId;
  final String? candidateId;
  final String memberId;
  final String memberName;
  final String? memberImage;
  final RoomMemberRole memberRole;
  final String memberRoleLabel;
  final DateTime createdAt;

  const RoomComment({
    required this.id,
    required this.body,
    required this.memberId,
    required this.memberName,
    required this.memberRole,
    required this.createdAt,
    this.decisionId,
    this.candidateId,
    this.memberImage,
    this.memberRoleLabel = '',
  });

  @override
  List<Object?> get props => [id, body, createdAt];
}

class RoomTimelineEvent extends Equatable {
  final String id;
  final String kind;
  final String label;
  final String? actorName;
  final String? actorImage;
  final DateTime createdAt;

  const RoomTimelineEvent({
    required this.id,
    required this.kind,
    required this.label,
    required this.createdAt,
    this.actorName,
    this.actorImage,
  });

  @override
  List<Object?> get props => [id, kind, createdAt];
}

// ── Comparison ──────────────────────────────────────────────────────────

/// One candidate's value on one comparison row.
class CompareCell extends Equatable {
  final String display;

  /// Best on this row. Only ever set where the row has a direction and the
  /// candidates actually differ — and a tie marks every winner.
  final bool best;

  const CompareCell({required this.display, this.best = false});

  @override
  List<Object?> get props => [display, best];
}

/// One attribute, across the candidates.
class CompareRow extends Equatable {
  final String key;
  final String label;

  /// `lower`, `higher` or `none`. Drives whether a winner is marked at all.
  final String direction;

  /// False when every candidate says the same thing — the client collapses
  /// these, because a comparison that repeats what is identical is a
  /// spreadsheet rather than a decision.
  final bool differs;

  /// Candidate id → cell.
  final Map<String, CompareCell> values;

  const CompareRow({
    required this.key,
    required this.label,
    this.direction = 'none',
    this.differs = false,
    this.values = const {},
  });

  @override
  List<Object?> get props => [key, differs, values.length];
}

/// What the comparison found, in one sentence.
///
/// Never a recommendation. [candidateId] is set only when one option wins every
/// measurable row — a fact about the options, not an opinion about her taste.
class CompareVerdict extends Equatable {
  final String code;
  final String label;
  final String? candidateId;

  const CompareVerdict({
    required this.code,
    required this.label,
    this.candidateId,
  });

  bool get namesAWinner => candidateId != null;

  @override
  List<Object?> get props => [code, candidateId];
}

class RoomComparison extends Equatable {
  final String decisionId;
  final String decisionTitle;
  final List<String> candidateIds;
  final List<CompareRow> rows;
  final Consensus consensus;
  final CompareVerdict verdict;
  final Map<String, int> commentCounts;

  const RoomComparison({
    required this.decisionId,
    required this.decisionTitle,
    required this.verdict,
    this.candidateIds = const [],
    this.rows = const [],
    this.consensus = const Consensus(),
    this.commentCounts = const {},
  });

  List<CompareRow> get differing =>
      rows.where((row) => row.differs).toList(growable: false);

  List<CompareRow> get identical =>
      rows.where((row) => !row.differs).toList(growable: false);

  bool get hasEnough => candidateIds.length >= 2;

  @override
  List<Object?> get props => [decisionId, candidateIds.length, rows.length];
}
