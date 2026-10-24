import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ohara/core/presentation/providers/core_providers.dart';
import 'package:ohara/features/auth/presentation/providers/auth_provider.dart';
import 'package:ohara/features/occasions/data/datasources/occasions_remote_datasource.dart';
import 'package:ohara/features/occasions/domain/entities/occasion.dart';

/// «مناسباتي», wired.
///
/// The same shape as the salon feature: `FutureProvider`s for reads, one
/// actions object for every write so that each write invalidates the same set
/// of reads. `autoDispose` throughout — a calendar she has left stops holding
/// her looks and bookings in memory.

final occasionsDataSourceProvider = Provider<OccasionsRemoteDataSource>(
  (ref) => OccasionsRemoteDataSourceImpl(ref.watch(dioProvider)),
);

/// Her occasions. `true` for upcoming, soonest first; `false` for past.
final occasionsProvider = FutureProvider.autoDispose
    .family<List<Occasion>, bool>((ref, upcoming) {
      // Rebuilt when the account changes: whose wedding it is matters.
      ref.watch(authNotifierProvider.select((s) => s.user?.id));
      return ref
          .watch(occasionsDataSourceProvider)
          .occasions(upcoming: upcoming);
    });

final occasionProvider = FutureProvider.autoDispose.family<Occasion, String>(
  (ref, id) => ref.watch(occasionsDataSourceProvider).occasion(id),
);

/// Every write to an occasion, in one place.
///
/// Each one returns the occasion as the server now sees it — with the plan
/// recomputed and the repeat warning re-checked — and invalidates both lists
/// and that occasion, so the card she goes back to says the same as the page
/// she left.
class OccasionActions {
  OccasionActions(this._ref);

  final Ref _ref;

  OccasionsRemoteDataSource get _api => _ref.read(occasionsDataSourceProvider);

  Future<Occasion> create(OccasionDraft draft) =>
      _write(null, () => _api.create(draft));

  Future<Occasion> update(String id, OccasionDraft draft) =>
      _write(id, () => _api.update(id, draft));

  Future<Occasion> setLook(String id, String? lookId) =>
      _write(id, () => _api.setLook(id, lookId));

  Future<Occasion> setAppointment(String id, String? appointmentId) =>
      _write(id, () => _api.setAppointment(id, appointmentId));

  Future<Occasion> setRemindersEnabled(String id, bool enabled) =>
      _write(id, () => _api.setRemindersEnabled(id, enabled));

  Future<Occasion> setStep(
    String id,
    OccasionStepKey key, {
    required bool done,
  }) => _write(id, () => _api.setStep(id, key, done: done));

  Future<void> remove(String id) async {
    await _api.remove(id);
    _ref.invalidate(occasionsProvider);
  }

  Future<Occasion> _write(String? id, Future<Occasion> Function() write) async {
    final occasion = await write();
    _ref.invalidate(occasionsProvider);
    if (id != null) _ref.invalidate(occasionProvider(id));
    return occasion;
  }
}

final occasionActionsProvider = Provider<OccasionActions>(OccasionActions.new);
