import 'package:ohara/features/closet/data/models/closet_models.dart';
import 'package:ohara/features/occasions/domain/entities/occasion.dart';
import 'package:ohara/features/salons/data/models/salon_models.dart';

/// Wire decoding for «مناسباتي».
///
/// Total, like the other decoders: a missing field yields the empty value
/// rather than throwing, so one malformed occasion costs one card.
///
/// The look and the appointment arrive in their own features' shapes, and are
/// decoded with those features' own functions — an occasion's look can never
/// read differently from the same look in the closet.

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

bool _bool(Object? value) => value == true || value == 'true';

String _string(Object? value) => value?.toString() ?? '';

String? _text(Object? value) {
  final text = value?.toString().trim();
  return text == null || text.isEmpty ? null : text;
}

/// `YYYY-MM-DD` → a local calendar date. Parsed by hand rather than with
/// `DateTime.parse`, which reads a bare date as UTC midnight and would show
/// the 14th as the 13th to anyone west of Greenwich.
DateTime occasionDateFromWire(Object? value) {
  final match = RegExp(
    r'^(\d{4})-(\d{2})-(\d{2})',
  ).firstMatch('${value ?? ''}');
  if (match == null) return DateTime.now();
  return DateTime(
    int.parse(match.group(1)!),
    int.parse(match.group(2)!),
    int.parse(match.group(3)!),
  );
}

/// A local calendar date → `YYYY-MM-DD`.
String occasionDateToWire(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-'
    '${date.month.toString().padLeft(2, '0')}-'
    '${date.day.toString().padLeft(2, '0')}';

OccasionStep? occasionStepFromJson(Map<String, dynamic> json) {
  final key = OccasionStepKey.fromWire(json['key'] as String?);
  if (key == null) return null; // a step this build does not know yet
  return OccasionStep(
    key: key,
    state: OccasionStepState.fromWire(json['state'] as String?),
    manual: _bool(json['manual']),
    urgent: _bool(json['urgent']),
    count: json['count'] == null ? null : _int(json['count']),
  );
}

OccasionRepeat occasionRepeatFromJson(Map<String, dynamic> json) =>
    OccasionRepeat(
      occasionId: _string(json['occasion_id']),
      title: _string(json['title']),
      date: occasionDateFromWire(json['date']),
      upcoming: _bool(json['upcoming']),
      sameLook: _bool(json['same_look']),
      pieces: [
        for (final piece in _maps(json['pieces']))
          RepeatPiece(id: _string(piece['id']), title: _string(piece['title'])),
      ],
    );

Occasion occasionFromJson(Map<String, dynamic> json) {
  final progress = _map(json['progress']);
  return Occasion(
    id: _string(json['id']),
    title: _string(json['title']),
    kind: OccasionKind.fromWire(json['kind'] as String?),
    date: occasionDateFromWire(json['date']),
    daysLeft: _int(json['days_left']),
    startsAtTime: _text(json['starts_at_time']),
    location: _text(json['location']),
    circle: _text(json['circle']),
    note: _text(json['note']),
    remindersEnabled:
        json['reminders_enabled'] == null || _bool(json['reminders_enabled']),
    lookOccasion: _text(json['look_occasion']),
    look: json['look'] is Map ? closetLookFromJson(_map(json['look'])) : null,
    appointment: json['appointment'] is Map
        ? appointmentFromJson(_map(json['appointment']))
        : null,
    steps: _maps(
      json['steps'],
    ).map(occasionStepFromJson).whereType<OccasionStep>().toList(),
    doneCount: _int(progress['done']),
    totalCount: _int(progress['total']),
    nextStep: OccasionStepKey.fromWire(json['next_step'] as String?),
    repeats: _maps(json['repeats']).map(occasionRepeatFromJson).toList(),
  );
}

List<Occasion> occasionsFromJson(Object? value) =>
    _maps(value).map(occasionFromJson).toList();
