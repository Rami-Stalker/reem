import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/design_system/design_system.dart';
import '../../../../core/router/route_paths.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../providers/profile_overview_provider.dart';
import '../../../../core/localization/l10n_extension.dart';

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
          label: context.l10n.account,
          rows: [
            _MenuRow(
              icon: Icons.location_on_outlined,
              label: context.l10n.savedAddresses,
              onTap: () => context.push(RoutePaths.addresses),
            ),
            _MenuRow(
              icon: Icons.credit_card_outlined,
              label: context.l10n.paymentMethods,
              onTap: () => context.push(RoutePaths.paymentMethods),
            ),
            _MenuRow(
              icon: Icons.reviews_outlined,
              label: context.l10n.reviewsAndRatings,
              trailing: rating != null
                  ? '${rating.toStringAsFixed(1)} · $reviews'
                  : null,
              onTap: () => _comingSoon(context, context.l10n.reviewsAndRatings),
            ),
            _MenuRow(
              icon: Icons.notifications_none_rounded,
              label: context.l10n.notifications,
              onTap: () => context.push(RoutePaths.notifications),
            ),
          ],
        ),
        const SizedBox(height: DsSpacing.md),
        _Group(
          label: context.l10n.preferences,
          rows: [
            _MenuRow(
              icon: Icons.palette_outlined,
              label: context.l10n.appPreferences,
              onTap: () => context.push(RoutePaths.appearance),
            ),
            _MenuRow(
              icon: Icons.language_rounded,
              label: context.l10n.language,
              onTap: () => context.push(RoutePaths.language),
            ),
            _MenuRow(
              icon: Icons.lock_outline_rounded,
              label: context.l10n.securityTitle,
              onTap: () => context.push(RoutePaths.settings),
            ),
          ],
        ),
        const SizedBox(height: DsSpacing.md),
        _Group(
          label: context.l10n.support,
          rows: [
            _MenuRow(
              icon: Icons.help_outline_rounded,
              label: context.l10n.helpAndFaq,
              onTap: () => _helpSheet(context),
            ),
            _MenuRow(
              icon: Icons.support_agent_rounded,
              label: context.l10n.supportCentre,
              onTap: () => _supportSheet(context),
            ),
            _MenuRow(
              icon: Icons.info_outline_rounded,
              label: context.l10n.aboutReem,
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
      subtitle: context.l10n.comingSoon,
      child: const _ComingSoon(),
    );
  }

  void _helpSheet(BuildContext context) {
    DsBottomSheet.showTitled(
      context,
      title: context.l10n.helpAndFaq,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Faq(
            q: context.l10n.faqTracking,
            a: context.l10n.faqTrackingAnswer,
          ),
          _Faq(
            q: context.l10n.faqPoints,
            a: context.l10n.rewardsPointsBlurb,
          ),
          _Faq(
            q: context.l10n.faqReturns,
            a: context.l10n.faqReturnsAnswer,
          ),
        ],
      ),
    );
  }

  void _supportSheet(BuildContext context) {
    DsBottomSheet.showTitled(
      context,
      title: context.l10n.supportCentre,
      subtitle: context.l10n.replyWithinHour,
      child: Column(
        children: [
          _ContactRow(
            icon: Icons.chat_bubble_outline_rounded,
            label: context.l10n.liveChat,
            value: context.l10n.startConversation,
            onTap: () => context.push(RoutePaths.chats),
          ),
          _ContactRow(
            icon: Icons.mail_outline_rounded,
            label: context.l10n.emailUs,
            value: 'support@reem.shop',
          ),
          _ContactRow(
            icon: Icons.phone_outlined,
            label: context.l10n.call,
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
      title: context.l10n.aboutReem,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DsGradientText('REEM',
              style: theme.textTheme.headlineMedium
                      ?.copyWith(fontWeight: DsTypography.bold) ??
                  const TextStyle()),
          const SizedBox(height: DsSpacing.xs),
          Text(
            context.l10n.aboutReemBlurb,
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: DsSpacing.md),
          Text(context.l10n.appVersion('1.0.0'),
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
        title: context.l10n.signOutQuestion,
        subtitle: context.l10n.signBackInLater,
        child: Column(
          children: [
            DsButton(
              label: context.l10n.signOut,
              variant: DsButtonVariant.danger,
              icon: Icons.logout_rounded,
              onPressed: () => Navigator.of(sheetContext).pop(true),
            ),
            const SizedBox(height: DsSpacing.sm),
            DsButton(
              label: context.l10n.cancel,
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
                  child: Text(context.l10n.signOut,
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
              context.l10n.comingSoonBlurb,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}
