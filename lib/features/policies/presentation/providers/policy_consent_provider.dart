import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:reem/features/auth/presentation/providers/auth_provider.dart';
import 'package:reem/features/policies/domain/entities/policy_document.dart';
import 'package:reem/features/policies/presentation/providers/policies_provider.dart';

/// What this account still owes a signature on.
///
/// Watches the session on purpose: signing in, signing out and switching
/// accounts all have to re-ask, and a gate that answered from the previous
/// account would either block the wrong woman or let the right one through.
///
/// A guest is never asked. She has no account to attach a consent to, and the
/// terms are put to her at registration, which is the moment she is actually
/// entering into them.
///
/// Errors resolve to an empty list rather than to a failure state, and that is
/// the important decision in this file: this provider gates the entire app, so
/// a five-second network blip must not be able to lock a woman out of Reem.
/// The gate fails open, the next launch asks again, and the honest cost is
/// that a signature can be a few hours late.
final pendingPoliciesProvider = FutureProvider.autoDispose
    .family<List<PolicySummary>, String>((ref, locale) async {
      final auth = ref.watch(authNotifierProvider);
      if (!auth.isInitialized || !auth.isAuthenticated) {
        return const <PolicySummary>[];
      }

      try {
        return await ref
            .watch(policiesDataSourceProvider)
            .pending(locale: locale);
      } on Object {
        return const <PolicySummary>[];
      }
    });
