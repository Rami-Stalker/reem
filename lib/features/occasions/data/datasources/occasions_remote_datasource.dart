import 'package:ohara/core/network/api_endpoints.dart';
import 'package:ohara/core/network/base_remote_datasource.dart';
import 'package:ohara/features/occasions/data/models/occasion_models.dart';
import 'package:ohara/features/occasions/domain/entities/occasion.dart';

/// What she writes down about a day, from the editor.
///
/// Used for both create and edit. On edit every field is sent, and an empty
/// optional field is sent as null so that clearing the location in the form
/// clears it on the server — the editor shows the whole row, so the whole row
/// is what she means.
class OccasionDraft {
  const OccasionDraft({
    required this.title,
    required this.kind,
    required this.date,
    this.startsAtTime,
    this.location,
    this.circle,
    this.note,
    this.remindersEnabled = true,
  });

  final String title;
  final OccasionKind kind;
  final DateTime date;
  final String? startsAtTime;
  final String? location;
  final String? circle;
  final String? note;
  final bool remindersEnabled;

  static String? _clean(String? value) {
    final text = value?.trim();
    return text == null || text.isEmpty ? null : text;
  }

  Map<String, dynamic> toCreateJson() => {
    'title': title.trim(),
    'kind': kind.wire,
    'date': occasionDateToWire(date),
    'starts_at_time': ?_clean(startsAtTime),
    'location': ?_clean(location),
    'circle': ?_clean(circle),
    'note': ?_clean(note),
    'reminders_enabled': remindersEnabled,
  };

  Map<String, dynamic> toUpdateJson() => {
    'title': title.trim(),
    'kind': kind.wire,
    'date': occasionDateToWire(date),
    'starts_at_time': _clean(startsAtTime),
    'location': _clean(location),
    'circle': _clean(circle),
    'note': _clean(note),
    'reminders_enabled': remindersEnabled,
  };
}

abstract interface class OccasionsRemoteDataSource {
  /// `upcoming` (soonest first) or `past` (latest first).
  Future<List<Occasion>> occasions({required bool upcoming});

  Future<Occasion> occasion(String id);

  Future<Occasion> create(OccasionDraft draft);

  Future<Occasion> update(String id, OccasionDraft draft);

  /// Null unlinks the look.
  Future<Occasion> setLook(String id, String? lookId);

  /// Null unlinks the appointment.
  Future<Occasion> setAppointment(String id, String? appointmentId);

  Future<Occasion> setRemindersEnabled(String id, bool enabled);

  /// Tick or untick a step she does by hand.
  Future<Occasion> setStep(
    String id,
    OccasionStepKey key, {
    required bool done,
  });

  Future<void> remove(String id);
}

final class OccasionsRemoteDataSourceImpl extends BaseRemoteDataSource
    implements OccasionsRemoteDataSource {
  const OccasionsRemoteDataSourceImpl(super.dio);

  @override
  Future<List<Occasion>> occasions({required bool upcoming}) async =>
      occasionsFromJson(
        await getList(
          ApiEndpoints.occasions,
          query: {'scope': upcoming ? 'upcoming' : 'past'},
        ),
      );

  @override
  Future<Occasion> occasion(String id) =>
      getDecoded(ApiEndpoints.occasion(id), decode: occasionFromJson);

  @override
  Future<Occasion> create(OccasionDraft draft) async => occasionFromJson(
    await postJson(ApiEndpoints.occasions, body: draft.toCreateJson()),
  );

  @override
  Future<Occasion> update(String id, OccasionDraft draft) async =>
      occasionFromJson(
        await patchJson(ApiEndpoints.occasion(id), body: draft.toUpdateJson()),
      );

  @override
  Future<Occasion> setLook(String id, String? lookId) async => occasionFromJson(
    await patchJson(ApiEndpoints.occasion(id), body: {'look_id': lookId}),
  );

  @override
  Future<Occasion> setAppointment(String id, String? appointmentId) async =>
      occasionFromJson(
        await patchJson(
          ApiEndpoints.occasion(id),
          body: {'appointment_id': appointmentId},
        ),
      );

  @override
  Future<Occasion> setRemindersEnabled(String id, bool enabled) async =>
      occasionFromJson(
        await patchJson(
          ApiEndpoints.occasion(id),
          body: {'reminders_enabled': enabled},
        ),
      );

  @override
  Future<Occasion> setStep(
    String id,
    OccasionStepKey key, {
    required bool done,
  }) async => occasionFromJson(
    await putJson(
      ApiEndpoints.occasionStep(id, key.wire),
      body: {'done': done},
    ),
  );

  @override
  Future<void> remove(String id) => deleteRequest(ApiEndpoints.occasion(id));
}
