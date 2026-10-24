import 'package:equatable/equatable.dart';
import 'package:ohara/core/shared/value_objects/money.dart';

/// Whether money can still climb the ladder.
///
/// The programme's central promise, as a checkable fact. It travels attached to
/// the distribution rather than on a screen of its own, because nobody should
/// be able to look at how the population is spread without also seeing what a
/// pure spender can reach.
class ValueGuarantee extends Equatable {
  /// The highest standing reachable by spending and nothing else.
  final int spendingCeiling;

  /// The rung that ceiling lands on.
  final String? highestRungReachableBySpending;
  final String? topRung;

  /// False when money has climbed into the top two rungs — the state that means
  /// the programme has quietly become a spending ladder.
  final bool holds;

  const ValueGuarantee({
    required this.spendingCeiling,
    required this.holds,
    this.highestRungReachableBySpending,
    this.topRung,
  });

  @override
  List<Object?> get props => [spendingCeiling, holds];
}

class TierDistributionRow extends Equatable {
  final String key;
  final String name;
  final int minScore;
  final int count;

  /// Share of the population, in basis points. Integer so a share never renders
  /// as 33.333333%.
  final int shareBps;
  final int averageScore;

  const TierDistributionRow({
    required this.key,
    required this.name,
    required this.minScore,
    required this.count,
    required this.shareBps,
    required this.averageScore,
  });

  double get sharePercent => shareBps / 100;

  @override
  List<Object?> get props => [key, count, shareBps];
}

class ValueDistribution extends Equatable {
  final int total;
  final List<TierDistributionRow> tiers;
  final int unranked;
  final ValueGuarantee guarantee;

  const ValueDistribution({
    required this.total,
    required this.guarantee,
    this.tiers = const [],
    this.unranked = 0,
  });

  @override
  List<Object?> get props => [total, tiers.length, guarantee];
}

/// What one benefit has cost and could still cost.
class BenefitCostRow extends Equatable {
  final String key;
  final String kind;
  final String title;
  final Money? unitCost;
  final int granted;
  final int? budget;
  final Money? issued;

  /// The most it can still cost. Null means unbounded.
  final Money? ceiling;

  /// True when it spends money and has no budget — the one state this report
  /// exists to surface.
  final bool unbounded;

  const BenefitCostRow({
    required this.key,
    required this.kind,
    required this.title,
    required this.granted,
    this.unitCost,
    this.budget,
    this.issued,
    this.ceiling,
    this.unbounded = false,
  });

  @override
  List<Object?> get props => [key, granted, unbounded];
}

class ValueCostReport extends Equatable {
  final List<BenefitCostRow> benefits;
  final Money? issuedTotal;
  final Money? ceilingTotal;
  final int unboundedCount;

  const ValueCostReport({
    this.benefits = const [],
    this.issuedTotal,
    this.ceilingTotal,
    this.unboundedCount = 0,
  });

  @override
  List<Object?> get props => [benefits.length, unboundedCount];
}

/// One version of the economics.
class ValuePolicyVersion extends Equatable {
  final String id;
  final int version;
  final bool isActive;
  final Map<String, dynamic> pillarWeights;
  final Map<String, dynamic> pillarScales;
  final Map<String, dynamic> eventWeights;
  final Map<String, dynamic> dailyPillarCaps;
  final int halfLifeDays;
  final int horizonDays;
  final int commerceCeilingBps;
  final int reliabilityBaseline;
  final int minEvidencePerPillar;
  final String? note;
  final DateTime? createdAt;
  final DateTime? activatedAt;

  const ValuePolicyVersion({
    required this.id,
    required this.version,
    this.isActive = false,
    this.pillarWeights = const {},
    this.pillarScales = const {},
    this.eventWeights = const {},
    this.dailyPillarCaps = const {},
    this.halfLifeDays = 365,
    this.horizonDays = 1095,
    this.commerceCeilingBps = 2500,
    this.reliabilityBaseline = 70,
    this.minEvidencePerPillar = 2,
    this.note,
    this.createdAt,
    this.activatedAt,
  });

  /// The commerce ceiling as points of the 1000-point scale — the unit an
  /// administrator actually reasons in, rather than basis points.
  int get commerceCeilingPoints => (commerceCeilingBps / 10000 * 1000).round();

  @override
  List<Object?> get props => [id, version, isActive];
}

/// What a draft would do to the live population, before it touches anybody.
class ValueSimulation extends Equatable {
  final int sampled;
  final int movedUp;
  final int movedDown;
  final int unchanged;
  final Map<String, int> tierCounts;
  final double averageScoreDelta;

  const ValueSimulation({
    required this.sampled,
    this.movedUp = 0,
    this.movedDown = 0,
    this.unchanged = 0,
    this.tierCounts = const {},
    this.averageScoreDelta = 0,
  });

  /// The number that should give an administrator pause: women who would lose a
  /// rung the moment this is activated.
  bool get isDisruptive => sampled > 0 && movedDown / sampled > 0.05;

  @override
  List<Object?> get props => [sampled, movedUp, movedDown, averageScoreDelta];
}

/// A profile whose shape is unusual enough to look at.
///
/// Deliberately not "fraud". Every reason here is explainable innocently — a
/// prolific reviewer really does look like this — which is why it is a queue
/// for a person rather than an automatic penalty.
class ValueSuspect extends Equatable {
  final String userId;
  final int score;
  final String? tierKey;

  /// `single_pillar`, `burst`.
  final List<String> reasons;

  /// How much of her standing comes from one pillar, 0–1.
  final double concentration;
  final int distinctDays;

  const ValueSuspect({
    required this.userId,
    required this.score,
    this.tierKey,
    this.reasons = const [],
    this.concentration = 0,
    this.distinctDays = 0,
  });

  @override
  List<Object?> get props => [userId, score, reasons];
}

/// A draft, as the editor builds it.
class ValuePolicyDraft {
  final Map<String, int>? pillarWeights;
  final int? halfLifeDays;
  final int? commerceCeilingBps;
  final int? reliabilityBaseline;
  final int? minEvidencePerPillar;
  final String? note;

  const ValuePolicyDraft({
    this.pillarWeights,
    this.halfLifeDays,
    this.commerceCeilingBps,
    this.reliabilityBaseline,
    this.minEvidencePerPillar,
    this.note,
  });

  Map<String, dynamic> toJson() => {
        if (pillarWeights != null) 'pillar_weights': pillarWeights,
        if (halfLifeDays != null) 'half_life_days': halfLifeDays,
        if (commerceCeilingBps != null) 'commerce_ceiling_bps': commerceCeilingBps,
        if (reliabilityBaseline != null) 'reliability_baseline': reliabilityBaseline,
        if (minEvidencePerPillar != null)
          'min_evidence_per_pillar': minEvidencePerPillar,
        if (note != null && note!.isNotEmpty) 'note': note,
      };
}
