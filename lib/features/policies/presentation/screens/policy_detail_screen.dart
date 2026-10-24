import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:ohara/core/design_system/design_system.dart';
import 'package:ohara/core/localization/l10n_extension.dart';
import 'package:ohara/core/router/route_paths.dart';
import 'package:ohara/features/policies/domain/entities/policy_document.dart';
import 'package:ohara/features/policies/presentation/providers/policies_provider.dart';
import 'package:ohara/features/policies/presentation/widgets/policy_pieces.dart';

/// One policy, read.
///
/// Two modes, and the difference matters. Without `versionId` it shows what is
/// published today. With one — which is how a receipt opens it — it shows that
/// exact issue, banner and all, including an archived text the policy centre
/// no longer lists. A receipt that rendered today's terms would be evidence of
/// nothing.
class PolicyDetailScreen extends ConsumerWidget {
  const PolicyDetailScreen({super.key, required this.slug, this.versionId});

  final String slug;
  final String? versionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final locale = policyLocaleOf(context);
    final pinned = versionId;

    final detail = pinned == null
        ? ref.watch(policyDetailProvider((slug: slug, locale: locale)))
        : ref.watch(policyVersionProvider((id: pinned, locale: locale)));

    return OharaScrollPage(
      slivers: [
        PremiumAppBar(
          title: switch (detail) {
            AsyncData(:final value) => value.summary.title,
            _ => l10n.policiesTitle,
          },
          showBack: true,
          centerTitle: false,
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(
            DsSpacing.lg,
            DsSpacing.sm,
            DsSpacing.lg,
            DsSpacing.xxxl,
          ),
          sliver: detail.when(
            loading: () => const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.all(DsSpacing.xxxl),
                child: Center(child: DsLoadingIndicator()),
              ),
            ),
            error: (error, _) => SliverToBoxAdapter(
              child: DsErrorState(
                message: '$error',
                onRetry: () => pinned == null
                    ? ref.invalidate(
                        policyDetailProvider((slug: slug, locale: locale)),
                      )
                    : ref.invalidate(
                        policyVersionProvider((id: pinned, locale: locale)),
                      ),
              ),
            ),
            data: (policy) => SliverList(
              delegate: SliverChildListDelegate([
                _Masthead(policy: policy, isPinnedVersion: pinned != null),
                const SizedBox(height: DsSpacing.lg),
                DsRichText(text: policy.body),
                if (policy.history.length > 1) ...[
                  const SizedBox(height: DsSpacing.xxl),
                  _History(slug: slug, history: policy.history),
                ],
              ]),
            ),
          ),
        ),
      ],
    );
  }
}

class _Masthead extends StatelessWidget {
  const _Masthead({required this.policy, required this.isPinnedVersion});

  final PolicyDetail policy;
  final bool isPinnedVersion;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = context.dsColors;
    final summary = policy.summary;
    final acceptance = summary.acceptance;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (summary.summary.isNotEmpty)
          Text(
            summary.summary,
            style: context.dsText.bodyLarge.copyWith(
              height: 1.6,
              color: colors.onSurfaceVariant,
            ),
          ),
        const SizedBox(height: DsSpacing.md),
        Wrap(
          spacing: DsSpacing.sm,
          runSpacing: DsSpacing.xs,
          children: [
            _Pill(
              icon: Icons.tag_rounded,
              label: l10n.policiesVersionLabel('${summary.version}'),
            ),
            if (summary.effectiveAt != null)
              _Pill(
                icon: Icons.event_outlined,
                label: l10n.policiesEffectiveFrom(
                  formatPolicyDate(l10n, summary.effectiveAt!),
                ),
              ),
            if (acceptance != null && acceptance.acceptedAt != null)
              _Pill(
                icon: Icons.check_circle_rounded,
                tint: colors.success,
                label: l10n.policiesAcceptedOn(
                  formatPolicyDate(l10n, acceptance.acceptedAt!),
                ),
              ),
          ],
        ),
        // The banner that stops a woman reading an old text and believing it
        // is the live one. Only ever shown when the version was asked for by
        // id, which is the only way to arrive at a retired issue.
        if (isPinnedVersion) ...[
          const SizedBox(height: DsSpacing.md),
          Container(
            padding: const EdgeInsets.all(DsSpacing.md),
            decoration: BoxDecoration(
              color: colors.warning.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(DsRadius.md),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.history_rounded, size: 18, color: colors.warning),
                const SizedBox(width: DsSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.policiesArchivedNotice('${summary.version}'),
                        style: context.dsText.bodySmall.copyWith(height: 1.5),
                      ),
                      const SizedBox(height: DsSpacing.xs),
                      GhostButton(
                        label: l10n.policiesReadCurrent,
                        onPressed: () => context.pushReplacement(
                          RoutePaths.policyDetailOf(summary.slug),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: DsSpacing.md),
        Divider(height: 1, color: colors.divider),
      ],
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.icon, required this.label, this.tint});

  final IconData icon;
  final String label;
  final Color? tint;

  @override
  Widget build(BuildContext context) {
    final colors = context.dsColors;
    final color = tint ?? colors.onSurfaceVariant;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: DsSpacing.sm,
        vertical: DsSpacing.xxs,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(DsRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: DsSpacing.xxs),
          Text(label, style: context.dsText.caption.tint(color)),
        ],
      ),
    );
  }
}

/// What this policy said before, and when it changed.
///
/// Shown on the policy itself rather than hidden in an admin screen: "the
/// terms changed and nobody told me" is the complaint this exists to answer,
/// and a change note beside a date answers it without anyone writing an email.
class _History extends StatelessWidget {
  const _History({required this.slug, required this.history});

  final String slug;
  final List<PolicyVersionRef> history;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = context.dsColors;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.policiesHistoryTitle,
          style: context.dsText.sectionTitle.bold,
        ),
        const SizedBox(height: DsSpacing.sm),
        for (final entry in history)
          Padding(
            padding: const EdgeInsets.only(bottom: DsSpacing.xs),
            child: SurfaceCard(
              padding: const EdgeInsets.all(DsSpacing.md),
              elevation: DsCardElevation.flat,
              onTap: entry.isCurrent
                  ? null
                  : () => context.push(
                      '${RoutePaths.policyDetailOf(slug)}?version=${entry.id}',
                    ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              l10n.policiesVersionLabel('${entry.version}'),
                              style: context.dsText.labelStrong,
                            ),
                            if (entry.isCurrent) ...[
                              const SizedBox(width: DsSpacing.xs),
                              Text(
                                '· ${l10n.policiesHistoryCurrent}',
                                style: context.dsText.caption.tint(
                                  colors.success,
                                ),
                              ),
                            ],
                          ],
                        ),
                        if (entry.effectiveAt != null) ...[
                          DsGaps.vXxxs,
                          Text(
                            formatPolicyDate(l10n, entry.effectiveAt!),
                            style: context.dsText.caption,
                          ),
                        ],
                        if ((entry.changeNote ?? '').isNotEmpty) ...[
                          const SizedBox(height: DsSpacing.xxs),
                          Text(
                            entry.changeNote!,
                            style: context.dsText.bodySmall.copyWith(
                              height: 1.5,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (!entry.isCurrent)
                    Icon(
                      Icons.chevron_right_rounded,
                      size: 18,
                      color: colors.onSurfaceVariant,
                    ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
