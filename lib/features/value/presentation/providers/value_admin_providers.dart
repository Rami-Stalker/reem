import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:reem/core/presentation/providers/core_providers.dart';
import 'package:reem/features/value/data/datasources/value_admin_remote_datasource.dart';
import 'package:reem/features/value/domain/entities/value_admin.dart';

final valueAdminDataSourceProvider = Provider<ValueAdminRemoteDataSource>(
  (ref) => ValueAdminRemoteDataSourceImpl(ref.watch(dioProvider)),
);

// ── Reads ───────────────────────────────────────────────────────────────

final valueDistributionProvider =
    FutureProvider.autoDispose<ValueDistribution>((ref) async {
  return ref.watch(valueAdminDataSourceProvider).distribution();
});

final valueCostProvider = FutureProvider.autoDispose<ValueCostReport>((ref) async {
  return ref.watch(valueAdminDataSourceProvider).cost();
});

final valuePoliciesProvider =
    FutureProvider.autoDispose<List<ValuePolicyVersion>>((ref) async {
  return ref.watch(valueAdminDataSourceProvider).policies();
});

final valueSuspectsProvider =
    FutureProvider.autoDispose<List<ValueSuspect>>((ref) async {
  return ref.watch(valueAdminDataSourceProvider).suspects();
});

/// The simulation for a draft, once one has been run.
///
/// Held in state rather than derived, because a simulation is an *act* an
/// administrator performed against a specific version — not something that
/// should silently refresh underneath her while she is reading it and deciding
/// whether to activate.
final valueSimulationProvider =
    StateProvider.autoDispose<Map<String, ValueSimulation>>((ref) => {});

// ── Writes ──────────────────────────────────────────────────────────────

class ValueAdminActions {
  ValueAdminActions(this._ref);

  final Ref _ref;

  ValueAdminRemoteDataSource get _api => _ref.read(valueAdminDataSourceProvider);

  Future<ValuePolicyVersion> draft(ValuePolicyDraft draft) async {
    final policy = await _api.draftPolicy(draft);
    _ref.invalidate(valuePoliciesProvider);
    return policy;
  }

  Future<ValueSimulation> simulate(String policyId) async {
    final result = await _api.simulate(policyId);
    _ref.read(valueSimulationProvider.notifier).update(
          (state) => {...state, policyId: result},
        );
    return result;
  }

  /// Activating rescores the whole population on the server, so everything on
  /// this screen is stale afterwards — including the guarantee, which is the
  /// one figure that must never be read from before a change.
  Future<void> activate(String policyId) async {
    await _api.activate(policyId);
    _ref.invalidate(valuePoliciesProvider);
    _ref.invalidate(valueDistributionProvider);
    _ref.invalidate(valueCostProvider);
    _ref.invalidate(valueSuspectsProvider);
  }

  Future<void> freeze(String userId, String reason) async {
    await _api.freeze(userId, reason);
    _ref.invalidate(valueSuspectsProvider);
    _ref.invalidate(valueDistributionProvider);
  }

  Future<void> unfreeze(String userId) async {
    await _api.unfreeze(userId);
    _ref.invalidate(valueSuspectsProvider);
    _ref.invalidate(valueDistributionProvider);
  }

  Future<Map<String, dynamic>> sweep() async {
    final counts = await _api.sweep();
    _ref.invalidate(valueDistributionProvider);
    _ref.invalidate(valueSuspectsProvider);
    return counts;
  }

  Future<int> recompute() async {
    final done = await _api.recomputeAll();
    _ref.invalidate(valueDistributionProvider);
    return done;
  }
}

final valueAdminActionsProvider =
    Provider<ValueAdminActions>(ValueAdminActions.new);
