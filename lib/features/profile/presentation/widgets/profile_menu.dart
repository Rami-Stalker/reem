import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/design_system/design_system.dart';
import '../../../../core/router/route_paths.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../providers/profile_overview_provider.dart';

/// The grouped account menu — Account, Preferences and Support sections plus a
/// sign-out action. Real destinations route to their screens; surfaces without
/// a screen yet open polished bottom sheets (Help, About, contact).
class ProfileMenu extends ConsumerWidget {
  const ProfileMenu({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rating = ref.watch(
      profileOverviewNotifierProvider.select((s) => s.overview?.averageRating),
    );
    final reviews = ref.watch(
      profileOverviewNotifierProvider.select((s) => s.overview?.reviewsCount ?? 0),
    );

    return Column(
      children: [
        _Group(
          label: 'Account',
          rows: [
            _MenuRow(
              icon: Icons.location_on_outlined,
              label: 'Saved addresses',
              onTap: () => context.push(RoutePaths.addresses),
            ),
            _MenuRow(
              icon: Icons.credit_card_outlined,
              label: 'Payment methods',
              onTap: () => context.push(RoutePaths.paymentMethods),
            ),
            _MenuRow(
              icon: Icons.reviews_outlined,
              label: 'Reviews & ratings',
              trailing: rating != null
                  ? '${rating.toStringAsFixed(1)} · $reviews'
                  : null,
              onTap: () => _comingSoon(context, 'Reviews & ratings'),
            ),
            _MenuRow(
              icon: Icons.notifications_none_rounded,
              label: 'Notifications',
              onTap: () => context.push(RoutePaths.notifications),
            ),
          ],
        ),
        const SizedBox(height: DsSpacing.md),
        _Group(
          label: 'Preferences',
          rows: [
            _MenuRow(
              icon: Icons.palette_outlined,
              label: 'App preferences',
              onTap: () => context.push(RoutePaths.appearance),
            ),
            _MenuRow(
              icon: Icons.language_rounded,
              label: 'Language',
              onTap: () => context.push(RoutePaths.language),
            ),
            _MenuRow(
              icon: Icons.lock_outline_rounded,
              label: 'Privacy & security',
              onTap: () => context.push(RoutePaths.settings),
            ),
          ],
        ),
        const SizedBox(height: DsSpacing.md),
        _Group(
          label: 'Support',
          rows: [
            _MenuRow(
              icon: Icons.help_outline_rounded,
              label: 'Help & FAQ',
              onTap: () => _helpSheet(context),
            ),
            _MenuRow(
              icon: Icons.support_agent_rounded,
              label: 'Support centre',
              onTap: () => _supportSheet(context),
            ),
            _MenuRow(
              icon: Icons.info_outline_rounded,
              label: 'About REEM',
              onTap: () => _aboutSheet(context),
            ),
          ],
        ),
        const SizedBox(height: DsSpacing.md),
        _LogoutCard(onLogout: () => _confirmLogout(context, ref)),
      ],
    );
  }

  // ── Sheets ───────────────────────────────────────────────────────────────
  void _comingSoon(BuildContext context, String title) {
    DsBottomSheet.showTitled(
      context,
      title: title,
      subtitle: 'Coming soon',
      child: const _ComingSoon(),
    );
  }

  void _helpSheet(BuildContext context) {
    DsBottomSheet.showTitled(
      context,
      title: 'Help & FAQ',
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Faq(
            q: 'How do I track my order?',
            a: 'Open My orders from your profile to see live status and delivery updates.',
          ),
          _Faq(
            q: 'How do loyalty points work?',
            a: 'Earn points on every order and review. Redeem them for coupons and perks.',
          ),
          _Faq(
            q: 'What is your returns policy?',
            a: 'Most items can be returned within 14 days. Open an order to start a return.',
          ),
        ],
      ),
    );
  }

  void _supportSheet(BuildContext context) {
    DsBottomSheet.showTitled(
      context,
      title: 'Support centre',
      subtitle: 'We usually reply within an hour',
      child: Column(
        children: [
          _ContactRow(
            icon: Icons.chat_bubble_outline_rounded,
            label: 'Live chat',
            value: 'Start a conversation',
            onTap: () => context.push(RoutePaths.chats),
          ),
          _ContactRow(
            icon: Icons.mail_outline_rounded,
            label: 'Email us',
            value: 'support@reem.shop',
          ),
          _ContactRow(
            icon: Icons.phone_outlined,
            label: 'Call',
            value: '+966 11 000 0000',
          ),
        ],
      ),
    );
  }

  void _aboutSheet(BuildContext context) {
    final theme = Theme.of(context);
    DsBottomSheet.showTitled(
      context,
      title: 'About REEM',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DsGradientText('REEM',
              style: theme.textTheme.headlineMedium
                      ?.copyWith(fontWeight: DsTypography.bold) ??
                  const TextStyle()),
          const SizedBox(height: DsSpacing.xs),
          Text(
            'A premium social-commerce home for the pieces you love — shopping, '
            'stories and rewards in one beautiful place.',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: DsSpacing.md),
          Text('Version 1.0.0',
              style: theme.textTheme.labelMedium
                  ?.copyWith(color: context.dsColors.onSurfaceVariant)),
        ],
      ),
    );
  }

  Future<void> _confirmLogout(BuildContext context, WidgetRef ref) async {
    final confirmed = await DsBottomSheet.show<bool>(
      context,
      builder: (sheetContext) => DsSheetScaffold(
        title: 'Sign out?',
        subtitle: 'You can always sign back in.',
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
      // The auth-aware router redirect sends signed-out users to login.
    }
  }
}

class _Group extends StatelessWidget {
  const _Group({required this.label, required this.rows});

  final String label;
  final List<_MenuRow> rows;

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

class _MenuRow extends StatelessWidget {
  const _MenuRow({
    required this.icon,
    required this.label,
    required this.onTap,
    this.trailing,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final String? trailing;

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
                color: c.primaryContainer.withValues(alpha: 0.55),
                borderRadius: DsRadius.borderMd,
              ),
              child: Icon(icon, size: 19, color: c.primary),
            ),
            const SizedBox(width: DsSpacing.md),
            Expanded(
              child: Text(label,
                  style: theme.textTheme.titleSmall
                      ?.copyWith(fontWeight: DsTypography.medium)),
            ),
            if (trailing != null) ...[
              Text(trailing!,
                  style: theme.textTheme.labelMedium
                      ?.copyWith(color: c.onSurfaceVariant)),
              const SizedBox(width: DsSpacing.xs),
            ],
            Icon(Icons.chevron_right_rounded, color: c.onSurfaceVariant, size: 20),
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
                  child: Icon(Icons.logout_rounded, size: 19, color: c.error),
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

class _Faq extends StatelessWidget {
  const _Faq({required this.q, required this.a});

  final String q;
  final String a;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: DsSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(q,
              style: theme.textTheme.titleSmall
                  ?.copyWith(fontWeight: DsTypography.bold)),
          const SizedBox(height: DsSpacing.xxs),
          Text(a,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: context.dsColors.onSurfaceVariant)),
        ],
      ),
    );
  }
}

class _ContactRow extends StatelessWidget {
  const _ContactRow({
    required this.icon,
    required this.label,
    required this.value,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final String value;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    final theme = Theme.of(context);
    return ListTile(
      onTap: onTap,
      contentPadding: EdgeInsets.zero,
      leading: Container(
        width: 40,
        height: 40,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: c.primaryContainer.withValues(alpha: 0.55),
          borderRadius: DsRadius.borderMd,
        ),
        child: Icon(icon, color: c.primary, size: 20),
      ),
      title: Text(label,
          style: theme.textTheme.titleSmall
              ?.copyWith(fontWeight: DsTypography.semiBold)),
      subtitle: Text(value,
          style: theme.textTheme.bodySmall
              ?.copyWith(color: c.onSurfaceVariant)),
    );
  }
}

class _ComingSoon extends StatelessWidget {
  const _ComingSoon();

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: DsSpacing.lg),
      child: Row(
        children: [
          Icon(Icons.auto_awesome_rounded, color: c.primary),
          const SizedBox(width: DsSpacing.sm),
          Expanded(
            child: Text(
              'We’re polishing this experience — it’ll be here soon.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}
