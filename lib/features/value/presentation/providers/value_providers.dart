import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ohara/core/presentation/providers/core_providers.dart';
import 'package:ohara/core/result/result.dart';
import 'package:ohara/features/value/data/datasources/impl/value_remote_datasource_impl.dart';
import 'package:ohara/features/value/data/datasources/value_remote_datasource.dart';
import 'package:ohara/features/value/data/repositories/value_repository_impl.dart';
import 'package:ohara/features/value/domain/entities/value_standing.dart';
import 'package:ohara/features/value/domain/repositories/value_repository.dart';

// ── Infrastructure ──────────────────────────────────────────────────────

final valueRemoteDataSourceProvider = Provider<ValueRemoteDataSource>(
  (ref) => ValueRemoteDataSourceImpl(ref.watch(dioProvider)),
);

final valueRepositoryProvider = Provider<ValueRepository>(
  (ref) => ValueRepositoryImpl(ref.watch(valueRemoteDataSourceProvider)),
);

// ── Reads ───────────────────────────────────────────────────────────────

/// Her standing, whole. The standing screen's single call.
final valueStandingProvider = FutureProvider.autoDispose<ValueStanding>((ref) async {
  final result = await ref.watch(valueRepositoryProvider).standing();
  return switch (result) {
    Success(:final data) => data,
    Error(:final failure) => throw failure,
  };
});

/// The compact form, for the badge on her profile and the strip on home.
///
/// Kept alive briefly: it is read by two or three surfaces on the same journey,
/// and re-fetching a four-field object each time she moves between tabs is
/// waste on a connection this feature has to work on.
final valueBadgeProvider = FutureProvider.autoDispose<ValueBadge?>((ref) async {
  final link = ref.keepAlive();
  ref.onDispose(link.close);

  final result = await ref.watch(valueRepositoryProvider).badge();
  return switch (result) {
    Success(:final data) => data,
    // A badge is decoration on somebody else's screen. It disappears rather
    // than taking the screen down with it.
    Error() => null,
  };
});

final valueRulesProvider = FutureProvider.autoDispose<List<ValueRule>>((ref) async {
  final result = await ref.watch(valueRepositoryProvider).rules();
  return switch (result) {
    Success(:final data) => data,
    Error() => const <ValueRule>[],
  };
});

final valueEventsProvider =
    FutureProvider.autoDispose.family<ValueEventPage, String?>((ref, pillar) async {
  final result = await ref.watch(valueRepositoryProvider).events(pillar: pillar);
  return switch (result) {
    Success(:final data) => data,
    Error(:final failure) => throw failure,
  };
});

// ── Writes ──────────────────────────────────────────────────────────────

/// The only mutation in the feature, and it changes no score.
class ValueActions {
  ValueActions(this._ref);

  final Ref _ref;

  Future<Result<ValueGrant>> claim(String benefitKey) async {
    final result =
        await _ref.read(valueRepositoryProvider).claimBenefit(benefitKey);
    if (result is Success<ValueGrant>) {
      // Only the standing screen changes — the score did not move, so the
      // badge does not need refetching. That is the design showing through the
      // cache invalidation.
      _ref.invalidate(valueStandingProvider);
    }
    return result;
  }

  Future<Result<ValueGrant>> use(
    String grantId, {
    required String usedOnType,
    required String usedOnId,
  }) async {
    final result = await _ref.read(valueRepositoryProvider).useGrant(
          grantId,
          usedOnType: usedOnType,
          usedOnId: usedOnId,
        );
    if (result is Success<ValueGrant>) _ref.invalidate(valueStandingProvider);
    return result;
  }
}

final valueActionsProvider = Provider<ValueActions>(ValueActions.new);
