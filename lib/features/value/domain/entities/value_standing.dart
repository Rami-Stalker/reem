import 'package:equatable/equatable.dart';

/// One rung of the ladder.
class ValueTier extends Equatable {
  final String key;
  final String name;
  final int minScore;
  final int rank;

  /// Free-form presentation from the server: tone, and the sentence her card
  /// shows at this rung. Held as a map so an administrator can restyle a rung
  /// without an app release.
  final Map<String, dynamic> presentation;

  const ValueTier({
    required this.key,
    required this.name,
    required this.minScore,
    required this.rank,
    this.presentation = const {},
  });

  String? get blurb => presentation['blurbAr'] as String?;
  String? get tone => presentation['tone'] as String?;

  @override
  List<Object?> get props => [key, minScore, rank];
}

/// How much evidence there is behind a pillar.
///
/// `insufficient` is not a low score. It means Reem does not yet know, and the
/// UI says so in those words — telling a woman she scores zero on something it
/// has never seen her do would be an accusation dressed as arithmetic.
enum PillarEvidence {
  sufficient,
  insufficient;

  static PillarEvidence fromWire(String? value) =>
      value == 'sufficient' ? PillarEvidence.sufficient : PillarEvidence.insufficient;
}

/// One dimension of her standing.
class ValuePillar extends Equatable {
  final String pillar;
  final String label;
  final String blurb;

  /// 0–100 within the pillar.
  final double score;

  /// Points this pillar puts into the 0–1000 total.
  final double contribution;

  final int events;
  final PillarEvidence evidence;

  /// True when the commerce ceiling clipped it — the visible face of "money
  /// alone does not get you to the top".
  final bool capped;

  const ValuePillar({
    required this.pillar,
    required this.label,
    required this.blurb,
    required this.score,
    required this.contribution,
    this.events = 0,
    this.evidence = PillarEvidence.insufficient,
    this.capped = false,
  });

  bool get isKnown => evidence == PillarEvidence.sufficient;

  @override
  List<Object?> get props => [pillar, score, contribution, evidence];
}

/// One contribution, as she sees it.
class ValueEvent extends Equatable {
  final String id;
  final String pillar;
  final String pillarLabel;
  final String code;

  /// What she did, in her own language.
  final String label;

  /// What had to be true for it to count. Shown on the row that did not count,
  /// which is the one she has questions about.
  final String? evidenceNote;

  final String status;
  final int weight;
  final DateTime occurredAt;
  final String? reversedReason;

  const ValueEvent({
    required this.id,
    required this.pillar,
    required this.pillarLabel,
    required this.code,
    required this.label,
    required this.status,
    required this.weight,
    required this.occurredAt,
    this.evidenceNote,
    this.reversedReason,
  });

  bool get isReversed => status == 'REVERSED';
  bool get isPositive => weight > 0;

  @override
  List<Object?> get props => [id, status, weight, occurredAt];
}

/// Something her standing opens.
class ValueBenefit extends Equatable {
  final String key;
  final String kind;
  final String title;
  final String? description;
  final Map<String, dynamic> config;

  final bool unlocked;

  /// The rung that would open it. The most motivating field on a locked card,
  /// and the reason locked benefits are shown rather than hidden.
  final String? requiresTier;

  /// `quota`, `budget` or `window` — unlocked but not available right now.
  final String? blockedBy;

  final ValueGrant? grant;

  const ValueBenefit({
    required this.key,
    required this.kind,
    required this.title,
    this.description,
    this.config = const {},
    this.unlocked = false,
    this.requiresTier,
    this.blockedBy,
    this.grant,
  });

  /// Open to her and actually available.
  bool get available => unlocked && blockedBy == null;

  /// Something she has to take up, as opposed to something simply true of her.
  /// A gift is claimed; priority in a queue is not.
  bool get isClaimable =>
      available && grant == null && (kind == 'GIFT' || kind == 'PERSONALISED_OFFER');

  @override
  List<Object?> get props => [key, unlocked, blockedBy, grant?.id];
}

class ValueGrant extends Equatable {
  final String id;
  final String status;
  final DateTime? expiresAt;

  const ValueGrant({required this.id, required this.status, this.expiresAt});

  @override
  List<Object?> get props => [id, status, expiresAt];
}

/// A day on the line.
class ValueSnapshot extends Equatable {
  final String date;
  final int score;
  final String? tier;

  const ValueSnapshot({required this.date, required this.score, this.tier});

  @override
  List<Object?> get props => [date, score];
}

/// What would move her, expressed as a dimension rather than as a number.
class ValueAdvice extends Equatable {
  final String pillar;
  final String label;
  final String blurb;
  final double headroom;

  const ValueAdvice({
    required this.pillar,
    required this.label,
    required this.blurb,
    required this.headroom,
  });

  @override
  List<Object?> get props => [pillar, headroom];
}

/// Her standing, whole.
///
/// The shape enforces the same rule the server's serializer does: a number
/// never travels alone. [pillars], [recent] and [advice] are not decoration on
/// this object, they are what stops it being a credit score.
class ValueStanding extends Equatable {
  final int score;

  /// The highest she has ever stood. Never falls — a relationship that dipped
  /// is not one that never happened.
  final int peakScore;

  /// Score minus score thirty days ago.
  final int momentum;

  final ValueTier? tier;
  final ValueTier? nextTier;
  final int toNextTier;
  final DateTime? tierAchievedAt;

  /// Set while a rung is being held despite a fall. She is told rather than
  /// silently protected and later surprised.
  final DateTime? tierHeldUntil;

  final bool frozen;

  final List<ValueTier> ladder;
  final List<ValuePillar> pillars;
  final List<ValueAdvice> advice;
  final List<ValueEvent> recent;
  final List<ValueSnapshot> history;
  final List<ValueBenefit> benefits;

  const ValueStanding({
    required this.score,
    this.peakScore = 0,
    this.momentum = 0,
    this.tier,
    this.nextTier,
    this.toNextTier = 0,
    this.tierAchievedAt,
    this.tierHeldUntil,
    this.frozen = false,
    this.ladder = const [],
    this.pillars = const [],
    this.advice = const [],
    this.recent = const [],
    this.history = const [],
    this.benefits = const [],
  });

  bool get isRising => momentum > 0;
  bool get isFalling => momentum < 0;

  List<ValueBenefit> get unlockedBenefits =>
      benefits.where((benefit) => benefit.available).toList(growable: false);

  List<ValueBenefit> get lockedBenefits =>
      benefits.where((benefit) => !benefit.unlocked).toList(growable: false);

  /// How far along she is between her rung and the next, 0–1.
  double get progressToNext {
    final next = nextTier;
    if (next == null) return 1;
    final floor = tier?.minScore ?? 0;
    final span = next.minScore - floor;
    if (span <= 0) return 1;
    return ((score - floor) / span).clamp(0.0, 1.0);
  }

  @override
  List<Object?> get props => [score, tier?.key, momentum, benefits.length];
}

/// The compact form, for badges and headers.
class ValueBadge extends Equatable {
  final int score;
  final String? tierKey;
  final String? tierName;
  final int momentum;
  final String? nextTierName;
  final int toNextTier;

  const ValueBadge({
    required this.score,
    this.tierKey,
    this.tierName,
    this.momentum = 0,
    this.nextTierName,
    this.toNextTier = 0,
  });

  @override
  List<Object?> get props => [score, tierKey, momentum];
}

/// One published earning rule.
///
/// The whole table is public. A programme whose rules are secret is one nobody
/// can trust or plan around.
class ValueRule extends Equatable {
  final String code;
  final String pillar;
  final String label;
  final String evidence;
  final int weight;

  const ValueRule({
    required this.code,
    required this.pillar,
    required this.label,
    required this.evidence,
    required this.weight,
  });

  @override
  List<Object?> get props => [code, weight];
}
