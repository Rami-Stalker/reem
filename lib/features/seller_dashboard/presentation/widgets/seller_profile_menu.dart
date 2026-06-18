import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../../core/design_system/design_system.dart';
import '../../../../../core/router/route_paths.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

/// The seller profile settings menu — grouped into Store, Business, Support.
class SellerProfileMenu extends ConsumerWidget {
  const SellerProfileMenu({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      children: [
        _Group(
          label: 'Store management',
          rows: [
            _Row(
              icon: Icons.inventory_2_outlined,
              label: 'My products',
              color: const Color(0xFF5B8DEF),
              onTap: () => context.push(RoutePaths.myProducts),
            ),
            _Row(
              icon: Icons.local_shipping_outlined,
              label: 'Shipping settings',
              color: const Color(0xFF3FA86F),
              onTap: () => _comingSoon(context, 'Shipping settings'),
            ),
            _Row(
              icon: Icons.credit_card_outlined,
              label: 'Payment settings',
              color: const Color(0xFFE0A23C),
              onTap: () => context.push(RoutePaths.paymentMethods),
            ),
            _Row(
              icon: Icons.policy_outlined,
              label: 'Store policies',
              color: const Color(0xFF8F5C99),
              onTap: () => _comingSoon(context, 'Store policies'),
            ),
          ],
        ),
        const SizedBox(height: DsSpacing.md),
        _Group(
          label: 'Business & finance',
          rows: [
            _Row(
              icon: Icons.bar_chart_rounded,
              label: 'Analytics',
              color: const Color(0xFFE85A8A),
              onTap: () => context.push(RoutePaths.adminAnalytics),
            ),
            _Row(
              icon: Icons.receipt_long_outlined,
              label: 'Financial reports',
              color: const Color(0xFF3FA86F),
              onTap: () => _comingSoon(context, 'Financial reports'),
            ),
            _Row(
              icon: Icons.account_balance_wallet_outlined,
              label: 'Withdrawal center',
              color: const Color(0xFFD43E73),
              onTap: () => _comingSoon(context, 'Withdrawal center'),
            ),
            _Row(
              icon: Icons.group_outlined,
              label: 'Team management',
              color: const Color(0xFF5B8DEF),
              onTap: () => _comingSoon(context, 'Team management'),
            ),
            _Row(
              icon: Icons.workspace_premium_outlined,
              label: 'Subscription & plan',
              color: const Color(0xFFE0A23C),
              onTap: () => _comingSoon(context, 'Subscription & plan'),
            ),
          ],
        ),
        const SizedBox(height: DsSpacing.md),
        _Group(
          label: 'Preferences & security',
          rows: [
            _Row(
              icon: Icons.notifications_none_rounded,
              label: 'Notification settings',
              color: const Color(0xFF8F5C99),
              onTap: () => context.push(RoutePaths.notifications),
            ),
            _Row(
              icon: Icons.lock_outline_rounded,
              label: 'Security center',
              color: const Color(0xFFE5484D),
              onTap: () => context.push(RoutePaths.settings),
            ),
            _Row(
              icon: Icons.history_rounded,
              label: 'Activity logs',
              color: const Color(0xFF5B8DEF),
              onTap: () => _comingSoon(context, 'Activity logs'),
            ),
            _Row(
              icon: Icons.language_rounded,
              label: 'Language',
              color: const Color(0xFF3FA86F),
              onTap: () => context.push(RoutePaths.language),
            ),
            _Row(
              icon: Icons.palette_outlined,
              label: 'Appearance',
              color: const Color(0xFF8F5C99),
              onTap: () => context.push(RoutePaths.appearance),
            ),
          ],
        ),
        const SizedBox(height: DsSpacing.md),
        _Group(
          label: 'Support',
          rows: [
            _Row(
              icon: Icons.support_agent_rounded,
              label: 'Seller support',
              color: const Color(0xFF3FA86F),
              onTap: () => context.push(RoutePaths.chats),
            ),
            _Row(
              icon: Icons.help_outline_rounded,
              label: 'Help & documentation',
              color: const Color(0xFF5B8DEF),
              onTap: () => _comingSoon(context, 'Help & documentation'),
            ),
            _Row(
              icon: Icons.info_outline_rounded,
              label: 'About REEM',
              color: const Color(0xFFE85A8A),
              onTap: () => _comingSoon(context, 'About REEM'),
            ),
          ],
        ),
        const SizedBox(height: DsSpacing.md),
        _LogoutCard(onLogout: () => _confirmLogout(context, ref)),
      ],
    );
  }

  void _comingSoon(BuildContext context, String title) {
    DsBottomSheet.showTitled(
      context,
      title: title,
      subtitle: 'Coming soon',
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: DsSpacing.lg),
        child: Row(
          children: [
            Icon(Icons.auto_awesome_rounded, color: context.dsColors.primary),
            const SizedBox(width: DsSpacing.sm),
            const Expanded(
              child: Text(
                  'We\'re polishing this experience — it\'ll be here soon.'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmLogout(BuildContext context, WidgetRef ref) async {
    final confirmed = await DsBottomSheet.show<bool>(
      context,
      builder: (sheetContext) => DsSheetScaffold(
        title: 'Sign out?',
        subtitle: 'You can sign back in at any time.',
        child: Column(
          children: [
            DsButton(
              label: 'Sign out',
              variant: DsButtonVariant.danger,
              icon: Icons.logout_rounded,
              onPressed: () => Navigator.of(sheetContext).pop(true),
            ),
            const SizedBox(height: DsSpacing.sm),
            DsButton(
              label: 'Cancel',
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

// ── Internal components ───────────────────────────────────────────────────────

class _Group extends StatelessWidget {
  const _Group({required this.label, required this.rows});

  final String label;
  final List<_Row> rows;

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: DsSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(DsSpacing.xs, 0, 0, DsSpacing.xs),
            child: Text(label.toUpperCase(),
                style: DsTypography.overline(c.onSurfaceVariant)),
          ),
          SurfaceCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                for (var i = 0; i < rows.length; i++) ...[
                  if (i > 0) Divider(height: 1, indent: 60, color: c.divider),
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
    final c = context.dsColors;
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: DsRadius.borderCard,
      child: Padding(
        padding: const EdgeInsets.symmetric(
            horizontal: DsSpacing.md, vertical: DsSpacing.sm + 2),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: DsRadius.borderMd,
              ),
              child: Icon(icon, size: 18, color: color),
            ),
            const SizedBox(width: DsSpacing.md),
            Expanded(
              child: Text(label,
                  style: theme.textTheme.titleSmall
                      ?.copyWith(fontWeight: DsTypography.medium)),
            ),
            Icon(Icons.chevron_right_rounded,
                color: c.onSurfaceVariant, size: 20),
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
    final c = context.dsColors;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: DsSpacing.lg),
      child: SurfaceCard(
        padding: EdgeInsets.zero,
        child: InkWell(
          onTap: onLogout,
          borderRadius: DsRadius.borderCard,
          child: Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: DsSpacing.md, vertical: DsSpacing.sm + 2),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: c.error.withValues(alpha: 0.12),
                    borderRadius: DsRadius.borderMd,
                  ),
                  child: Icon(Icons.logout_rounded, size: 18, color: c.error),
                ),
                const SizedBox(width: DsSpacing.md),
                Expanded(
                  child: Text('Sign out',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: DsTypography.semiBold,
                            color: c.error,
                          )),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
