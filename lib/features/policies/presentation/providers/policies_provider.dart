import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ohara/core/presentation/providers/core_providers.dart';
import 'package:ohara/features/policies/data/datasources/policies_remote_datasource.dart';
import 'package:ohara/features/policies/domain/entities/policy_document.dart';

final policiesDataSourceProvider = Provider<PoliciesRemoteDataSource>(
  (ref) => PoliciesRemoteDataSource(ref.watch(dioProvider)),
);

/// The language to ask the server for.
///
/// Read from the widget tree rather than from a provider of its own, and every
/// policy provider is keyed by it. That is what makes switching the app's
/// language re-fetch the text: a different family key is a different provider,
/// so the Arabic and English documents never share a cache entry and the
/// screen cannot paint one while claiming the other.
String policyLocaleOf(BuildContext context) =>
    Localizations.localeOf(context).languageCode == 'en' ? 'en' : 'ar';

/// Every published policy, for the policy centre.
final policyCatalogueProvider = FutureProvider.autoDispose
    .family<List<PolicySummary>, String>(
      (ref, locale) =>
          ref.watch(policiesDataSourceProvider).catalogue(locale: locale),
    );

/// One policy, with its text.
final policyDetailProvider = FutureProvider.autoDispose
    .family<PolicyDetail, ({String slug, String locale})>(
      (ref, args) => ref
          .watch(policiesDataSourceProvider)
          .document(args.slug, locale: args.locale),
    );

/// One retired or current issue, opened from a receipt.
final policyVersionProvider = FutureProvider.autoDispose
    .family<PolicyDetail, ({String id, String locale})>(
      (ref, args) => ref
          .watch(policiesDataSourceProvider)
          .version(args.id, locale: args.locale),
    );

/// What a new account of this kind must sign, before the account exists.
///
/// `role` is `buyer` or `seller`. Not auto-disposed on a timer but on the
/// screen: the registration form watches it, and leaving the form releases it.
final requiredPoliciesProvider = FutureProvider.autoDispose
    .family<List<PolicySummary>, ({String role, String locale})>(
      (ref, args) => ref
          .watch(policiesDataSourceProvider)
          .requiredFor(role: args.role, locale: args.locale),
    );

/// Her receipts — which policy, which version, which day.
final policyReceiptsProvider = FutureProvider.autoDispose
    .family<List<PolicyReceipt>, String>(
      (ref, locale) =>
          ref.watch(policiesDataSourceProvider).acceptances(locale: locale),
    );
