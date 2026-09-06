import 'package:reem/features/value/domain/entities/value_standing.dart';

/// Wire decoding for Reem Value.
///
/// Free functions rather than model subclasses, matching the stylist and the
/// closet. Every decoder is total: a missing field yields the empty value
/// rather than throwing, because a malformed row on a standing screen should
/// cost one line, not the screen.

Map<String, dynamic> _map(Object? value) =>
    value is Map ? Map<String, dynamic>.from(value) : const {};

List<Map<String, dynamic>> _maps(Object? value) => value is List
    ? value.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList()
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

ValueTier tierFromJson(Map<String, dynamic> json) => ValueTier(
      key: json['key']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      minScore: _int(json['min_score']),
      rank: _int(json['rank']),
      presentation: _map(json['presentation']),
    );

ValuePillar pillarFromJson(Map<String, dynamic> json) => ValuePillar(
      pillar: json['pillar']?.toString() ?? '',
      label: json['label']?.toString() ?? '',
      blurb: json['blurb']?.toString() ?? '',
      score: _double(json['score']),
      contribution: _double(json['contribution']),
      events: _int(json['events']),
      evidence: PillarEvidence.fromWire(json['evidence'] as String?),
      capped: json['capped'] == true,
    );

ValueEvent eventFromJson(Map<String, dynamic> json) => ValueEvent(
      id: json['id']?.toString() ?? '',
      pillar: json['pillar']?.toString() ?? '',
      pillarLabel: json['pillar_label']?.toString() ?? '',
      code: json['code']?.toString() ?? '',
      label: json['label']?.toString() ?? '',
      evidenceNote: json['evidence_note'] as String?,
      status: json['status']?.toString() ?? 'CONFIRMED',
      weight: _int(json['weight']),
      occurredAt: _date(json['occurred_at']) ?? DateTime.now(),
      reversedReason: json['reversed_reason'] as String?,
    );

ValueGrant? grantFromJson(Object? value) {
  if (value is! Map) return null;
  final json = Map<String, dynamic>.from(value);
  return ValueGrant(
    id: json['id']?.toString() ?? '',
    status: json['status']?.toString() ?? 'OFFERED',
    expiresAt: _date(json['expires_at']),
  );
}

ValueBenefit benefitFromJson(Map<String, dynamic> json) => ValueBenefit(
      key: json['key']?.toString() ?? '',
      kind: json['kind']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      description: json['description'] as String?,
      config: _map(json['config']),
      unlocked: json['unlocked'] == true,
      requiresTier: json['requires_tier'] as String?,
      blockedBy: json['blocked_by'] as String?,
      grant: grantFromJson(json['grant']),
    );

ValueSnapshot snapshotFromJson(Map<String, dynamic> json) => ValueSnapshot(
      date: json['date']?.toString() ?? '',
      score: _int(json['score']),
      tier: json['tier'] as String?,
    );

ValueAdvice adviceFromJson(Map<String, dynamic> json) => ValueAdvice(
      pillar: json['pillar']?.toString() ?? '',
      label: json['label']?.toString() ?? '',
      blurb: json['blurb']?.toString() ?? '',
      headroom: _double(json['headroom']),
    );

ValueStanding standingFromJson(Map<String, dynamic> json) => ValueStanding(
      score: _int(json['score']),
      peakScore: _int(json['peak_score']),
      momentum: _int(json['momentum']),
      tier: json['tier'] is Map ? tierFromJson(_map(json['tier'])) : null,
      nextTier:
          json['next_tier'] is Map ? tierFromJson(_map(json['next_tier'])) : null,
      toNextTier: _int(json['to_next_tier']),
      tierAchievedAt: _date(json['tier_achieved_at']),
      tierHeldUntil: _date(json['tier_held_until']),
      frozen: json['frozen'] == true,
      ladder: _maps(json['ladder']).map(tierFromJson).toList(growable: false),
      pillars: _maps(json['pillars']).map(pillarFromJson).toList(growable: false),
      advice: _maps(json['advice']).map(adviceFromJson).toList(growable: false),
      recent: _maps(json['recent']).map(eventFromJson).toList(growable: false),
      history: _maps(json['history']).map(snapshotFromJson).toList(growable: false),
      benefits: _maps(json['benefits']).map(benefitFromJson).toList(growable: false),
    );

ValueBadge badgeFromJson(Map<String, dynamic> json) => ValueBadge(
      score: _int(json['score']),
      tierKey: json['tierKey'] as String? ?? json['tier_key'] as String?,
      tierName: json['tierName'] as String? ?? json['tier_name'] as String?,
      momentum: _int(json['momentum']),
      nextTierName:
          json['nextTierName'] as String? ?? json['next_tier_name'] as String?,
      toNextTier: _int(json['toNextTier'] ?? json['to_next_tier']),
    );

ValueRule ruleFromJson(Map<String, dynamic> json) => ValueRule(
      code: json['code']?.toString() ?? '',
      pillar: json['pillar']?.toString() ?? '',
      label: json['label']?.toString() ?? '',
      evidence: json['evidence']?.toString() ?? '',
      weight: _int(json['weight']),
    );

List<ValueRule> rulesFromJson(Map<String, dynamic> json) =>
    _maps(json['rules']).map(ruleFromJson).toList(growable: false);

List<ValueEvent> eventsFromJson(Object? value) =>
    _maps(value).map(eventFromJson).toList(growable: false);

List<ValueBenefit> benefitsFromJson(Object? value) =>
    _maps(value).map(benefitFromJson).toList(growable: false);
