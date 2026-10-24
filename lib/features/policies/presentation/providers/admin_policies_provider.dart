import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ohara/core/presentation/providers/core_providers.dart';
import 'package:ohara/features/policies/data/datasources/policy_admin_remote_datasource.dart';
import 'package:ohara/features/policies/domain/entities/admin_policy.dart';

final policyAdminDataSourceProvider = Provider<PolicyAdminRemoteDataSource>(
  (ref) => PolicyAdminRemoteDataSource(ref.watch(dioProvider)),
);

/// Every document, every version, every translation — the console's whole
/// working set in one request.
///
/// One provider rather than one per document because the write endpoints all
/// answer with the same shape: publishing archives a sibling version, so the
/// screen has to re-render more than the row that was posted, and the simplest
/// correct thing is to replace the lot.
final adminPoliciesProvider =
    FutureProvider.autoDispose<List<AdminPolicyDocument>>(
      (ref) => ref.watch(policyAdminDataSourceProvider).documents(),
    );

/// How many accounts have signed each required policy, and how many are on the
/// current version of it.
final adminPolicyConsentProvider =
    FutureProvider.autoDispose<List<AdminPolicyConsentStat>>(
      (ref) => ref.watch(policyAdminDataSourceProvider).consentSummary(),
    );
