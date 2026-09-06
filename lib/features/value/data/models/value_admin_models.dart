import 'package:reem/core/shared/value_objects/money.dart';
import 'package:reem/features/value/domain/entities/value_admin.dart';

/// Wire decoding for the administrative side of Reem Value.
///
/// Kept apart from `value_models.dart` because the two have different readers
/// and different risks: a customer's standing must degrade to something
/// harmless when a field is missing, while an operator's cost report must not
/// quietly render a zero where the server said nothing. Every decoder below is
/// still total, but the nullable money fields stay null rather than becoming
/// `0 SYP` — an unknown exposure and a zero exposure are different answers.

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

int? _intOrNull(Object? value) => switch (value) {
      final num n => n.toInt(),
      final String s => int.tryParse(s),
      _ => null,
    };

double _double(Object? value) => switch (value) {
      final num n => n.toDouble(),
      final String s => double.tryParse(s) ?? 0,
      _ => 0,
    };

DateTime? _date(Object? value) =>
    value is String ? DateTime.tryParse(value) : null;

ValueGuarantee guaranteeFromJson(Map<String, dynamic> json) => ValueGuarantee(
      spendingCeiling: _int(json['spendingCeiling'] ?? json['spending_ceiling']),
      holds: json['holds'] == true,
      highestRungReachableBySpending:
          (json['highestRungReachableBySpending'] ??
              json['highest_rung_reachable_by_spending']) as String?,
      topRung: (json['topRung'] ?? json['top_rung']) as String?,
    );

ValueDistribution distributionFromJson(Map<String, dynamic> json) =>
    ValueDistribution(
      total: _int(json['total']),
      guarantee: guaranteeFromJson(_map(json['guarantee'])),
      unranked: _int(json['unranked']),
      tiers: _maps(json['tiers'])
          .map(
            (tier) => TierDistributionRow(
              key: tier['key']?.toString() ?? '',
              name: tier['name']?.toString() ?? '',
              minScore: _int(tier['minScore'] ?? tier['min_score']),
              count: _int(tier['count']),
              shareBps: _int(tier['shareBps'] ?? tier['share_bps']),
              averageScore: _int(tier['averageScore'] ?? tier['average_score']),
            ),
          )
          .toList(growable: false),
    );

ValueCostReport costFromJson(Map<String, dynamic> json) => ValueCostReport(
      issuedTotal: Money.tryFromJson(json['issuedTotal'] ?? json['issued_total']),
      ceilingTotal:
          Money.tryFromJson(json['ceilingTotal'] ?? json['ceiling_total']),
      unboundedCount: _int(json['unboundedCount'] ?? json['unbounded_count']),
      benefits: _maps(json['benefits'])
          .map(
            (row) => BenefitCostRow(
              key: row['key']?.toString() ?? '',
              kind: row['kind']?.toString() ?? '',
              title: row['title']?.toString() ?? '',
              unitCost: Money.tryFromJson(row['unitCost'] ?? row['unit_cost']),
              granted: _int(row['granted']),
              budget: _intOrNull(row['budget']),
              issued: Money.tryFromJson(row['issued']),
              ceiling: Money.tryFromJson(row['ceiling']),
              unbounded: row['unbounded'] == true,
            ),
          )
          .toList(growable: false),
    );

ValuePolicyVersion policyFromJson(Map<String, dynamic> json) =>
    ValuePolicyVersion(
      id: json['id']?.toString() ?? '',
      version: _int(json['version']),
      isActive: (json['isActive'] ?? json['is_active']) == true,
      pillarWeights: _map(json['pillarWeights'] ?? json['pillar_weights']),
      pillarScales: _map(json['pillarScales'] ?? json['pillar_scales']),
      eventWeights: _map(json['eventWeights'] ?? json['event_weights']),
      dailyPillarCaps: _map(json['dailyPillarCaps'] ?? json['daily_pillar_caps']),
      halfLifeDays: _int(json['halfLifeDays'] ?? json['half_life_days']),
      horizonDays: _int(json['horizonDays'] ?? json['horizon_days']),
      commerceCeilingBps:
          _int(json['commerceCeilingBps'] ?? json['commerce_ceiling_bps']),
      reliabilityBaseline:
          _int(json['reliabilityBaseline'] ?? json['reliability_baseline']),
      minEvidencePerPillar:
          _int(json['minEvidencePerPillar'] ?? json['min_evidence_per_pillar']),
      note: json['note'] as String?,
      createdAt: _date(json['createdAt'] ?? json['created_at']),
      activatedAt: _date(json['activatedAt'] ?? json['activated_at']),
    );

List<ValuePolicyVersion> policiesFromJson(Object? value) =>
    _maps(value).map(policyFromJson).toList(growable: false);

ValueSimulation simulationFromJson(Map<String, dynamic> json) => ValueSimulation(
      sampled: _int(json['sampled']),
      movedUp: _int(json['movedUp'] ?? json['moved_up']),
      movedDown: _int(json['movedDown'] ?? json['moved_down']),
      unchanged: _int(json['unchanged']),
      averageScoreDelta:
          _double(json['averageScoreDelta'] ?? json['average_score_delta']),
      tierCounts: {
        for (final entry in _map(json['tierCounts'] ?? json['tier_counts']).entries)
          entry.key: _int(entry.value),
      },
    );

List<ValueSuspect> suspectsFromJson(Object? value) => _maps(value)
    .map(
      (row) => ValueSuspect(
        userId: (row['userId'] ?? row['user_id'])?.toString() ?? '',
        score: _int(row['score']),
        tierKey: (row['tierKey'] ?? row['tier_key']) as String?,
        reasons: _strings(row['reasons']),
        concentration: _double(row['concentration']),
        distinctDays: _int(row['distinctDays'] ?? row['distinct_days']),
      ),
    )
    .toList(growable: false);
