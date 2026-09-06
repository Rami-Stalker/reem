import 'package:reem/core/network/api_endpoints.dart';
import 'package:reem/core/network/base_remote_datasource.dart';
import 'package:reem/features/value/data/models/value_admin_models.dart';
import 'package:reem/features/value/domain/entities/value_admin.dart';

abstract interface class ValueAdminRemoteDataSource {
  Future<ValueDistribution> distribution();

  Future<ValueCostReport> cost();

  Future<List<ValuePolicyVersion>> policies();

  Future<ValuePolicyVersion> draftPolicy(ValuePolicyDraft draft);

  Future<ValueSimulation> simulate(String policyId, {int? sample});

  Future<ValuePolicyVersion> activate(String policyId);

  Future<List<ValueSuspect>> suspects();

  Future<void> freeze(String userId, String reason);

  Future<void> unfreeze(String userId);

  Future<Map<String, dynamic>> sweep();

  Future<int> recomputeAll();
}

final class ValueAdminRemoteDataSourceImpl extends BaseRemoteDataSource
    implements ValueAdminRemoteDataSource {
  const ValueAdminRemoteDataSourceImpl(super.dio);

  @override
  Future<ValueDistribution> distribution() async =>
      distributionFromJson(await getJson(ApiEndpoints.adminValueDistribution));

  @override
  Future<ValueCostReport> cost() async =>
      costFromJson(await getJson(ApiEndpoints.adminValueCost));

  @override
  Future<List<ValuePolicyVersion>> policies() async =>
      policiesFromJson(await getList(ApiEndpoints.adminValuePolicies));

  @override
  Future<ValuePolicyVersion> draftPolicy(ValuePolicyDraft draft) async =>
      policyFromJson(
        await postJson(ApiEndpoints.adminValuePolicies, body: draft.toJson()),
      );

  @override
  Future<ValueSimulation> simulate(String policyId, {int? sample}) async =>
      simulationFromJson(
        await postJson(
          ApiEndpoints.adminValuePolicySimulate(policyId),
          body: {'sample': ?sample},
        ),
      );

  @override
  Future<ValuePolicyVersion> activate(String policyId) async {
    // The response carries the recompute count and the re-checked guarantee
    // beside the policy; only the policy is decoded here, and the caller
    // refetches the distribution — which is where the new guarantee belongs on
    // screen anyway.
    final json = await postJson(ApiEndpoints.adminValuePolicyActivate(policyId));
    final policy = json['policy'];
    return policyFromJson(
      policy is Map ? Map<String, dynamic>.from(policy) : json,
    );
  }

  @override
  Future<List<ValueSuspect>> suspects() async =>
      suspectsFromJson(await getList(ApiEndpoints.adminValueSuspects));

  @override
  Future<void> freeze(String userId, String reason) async {
    await postJson(ApiEndpoints.adminValueFreeze(userId), body: {'reason': reason});
  }

  @override
  Future<void> unfreeze(String userId) async {
    await postJson(ApiEndpoints.adminValueUnfreeze(userId));
  }

  @override
  Future<Map<String, dynamic>> sweep() =>
      postJson(ApiEndpoints.adminValueSweep);

  @override
  Future<int> recomputeAll() async {
    final json = await postJson(ApiEndpoints.adminValueRecompute);
    final count = json['recomputed'];
    return count is num ? count.toInt() : 0;
  }
}
