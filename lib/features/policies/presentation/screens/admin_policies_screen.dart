import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ohara/core/design_system/design_system.dart';
import 'package:ohara/core/localization/l10n_extension.dart';
import 'package:ohara/features/admin/presentation/widgets/admin_page_header.dart';
import 'package:ohara/features/policies/domain/entities/admin_policy.dart';
import 'package:ohara/features/policies/presentation/providers/admin_policies_provider.dart';
import 'package:ohara/features/policies/presentation/widgets/policy_editor_sheet.dart';

/// The policy desk — the point of the whole subsystem.
///
/// The client asked to be able to change the terms without updating the app.
/// This screen is that promise made operable: open a draft, edit the Arabic
/// and the English, publish, and every phone shows the new text on its next
/// read. Nothing here ships in a release.
///
/// What it deliberately does *not* offer is editing a published version. The
/// server refuses it, and offering a control the server refuses would only
/// teach an editor that this screen lies. An edit is a new version, and the
/// old one stays readable because somebody's signature points at it.
class AdminPoliciesScreen extends ConsumerWidget {
  const AdminPoliciesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final palette = context.console;
    final documents = ref.watch(adminPoliciesProvider);
    final consent = ref.watch(adminPolicyConsentProvider);

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AdminPageHeader(
            title: l10n.adminPolicies,
            icon: Icons.policy_rounded,
            subtitle: l10n.adminPoliciesSubtitle,
            actions: [
              IconButton(
                tooltip: l10n.refresh,
                onPressed: () {
                  ref.invalidate(adminPoliciesProvider);
                  ref.invalidate(adminPolicyConsentProvider);
                },
                icon: const Icon(Icons.refresh_rounded),
              ),
            ],
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(
              courtGutter(context),
              0,
              courtGutter(context),
              DsSpacing.xxxl,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                consent.maybeWhen(
                  data: (stats) => stats.isEmpty
                      ? const SizedBox.shrink()
                      : _ConsentStrip(
                          stats: stats,
                          // The strip used to head each column with the slug
                          // («customer-terms»); the policy's own title reads
                          // better, and the slug stays on the row below.
                          titles: {
                            for (final document
                                in documents.value ??
                                    const <AdminPolicyDocument>[])
                              document.slug: document.title(
                                Localizations.localeOf(context).languageCode ==
                                        'en'
                                    ? 'en'
                                    : 'ar',
                              ),
                          },
                        ),
                  orElse: () => const SizedBox.shrink(),
                ),
                const SizedBox(height: DsSpacing.lg),
                documents.when(
                  loading: () => const Padding(
                    padding: EdgeInsets.all(DsSpacing.xxl),
                    child: DsLoadingIndicator(),
                  ),
                  error: (error, _) => Text(
                    '$error',
                    style: context.dsText.bodySmall.tint(palette.critical),
                  ),
                  data: (rows) => Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (final document in rows)
                        _PolicyRow(document: document),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// How far the current version of each required policy has landed.
class _ConsentStrip extends StatelessWidget {
  const _ConsentStrip({required this.stats, required this.titles});

  final List<AdminPolicyConsentStat> stats;
  final Map<String, String> titles;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final palette = context.console;

    return Container(
      padding: const EdgeInsets.all(DsSpacing.lg),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(DsRadius.lg),
        border: Border.all(color: palette.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.adminPolicyConsentSummary,
            style: context.dsText.sectionTitle.bold.tint(palette.ink),
          ),
          const SizedBox(height: DsSpacing.md),
          Wrap(
            spacing: DsSpacing.xl,
            runSpacing: DsSpacing.md,
            children: [
              for (final stat in stats)
                SizedBox(
                  width: 220,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        titles[stat.slug] ?? stat.slug,
                        style: context.dsText.labelStrong.tint(palette.ink),
                      ),
                      DsGaps.vXxxs,
                      Text(
                        l10n.adminPolicyAcceptedCurrent(
                          '${stat.acceptedCurrent}',
                        ),
                        style: context.dsText.metricSmall.tint(
                          stat.requiresReacceptance
                              ? palette.caution
                              : palette.positive,
                        ),
                      ),
                      Text(
                        l10n.adminPolicyAcceptedAny(stat.acceptedAnyVersion),
                        style: context.dsText.caption.tint(palette.muted),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PolicyRow extends ConsumerWidget {
  const _PolicyRow({required this.document});

  final AdminPolicyDocument document;

  Future<void> _run(
    BuildContext context,
    WidgetRef ref,
    Future<List<AdminPolicyDocument>> Function() action,
    String success,
  ) async {
    try {
      await action();
      ref.invalidate(adminPoliciesProvider);
      ref.invalidate(adminPolicyConsentProvider);
      if (context.mounted) {
        DsSnackbar.show(
          context,
          message: success,
          type: DsSnackbarType.success,
        );
      }
    } on Object catch (error) {
      if (context.mounted) {
        DsSnackbar.show(context, message: '$error', type: DsSnackbarType.error);
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final palette = context.console;
    final locale = Localizations.localeOf(context).languageCode == 'en'
        ? 'en'
        : 'ar';
    final draft = document.draft;
    final published = document.published;
    final source = ref.read(policyAdminDataSourceProvider);

    return Container(
      margin: const EdgeInsets.only(bottom: DsSpacing.md),
      padding: const EdgeInsets.all(DsSpacing.lg),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(DsRadius.lg),
        border: Border.all(color: palette.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      document.title(locale),
                      style: context.dsText.cardTitle.bold.tint(palette.ink),
                    ),
                    DsGaps.vXxxs,
                    Text(
                      '${document.slug} · ${l10n.adminPolicyVersionsCount(document.versions.length)}',
                      style: context.dsText.caption.tint(palette.muted),
                    ),
                  ],
                ),
              ),
              if (published != null)
                _Chip(
                  label:
                      '${l10n.adminPolicyStatusPublished} · ${l10n.policiesVersionLabel('${published.version}')}',
                  color: palette.positive,
                ),
              if (draft != null) ...[
                const SizedBox(width: DsSpacing.xs),
                _Chip(
                  label:
                      '${l10n.adminPolicyStatusDraft} · ${l10n.policiesVersionLabel('${draft.version}')}',
                  color: palette.caution,
                ),
              ],
            ],
          ),
          const SizedBox(height: DsSpacing.md),

          // The two switches that change who has to sign. They are writes, so
          // the audit interceptor records each one without this screen asking.
          Wrap(
            spacing: DsSpacing.lg,
            runSpacing: DsSpacing.xs,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _Toggle(
                label: l10n.adminPolicyRequiredForConsent,
                value: document.requiredForConsent,
                onChanged: (value) => _run(
                  context,
                  ref,
                  () => source.updateDocument(
                    document.id,
                    requiredForConsent: value,
                  ),
                  l10n.adminPolicySaved,
                ),
              ),
              _Toggle(
                label: l10n.adminPolicyVisible,
                value: document.isActive,
                onChanged: (value) => _run(
                  context,
                  ref,
                  () => source.updateDocument(document.id, isActive: value),
                  l10n.adminPolicySaved,
                ),
              ),
              _AudiencePicker(
                value: document.audience,
                onChanged: (value) => _run(
                  context,
                  ref,
                  () => source.updateDocument(document.id, audience: value),
                  l10n.adminPolicySaved,
                ),
              ),
            ],
          ),

          const SizedBox(height: DsSpacing.md),
          Divider(height: 1, color: palette.line),
          const SizedBox(height: DsSpacing.md),

          if (draft == null)
            Row(
              children: [
                Expanded(
                  child: Text(
                    l10n.adminPolicyNoDraft,
                    style: context.dsText.bodySmall.tint(palette.muted),
                  ),
                ),
                SizedBox(
                  width: 190,
                  child: SecondaryButton(
                    label: l10n.adminPolicyNewDraft,
                    icon: Icons.edit_note_rounded,
                    onPressed: () => _run(
                      context,
                      ref,
                      () => source.createDraft(document.id),
                      l10n.adminPolicyDraftCreated,
                    ),
                  ),
                ),
              ],
            )
          else
            // Explicit widths, because `isExpanded: false` does not shrink a
            // `DsButton`: it centres its content in an `AnimatedContainer`,
            // and a container with an alignment fills whatever width it is
            // offered. Left alone these come out as three stacked full-width
            // bars on a 2400px console. Sized the way `CheckoutScreen` sizes
            // its own action bar, rather than by changing a shared component
            // fifty screens depend on.
            Wrap(
              spacing: DsSpacing.sm,
              runSpacing: DsSpacing.xs,
              children: [
                SizedBox(
                  width: 190,
                  child: SecondaryButton(
                    label: l10n.adminPolicyEditDraft,
                    icon: Icons.edit_outlined,
                    onPressed: () => unawaited(
                      showPolicyEditorSheet(
                        context,
                        document: document,
                        version: draft,
                      ),
                    ),
                  ),
                ),
                SizedBox(
                  width: 160,
                  child: PrimaryButton(
                    label: l10n.adminPolicyPublish,
                    icon: Icons.publish_rounded,
                    onPressed: () => unawaited(
                      showPolicyPublishSheet(
                        context,
                        document: document,
                        draft: draft,
                      ),
                    ),
                  ),
                ),
                SizedBox(
                  width: 170,
                  child: GhostButton(
                    label: l10n.adminPolicyDiscardDraft,
                    onPressed: () async {
                      final confirmed = await DsDialog.confirm(
                        context,
                        title: l10n.adminPolicyDiscardDraft,
                        message: l10n.adminPolicyDiscardConfirm,
                        destructive: true,
                      );
                      if (!confirmed || !context.mounted) return;
                      await _run(
                        context,
                        ref,
                        () => source.discard(draft.id),
                        l10n.adminPolicyDraftDiscarded,
                      );
                    },
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: DsSpacing.sm,
        vertical: 3,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(DsRadius.sm),
      ),
      child: Text(label, style: context.dsText.micro.tint(color)),
    );
  }
}

class _Toggle extends StatelessWidget {
  const _Toggle({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final palette = context.console;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Switch(
          value: value,
          onChanged: onChanged,
          activeThumbColor: palette.primary,
        ),
        const SizedBox(width: DsSpacing.xxs),
        Text(label, style: context.dsText.bodySmall.tint(palette.ink)),
      ],
    );
  }
}

/// Who has to sign this document. Three values, and changing one moves who
/// meets the consent gate — so it is a dropdown with the meaning spelled out
/// rather than an enum name.
class _AudiencePicker extends StatelessWidget {
  const _AudiencePicker({required this.value, required this.onChanged});

  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final palette = context.console;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '${l10n.adminPolicyAudience}:',
          style: context.dsText.bodySmall.tint(palette.muted),
        ),
        const SizedBox(width: DsSpacing.xs),
        DropdownButton<String>(
          value: value,
          underline: const SizedBox.shrink(),
          style: context.dsText.bodySmall.tint(palette.ink),
          items: [
            DropdownMenuItem(
              value: 'EVERYONE',
              child: Text(l10n.adminPolicyAudienceEveryone),
            ),
            DropdownMenuItem(
              value: 'CUSTOMER',
              child: Text(l10n.adminPolicyAudienceCustomer),
            ),
            DropdownMenuItem(
              value: 'SELLER',
              child: Text(l10n.adminPolicyAudienceSeller),
            ),
          ],
          onChanged: (next) {
            if (next != null && next != value) onChanged(next);
          },
        ),
      ],
    );
  }
}
