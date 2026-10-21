import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:reem/core/design_system/design_system.dart';
import 'package:reem/core/localization/l10n_extension.dart';
import 'package:reem/features/auth/presentation/providers/auth_provider.dart';
import 'package:reem/features/policies/domain/entities/policy_document.dart';
import 'package:reem/features/policies/presentation/providers/policies_provider.dart';
import 'package:reem/features/policies/presentation/providers/policy_consent_provider.dart';
import 'package:reem/features/policies/presentation/widgets/policy_pieces.dart';

/// The gate: she cannot go further until she has signed what is outstanding.
///
/// `AppChrome` renders this *instead of* the app's navigator rather than
/// pushing it as a route, so there is no back gesture, no deep link and no
/// notification tap that can get behind it. That is deliberate — a consent
/// screen with a way around it produces a consent record nobody can rely on.
///
/// Two things keep it from being hostile. Every document is readable from
/// here, full text, before she agrees to anything. And she can sign out, which
/// is the honest alternative to agreeing: the only thing this screen refuses
/// is *using the platform* without a consent on file.
class PolicyConsentScreen extends ConsumerStatefulWidget {
  const PolicyConsentScreen({super.key, required this.pending});

  final List<PolicySummary> pending;

  @override
  ConsumerState<PolicyConsentScreen> createState() =>
      _PolicyConsentScreenState();
}

class _PolicyConsentScreenState extends ConsumerState<PolicyConsentScreen> {
  bool _agreed = false;
  bool _submitting = false;
  String? _error;

  Future<void> _submit() async {
    final locale = policyLocaleOf(context);
    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      await ref
          .read(policiesDataSourceProvider)
          .accept(
            versionIds: widget.pending
                .map((policy) => policy.versionId)
                .toList(growable: false),
            locale: locale,
          );
      if (!mounted) return;
      // Re-ask rather than trusting the response we just got: the gate's whole
      // job is to reflect what the server believes, and one authority for that
      // is better than two that can disagree.
      ref.invalidate(pendingPoliciesProvider(locale));
      ref.invalidate(policyCatalogueProvider(locale));
      ref.invalidate(policyReceiptsProvider(locale));
    } on Object {
      if (!mounted) return;
      setState(() => _error = context.l10n.policiesConsentFailed);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = context.dsColors;

    // "We have updated these" is only true when she had signed something
    // before. For an account that predates the policy centre — or one created
    // while the documents were not yet published — it would be a lie, and the
    // first screen a woman meets is a bad place to start lying to her.
    final isUpdate = widget.pending.any((policy) => policy.acceptance != null);

    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                  DsSpacing.lg,
                  DsSpacing.xl,
                  DsSpacing.lg,
                  DsSpacing.lg,
                ),
                children: [
                  Icon(
                    Icons.verified_user_outlined,
                    size: 44,
                    color: colors.primary,
                  ),
                  const SizedBox(height: DsSpacing.md),
                  DsGradientText(
                    l10n.policiesConsentTitle,
                    style: context.dsText.pageTitle.bold,
                  ),
                  const SizedBox(height: DsSpacing.sm),
                  Text(
                    isUpdate
                        ? l10n.policiesConsentIntroUpdated
                        : l10n.policiesConsentIntroNew,
                    style: context.dsText.body.copyWith(
                      height: 1.6,
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: DsSpacing.xl),
                  for (final policy in widget.pending)
                    _ConsentDocument(policy: policy),
                  if (_error != null) ...[
                    const SizedBox(height: DsSpacing.md),
                    DsInlineError(message: _error!),
                  ],
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(
                DsSpacing.lg,
                DsSpacing.sm,
                DsSpacing.lg,
                DsSpacing.lg,
              ),
              decoration: BoxDecoration(
                color: colors.surface,
                border: Border(top: BorderSide(color: colors.border)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CheckboxListTile(
                    value: _agreed,
                    onChanged: _submitting
                        ? null
                        : (value) => setState(() => _agreed = value ?? false),
                    controlAffinity: ListTileControlAffinity.leading,
                    contentPadding: EdgeInsets.zero,
                    activeColor: colors.primary,
                    title: Text(
                      l10n.policiesConsentAgree,
                      style: context.dsText.body,
                    ),
                  ),
                  const SizedBox(height: DsSpacing.xs),
                  PrimaryButton(
                    label: l10n.policiesConsentContinue,
                    onPressed: _agreed && !_submitting ? _submit : null,
                    isLoading: _submitting,
                  ),
                  const SizedBox(height: DsSpacing.xxs),
                  // No navigation afterwards, and none is needed: signing out
                  // empties `pendingPoliciesProvider`, `AppChrome` puts the
                  // router back, and the auth guard sends an account-less
                  // visitor where she belongs. Calling `context.go` from here
                  // would reach for a GoRouter this screen has replaced.
                  TextButton(
                    onPressed: _submitting
                        ? null
                        : () => unawaited(
                            ref.read(authNotifierProvider.notifier).logout(),
                          ),
                    child: Text(
                      l10n.policiesConsentSignOut,
                      style: context.dsText.caption,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One outstanding document, with the whole text one tap away.
class _ConsentDocument extends StatelessWidget {
  const _ConsentDocument({required this.policy});

  final PolicySummary policy;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = context.dsColors;

    return Padding(
      padding: const EdgeInsets.only(bottom: DsSpacing.sm),
      child: SurfaceCard(
        padding: const EdgeInsets.all(DsSpacing.md),
        // The gate's own navigator, which `AppChrome` mounts for exactly this.
        // `context.push` would reach GoRouter — the stack this screen has
        // replaced — so the document would open behind the gate and the tap
        // would appear to do nothing.
        onTap: () => unawaited(
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => _ConsentReader(policy: policy),
            ),
          ),
        ),
        child: Row(
          children: [
            Icon(policyIcon(policy), color: colors.primary, size: 22),
            const SizedBox(width: DsSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(policy.title, style: context.dsText.cardTitle.semibold),
                  const SizedBox(height: 2),
                  Text(
                    l10n.policiesConsentTapToRead,
                    style: context.dsText.caption.tint(colors.primary),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              size: 20,
              color: colors.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }
}

/// The full text, inside the gate.
///
/// A page of its own rather than a sheet: these documents are thousands of
/// words, and a half-height sheet is how a platform makes the terms
/// technically available and practically unread.
class _ConsentReader extends ConsumerWidget {
  const _ConsentReader({required this.policy});

  final PolicySummary policy;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = policyLocaleOf(context);
    final detail = ref.watch(
      policyDetailProvider((slug: policy.slug, locale: locale)),
    );
    final colors = context.dsColors;

    return Scaffold(
      backgroundColor: colors.background,
      appBar: ReemAppBar(title: policy.title),
      body: detail.when(
        loading: () => const Center(child: DsLoadingIndicator()),
        error: (error, _) => Padding(
          padding: const EdgeInsets.all(DsSpacing.lg),
          child: DsErrorState(
            message: '$error',
            onRetry: () => ref.invalidate(
              policyDetailProvider((slug: policy.slug, locale: locale)),
            ),
          ),
        ),
        data: (loaded) => ListView(
          padding: const EdgeInsets.fromLTRB(
            DsSpacing.lg,
            DsSpacing.md,
            DsSpacing.lg,
            DsSpacing.xxxl,
          ),
          children: [DsRichText(text: loaded.body)],
        ),
      ),
    );
  }
}
