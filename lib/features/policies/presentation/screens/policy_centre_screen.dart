import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:ohara/core/design_system/design_system.dart';
import 'package:ohara/core/localization/l10n_extension.dart';
import 'package:ohara/core/router/route_paths.dart';
import 'package:ohara/features/auth/presentation/providers/auth_provider.dart';
import 'package:ohara/features/policies/domain/entities/policy_document.dart';
import 'package:ohara/features/policies/presentation/providers/policies_provider.dart';
import 'package:ohara/features/policies/presentation/widgets/policy_pieces.dart';
import 'package:ohara/features/policies/presentation/widgets/policy_receipts_sheet.dart';

/// «السياسات والشروط» — every published document, in one place.
///
/// Split into what addresses *her* and what addresses everyone else, rather
/// than filtered to her role. A shopper who wants to read the commissions
/// policy before she trusts a boutique is entitled to, and a policy centre
/// that hides half its documents by role is a transparency page that is not
/// transparent. The split is about what to read first, not about what she may
/// read.
///
/// Public: a guest sees every document and no acceptance state. The server
/// answers the catalogue without a session for exactly that reason.
class PolicyCentreScreen extends ConsumerWidget {
  const PolicyCentreScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final locale = policyLocaleOf(context);
    final catalogue = ref.watch(policyCatalogueProvider(locale));
    final auth = ref.watch(authNotifierProvider);

    // A guest is reading as a prospective shopper — which is what she is. The
    // alternative, showing her nothing as "hers", would put the customer terms
    // she is about to agree to at the bottom of the page.
    final mine = auth.user?.isSeller == true
        ? PolicyAudience.seller
        : PolicyAudience.customer;

    return OharaScrollPage(
      slivers: [
        PremiumAppBar(
          title: l10n.policiesTitle,
          subtitle: l10n.policiesSubtitle,
          showBack: true,
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(
            DsSpacing.lg,
            DsSpacing.sm,
            DsSpacing.lg,
            DsSpacing.xxxl,
          ),
          sliver: catalogue.when(
            loading: () => const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.all(DsSpacing.xxxl),
                child: Center(child: DsLoadingIndicator()),
              ),
            ),
            error: (error, _) => SliverToBoxAdapter(
              child: DsErrorState(
                message: '$error',
                onRetry: () => ref.invalidate(policyCatalogueProvider(locale)),
              ),
            ),
            data: (policies) {
              if (policies.isEmpty) {
                return SliverToBoxAdapter(
                  child: DsEmptyState(
                    icon: Icons.policy_outlined,
                    title: l10n.policiesTitle,
                    message: l10n.policiesEmpty,
                  ),
                );
              }

              // Split on the audience rather than on "not in the other list":
              // `PolicySummary` has no `==`, so a `contains` check here would
              // be identity comparison that happens to work only because both
              // lists came from the same objects.
              bool addressesHer(PolicySummary policy) =>
                  policy.audience == mine ||
                  policy.audience == PolicyAudience.everyone;

              final forMe = policies
                  .where(addressesHer)
                  .toList(growable: false);
              final others = policies
                  .where((policy) => !addressesHer(policy))
                  .toList(growable: false);

              return SliverList(
                delegate: SliverChildListDelegate([
                  if (auth.isAuthenticated) ...[
                    _ConsentsRow(onTap: () => showPolicyReceiptsSheet(context)),
                    const SizedBox(height: DsSpacing.lg),
                  ],
                  _SectionLabel(l10n.policiesSectionForYou),
                  for (final policy in forMe)
                    PolicyCard(
                      policy: policy,
                      onTap: () =>
                          context.push(RoutePaths.policyDetailOf(policy.slug)),
                    ),
                  if (others.isNotEmpty) ...[
                    const SizedBox(height: DsSpacing.lg),
                    _SectionLabel(
                      mine == PolicyAudience.seller
                          ? l10n.policiesSectionCustomers
                          : l10n.policiesSectionSellers,
                    ),
                    for (final policy in others)
                      PolicyCard(
                        policy: policy,
                        onTap: () => context.push(
                          RoutePaths.policyDetailOf(policy.slug),
                        ),
                      ),
                  ],
                ]),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: DsSpacing.sm),
      child: Text(
        label,
        style: context.dsText.overline.tint(context.dsColors.onSurfaceVariant),
      ),
    );
  }
}

/// The door to her own receipts.
///
/// On the policy centre rather than buried in account settings because this is
/// the page somebody opens when she is asking "what did I agree to" — and the
/// answer to that question has to be one tap from the question.
class _ConsentsRow extends StatelessWidget {
  const _ConsentsRow({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = context.dsColors;

    return SurfaceCard(
      onTap: onTap,
      padding: const EdgeInsets.all(DsSpacing.md),
      color: colors.primary.withValues(alpha: 0.06),
      child: Row(
        children: [
          Icon(Icons.fact_check_outlined, color: colors.primary),
          const SizedBox(width: DsSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.policiesMyConsents,
                  style: context.dsText.cardTitle.semibold,
                ),
                DsGaps.vXxxs,
                Text(
                  l10n.policiesMyConsentsSubtitle,
                  style: context.dsText.caption,
                ),
              ],
            ),
          ),
          Icon(
            Icons.chevron_right_rounded,
            color: colors.onSurfaceVariant,
            size: 20,
          ),
        ],
      ),
    );
  }
}
