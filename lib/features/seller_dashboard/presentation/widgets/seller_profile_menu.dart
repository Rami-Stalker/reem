import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:reem/core/design_system/design_system.dart';
import 'package:reem/core/localization/l10n_extension.dart';
import 'package:reem/core/router/route_paths.dart';
import 'package:reem/features/auth/presentation/providers/auth_provider.dart';
import 'package:reem/features/settings/presentation/widgets/about_sheet.dart';
import 'package:reem/features/settings/presentation/widgets/help_sheet.dart';

/// The seller's settings menu, grouped: the storefront, the money, the
/// account, and the way to a human.
///
/// Rewritten for two reasons. Every one of its thirty-odd labels was a hard
/// English literal on an Arabic-first app, and each row carried its own
/// arbitrary colour — a blue, a green, an amber, a violet, a red — which made
/// a settings list look like a status board. Rows now take their tint from the
/// atelier's data-series palette, cycling through it so neighbours stay
/// distinguishable without any of them claiming to mean something.
class SellerProfileMenu extends ConsumerWidget {
  const SellerProfileMenu({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final series = context.atelier.series;

    Color tint(int i) => series[i % series.length];

    final groups = <_Group>[
      _Group(
        label: l10n.sellerGroupStore,
        rows: [
          _Row(
            icon: Icons.inventory_2_outlined,
            label: l10n.myProducts,
            color: tint(0),
            onTap: () => context.push(RoutePaths.myProducts),
          ),
          _Row(
            icon: Icons.local_shipping_outlined,
            label: l10n.sellerShippingSettings,
            color: tint(1),
            onTap: () => _comingSoon(context, l10n.sellerShippingSettings),
          ),
          _Row(
            icon: Icons.credit_card_outlined,
            label: l10n.sellerPaymentSettings,
            color: tint(2),
            onTap: () => context.push(RoutePaths.paymentMethods),
          ),
          _Row(
            icon: Icons.reviews_outlined,
            label: l10n.sellerReviewsMenu,
            color: tint(3),
            onTap: () => context.push(RoutePaths.sellerReviews),
          ),
          _Row(
            icon: Icons.route_outlined,
            label: l10n.courierDay,
            color: tint(9),
            onTap: () => context.push(RoutePaths.courierDay),
          ),
          _Row(
            icon: Icons.assignment_return_outlined,
            label: l10n.sellerReturnsTitle,
            color: tint(4),
            onTap: () => context.push(RoutePaths.sellerReturns),
          ),
          _Row(
            icon: Icons.policy_outlined,
            label: l10n.sellerStorePolicies,
            color: tint(5),
            onTap: () => _comingSoon(context, l10n.sellerStorePolicies),
          ),
        ],
      ),
      _Group(
        label: l10n.sellerGroupBusiness,
        rows: [
          _Row(
            icon: Icons.bar_chart_rounded,
            label: l10n.sellerAnalytics,
            color: tint(0),
            onTap: () => context.push(RoutePaths.sellerAnalytics),
          ),
          _Row(
            icon: Icons.receipt_long_outlined,
            label: l10n.sellerFinancialReports,
            color: tint(1),
            onTap: () => context.push(RoutePaths.sellerEarnings),
          ),
          _Row(
            icon: Icons.account_balance_wallet_outlined,
            label: l10n.sellerWithdrawalCentre,
            color: tint(2),
            onTap: () => context.push(RoutePaths.sellerEarnings),
          ),
          _Row(
            icon: Icons.group_outlined,
            label: l10n.sellerTeamManagement,
            color: tint(3),
            onTap: () => _comingSoon(context, l10n.sellerTeamManagement),
          ),
          _Row(
            icon: Icons.workspace_premium_outlined,
            label: l10n.sellerSubscriptionPlan,
            color: tint(4),
            onTap: () => _comingSoon(context, l10n.sellerSubscriptionPlan),
          ),
        ],
      ),
      _Group(
        label: l10n.sellerGroupPreferences,
        rows: [
          _Row(
            icon: Icons.notifications_none_rounded,
            label: l10n.notifications,
            color: tint(0),
            onTap: () => context.push(RoutePaths.notifications),
          ),
          _Row(
            icon: Icons.lock_outline_rounded,
            label: l10n.securityCentre,
            color: tint(1),
            onTap: () => context.push(RoutePaths.securitySettings),
          ),
          _Row(
            icon: Icons.history_rounded,
            label: l10n.sellerActivityLog,
            color: tint(2),
            onTap: () => _comingSoon(context, l10n.sellerActivityLog),
          ),
          _Row(
            icon: Icons.language_rounded,
            label: l10n.language,
            color: tint(3),
            onTap: () => context.push(RoutePaths.language),
          ),
          _Row(
            icon: Icons.palette_outlined,
            label: l10n.appearance,
            color: tint(4),
            onTap: () => context.push(RoutePaths.appearance),
          ),
        ],
      ),
      _Group(
        label: l10n.support,
        rows: [
          _Row(
            icon: Icons.support_agent_rounded,
            label: l10n.sellerSupport,
            color: tint(0),
            onTap: () => context.push(RoutePaths.chats),
          ),
          _Row(
            icon: Icons.help_outline_rounded,
            label: l10n.helpAndFaq,
            color: tint(1),
            onTap: () => showHelpSheet(context),
          ),
          _Row(
            icon: Icons.info_outline_rounded,
            label: l10n.aboutReem,
            color: tint(2),
            onTap: () => showAboutSheet(context),
          ),
        ],
      ),
    ];

    return Column(
      children: [
        for (final group in groups) ...[
          group,
          const SizedBox(height: DsSpacing.md),
        ],
        _LogoutCard(onLogout: () => _confirmLogout(context, ref)),
      ],
    );
  }

  void _comingSoon(BuildContext context, String title) {
    final l10n = context.l10n;
    DsBottomSheet.showTitled(
      context,
      title: title,
      subtitle: l10n.comingSoon,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: DsSpacing.lg),
        child: Row(
          children: [
            Icon(Icons.auto_awesome_rounded, color: context.dsColors.primary),
            const SizedBox(width: DsSpacing.sm),
            Expanded(child: Text(l10n.comingSoonBlurb)),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmLogout(BuildContext context, WidgetRef ref) async {
    final l10n = context.l10n;
    final confirmed = await DsBottomSheet.show<bool>(
      context,
      builder: (sheetContext) => DsSheetScaffold(
        title: l10n.signOutQuestion,
        subtitle: l10n.signBackInLater,
        child: Column(
          children: [
            DsButton(
              label: l10n.signOut,
              variant: DsButtonVariant.danger,
              icon: Icons.logout_rounded,
              onPressed: () => Navigator.of(sheetContext).pop(true),
            ),
            const SizedBox(height: DsSpacing.sm),
            DsButton(
              label: l10n.cancel,
              variant: DsButtonVariant.ghost,
              onPressed: () => Navigator.of(sheetContext).pop(false),
            ),
          ],
        ),
      ),
    );

    if (confirmed == true) {
      await ref.read(authNotifierProvider.notifier).logout();
    }
  }
}

// ── Internal components ─────────────────────────────────────────────────────

class _Group extends StatelessWidget {
  const _Group({required this.label, required this.rows});

  final String label;
  final List<_Row> rows;

  @override
  Widget build(BuildContext context) {
    final palette = context.atelier;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: DsSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(
              DsSpacing.xs,
              0,
              0,
              DsSpacing.xs,
            ),
            child: Text(
              label.toUpperCase(),
              style: DsTypography.overline(palette.muted),
            ),
          ),
          Container(
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: palette.surface,
              borderRadius: DsRadius.borderCard,
              border: Border.all(color: palette.line),
              boxShadow: palette.shadow,
            ),
            child: Column(
              children: [
                for (var i = 0; i < rows.length; i++) ...[
                  if (i > 0)
                    Divider(height: 1, indent: 60, color: palette.line),
                  rows[i],
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.atelier;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: DsSpacing.md,
          vertical: DsSpacing.sm + DsSpacing.xxxs,
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.13),
                borderRadius: DsRadius.borderMd,
              ),
              child: Icon(icon, size: 18, color: color),
            ),
            const SizedBox(width: DsSpacing.md),
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.dsText.tileTitle.tint(palette.ink),
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: palette.muted,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}

class _LogoutCard extends StatelessWidget {
  const _LogoutCard({required this.onLogout});

  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    final palette = context.atelier;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: DsSpacing.lg),
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: palette.surface,
          borderRadius: DsRadius.borderCard,
          border: Border.all(color: palette.line),
          boxShadow: palette.shadow,
        ),
        child: InkWell(
          onTap: onLogout,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: DsSpacing.md,
              vertical: DsSpacing.sm + DsSpacing.xxxs,
            ),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: palette.critical.withValues(alpha: 0.13),
                    borderRadius: DsRadius.borderMd,
                  ),
                  child: Icon(
                    Icons.logout_rounded,
                    size: 18,
                    color: palette.critical,
                  ),
                ),
                const SizedBox(width: DsSpacing.md),
                Expanded(
                  child: Text(
                    context.l10n.signOut,
                    style: context.dsText.tileTitle.semibold.tint(palette.critical),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
