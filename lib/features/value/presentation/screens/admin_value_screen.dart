import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:reem/core/design_system/design_system.dart';
import 'package:reem/core/localization/l10n_extension.dart';
import 'package:reem/features/admin/presentation/widgets/admin_page_header.dart';
import 'package:reem/features/value/domain/entities/value_admin.dart';
import 'package:reem/features/value/presentation/providers/value_admin_providers.dart';
import 'package:reem/features/value/presentation/widgets/value_policy_editor.dart';
import 'package:reem/l10n/app_localizations.dart';

/// Running Reem Value.
///
/// The order of this screen is the order an operator should think in, and it is
/// deliberate:
///
///  1. **Can money buy the top?** The guarantee, first and unmissable. Every
///     other number here is only meaningful if this one holds.
///  2. **Where does everybody stand?** A ladder whose top rung holds nobody is
///     decoration; one holding a third of the population is not a standing.
///  3. **What does it cost?** Exposure, with unbudgeted spend called out.
///  4. **Retune it.** Draft, simulate, then activate — never a single save.
///  5. **Who is worth a look?** A queue for a person, not an automatic penalty.
class AdminValueScreen extends ConsumerWidget {
  const AdminValueScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final distribution = ref.watch(valueDistributionProvider);

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AdminPageHeader(
            // The feature's name, which is a name in both languages: the
            // Arabic console says «ريم فاليو» aloud and writes it this way.
            // l10n-ignore: a product name, not copy.
            title: 'Reem Value',
            subtitle: context.l10n.valueAdminSubtitle,
            actions: [
              IconButton(
                tooltip: context.l10n.valueAdminRefresh,
                onPressed: () {
                  ref.invalidate(valueDistributionProvider);
                  ref.invalidate(valueCostProvider);
                  ref.invalidate(valueSuspectsProvider);
                },
                icon: const Icon(Icons.refresh_rounded),
              ),
              IconButton(
                tooltip: context.l10n.valueAdminSweepNow,
                onPressed: () => _sweep(context, ref),
                icon: const Icon(Icons.cyclone_rounded),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              DsSpacing.xl,
              0,
              DsSpacing.xl,
              DsSpacing.xxl,
            ),
            child: distribution.when(
              loading: () => const Padding(
                padding: EdgeInsets.all(DsSpacing.xxl),
                child: Center(child: DsLoadingIndicator()),
              ),
              error: (_, _) => DsErrorState(
                message: context.l10n.valueAdminDistributionFailed,
                onRetry: () => ref.invalidate(valueDistributionProvider),
              ),
              data: (data) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _GuaranteeBanner(guarantee: data.guarantee),
                  const SizedBox(height: DsSpacing.lg),
                  _DistributionCard(distribution: data),
                  const SizedBox(height: DsSpacing.lg),
                  const _CostCard(),
                  const SizedBox(height: DsSpacing.lg),
                  const ValuePolicySection(),
                  const SizedBox(height: DsSpacing.lg),
                  const _SuspectsCard(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _sweep(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    final l10n = context.l10n;
    try {
      final counts = await ref.read(valueAdminActionsProvider).sweep();
      DsSnackbar.on(
        messenger,
        message: l10n.valueAdminSweepDone(
          (counts['recomputed'] as num? ?? 0).toInt(),
        ),
        type: DsSnackbarType.success,
      );
    } catch (_) {
      DsSnackbar.on(
        messenger,
        message: l10n.valueAdminSweepFailed,
        type: DsSnackbarType.error,
      );
    }
  }
}

/// The programme's promise, checked.
///
/// Rendered as a banner rather than a row in a table because it is not a
/// statistic — it is a pass/fail on the one claim Reem Value makes about
/// itself. When it fails, the screen should be uncomfortable to look at.
class _GuaranteeBanner extends StatelessWidget {
  const _GuaranteeBanner({required this.guarantee});

  final ValueGuarantee guarantee;

  @override
  Widget build(BuildContext context) {
    final console = context.console;
    final holds = guarantee.holds;
    final accent = holds ? console.positive : console.critical;

    return Container(
      padding: const EdgeInsets.all(DsSpacing.lg),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(DsRadius.card),
        border: Border.all(color: accent.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            holds ? Icons.verified_rounded : Icons.warning_amber_rounded,
            color: accent,
          ),
          const SizedBox(width: DsSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  holds
                      ? context.l10n.valueAdminGuaranteeHolds
                      : context.l10n.valueAdminGuaranteeBroken,
                  style: context.dsText.cardTitle.tint(accent),
                ),
                DsGaps.vXxs,
                Text(
                  [
                    context.l10n.valueAdminSpendingReach(
                      guarantee.spendingCeiling,
                    ),
                    if (guarantee.highestRungReachableBySpending
                        case final rung?)
                      context.l10n.valueAdminSpendingRung(
                        _rungName(context.l10n, rung),
                      ),
                    if (guarantee.topRung case final top?)
                      context.l10n.valueAdminTopRung(
                        _rungName(context.l10n, top),
                      )
                    else
                      '.',
                  ].join(),
                  style: context.dsText.body,
                ),
                if (!holds) ...[
                  const SizedBox(height: DsSpacing.xs),
                  Text(
                    context.l10n.valueAdminGuaranteeFix,
                    style: context.dsText.caption.tint(accent),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DistributionCard extends StatelessWidget {
  const _DistributionCard({required this.distribution});

  final ValueDistribution distribution;

  @override
  Widget build(BuildContext context) {
    final console = context.console;
    final busiest = distribution.tiers.fold<int>(
      1,
      (max, tier) => tier.count > max ? tier.count : max,
    );

    return _Panel(
      title: context.l10n.valueAdminDistributionTitle,
      subtitle: context.l10n.valueAdminDistributionSubtitle(
        distribution.total,
        distribution.unranked,
      ),
      child: Column(
        children: [
          for (final tier in distribution.tiers)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: DsSpacing.xs),
              child: Row(
                children: [
                  SizedBox(
                    width: 120,
                    child: Text(tier.name, style: context.dsText.labelStrong),
                  ),
                  SizedBox(
                    width: 56,
                    child: Text(
                      '≥${tier.minScore}',
                      style: context.dsText.micro.tint(console.muted),
                    ),
                  ),
                  Expanded(
                    child: DsMeter(
                      value: tier.count / busiest,
                      weight: DsMeterWeight.bold,
                      color: console.primary,
                      track: console.surfaceAlt,
                    ),
                  ),
                  const SizedBox(width: DsSpacing.sm),
                  SizedBox(
                    width: 110,
                    child: Text(
                      '${tier.count} · ${tier.sharePercent.toStringAsFixed(1)}%',
                      textAlign: TextAlign.end,
                      style: context.dsText.numeric,
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

class _CostCard extends ConsumerWidget {
  const _CostCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final console = context.console;
    final costAsync = ref.watch(valueCostProvider);

    return _Panel(
      title: context.l10n.valueAdminCostTitle,
      subtitle: context.l10n.valueAdminCostSubtitle,
      child: costAsync.when(
        loading: () => const Padding(
          padding: EdgeInsets.all(DsSpacing.lg),
          child: Center(child: DsLoadingIndicator()),
        ),
        error: (_, _) => Text(context.l10n.valueAdminCostFailed),
        data: (cost) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (cost.unboundedCount > 0)
              Container(
                margin: const EdgeInsets.only(bottom: DsSpacing.sm),
                padding: const EdgeInsets.all(DsSpacing.sm),
                decoration: BoxDecoration(
                  color: console.caution.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(DsRadius.sm),
                ),
                child: Text(
                  // The one state this report exists to surface: a benefit that
                  // spends money with no ceiling on how much.
                  context.l10n.valueAdminUnbounded(cost.unboundedCount),
                  style: context.dsText.caption.tint(console.caution),
                ),
              ),
            Row(
              children: [
                _Metric(
                  label: context.l10n.valueAdminSpent,
                  value: cost.issuedTotal?.format() ?? '—',
                ),
                _Metric(
                  label: context.l10n.valueAdminMaxCommitment,
                  value: cost.ceilingTotal?.format() ?? '—',
                ),
              ],
            ),
            const SizedBox(height: DsSpacing.sm),
            for (final row in cost.benefits)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(row.title, style: context.dsText.body),
                    ),
                    SizedBox(
                      width: 90,
                      child: Text(
                        '${row.granted}${row.budget != null ? '/${row.budget}' : ''}',
                        textAlign: TextAlign.end,
                        style: context.dsText.numeric,
                      ),
                    ),
                    SizedBox(
                      width: 130,
                      child: Text(
                        row.issued?.format() ?? '—',
                        textAlign: TextAlign.end,
                        style: context.dsText.numeric.tint(
                          row.unbounded ? console.caution : console.muted,
                        ),
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

class _SuspectsCard extends ConsumerWidget {
  const _SuspectsCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final console = context.console;
    final suspectsAsync = ref.watch(valueSuspectsProvider);

    return _Panel(
      title: context.l10n.valueAdminSuspectsTitle,
      // Said plainly, because the word matters: these are shapes, not verdicts,
      // and every one of them has an innocent explanation.
      subtitle: context.l10n.valueAdminSuspectsSubtitle,
      child: suspectsAsync.when(
        loading: () => const Padding(
          padding: EdgeInsets.all(DsSpacing.lg),
          child: Center(child: DsLoadingIndicator()),
        ),
        error: (_, _) => Text(context.l10n.valueAdminSuspectsFailed),
        data: (suspects) => suspects.isEmpty
            ? Text(
                context.l10n.valueAdminSuspectsNone,
                style: context.dsText.body.tint(console.muted),
              )
            : Column(
                children: [
                  for (final suspect in suspects)
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: DsSpacing.xs,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${suspect.tierKey ?? '—'} · ${suspect.score}',
                                  style: context.dsText.labelStrong,
                                ),
                                Text(
                                  suspect.reasons
                                      .map((r) => _reasonLabel(context, r))
                                      .join(' · '),
                                  style: context.dsText.caption,
                                ),
                                Text(
                                  context.l10n.valueAdminConcentration(
                                    (suspect.concentration * 100).round(),
                                    suspect.distinctDays,
                                  ),
                                  style: context.dsText.micro.tint(
                                    console.muted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          TextButton(
                            onPressed: () => _freeze(context, ref, suspect),
                            child: Text(context.l10n.valueAdminFreezeAction),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
      ),
    );
  }

  static String _reasonLabel(BuildContext context, String reason) =>
      switch (reason) {
        'single_pillar' => context.l10n.valueAdminReasonSinglePillar,
        'burst' => context.l10n.valueAdminReasonBurst,
        _ => reason,
      };

  Future<void> _freeze(
    BuildContext context,
    WidgetRef ref,
    ValueSuspect suspect,
  ) async {
    final reason = await DsDialog.prompt(
      context,
      title: context.l10n.valueAdminFreezeTitle,
      message: context.l10n.valueAdminFreezeBody,
      hintText: context.l10n.valueAdminFreezeReason,
      confirmLabel: context.l10n.valueAdminFreezeConfirm,
      cancelLabel: context.l10n.valueCancel,
      maxLines: 3,
      maxLength: 200,
    );

    if (reason == null || reason.isEmpty || !context.mounted) {
      return;
    }
    await ref.read(valueAdminActionsProvider).freeze(suspect.userId, reason);
  }
}

// ── Shared chrome ───────────────────────────────────────────────────────

class _Panel extends StatelessWidget {
  const _Panel({required this.title, required this.child, this.subtitle});

  final String title;
  final String? subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final console = context.console;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(DsSpacing.lg),
      decoration: BoxDecoration(
        color: console.surface,
        borderRadius: BorderRadius.circular(DsRadius.card),
        border: Border.all(color: console.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: context.dsText.sectionTitle),
          if (subtitle != null) ...[
            DsGaps.vXxxs,
            Text(subtitle!, style: context.dsText.sectionSubtitle),
          ],
          const SizedBox(height: DsSpacing.md),
          child,
        ],
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value, style: context.dsText.metricSmall),
          Text(label, style: context.dsText.metricLabel),
        ],
      ),
    );
  }
}

/// A standing rung in her language. The guarantee line quoted the rung's code
/// — «known», «circle» — inside an Arabic sentence.
String _rungName(AppLocalizations l10n, String key) => switch (key) {
  'new' => l10n.valueRungNew,
  'known' => l10n.valueRungKnown,
  'trusted' => l10n.valueRungTrusted,
  'insider' => l10n.valueRungInsider,
  'circle' => l10n.valueRungCircle,
  _ => key,
};
