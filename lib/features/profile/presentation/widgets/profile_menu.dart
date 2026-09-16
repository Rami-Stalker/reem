import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:reem/core/config/app_env.dart';
import 'package:reem/core/design_system/design_system.dart';
import 'package:reem/core/localization/l10n_extension.dart';
import 'package:reem/core/router/route_paths.dart';
import 'package:reem/features/auth/presentation/providers/auth_provider.dart';
import 'package:reem/features/cart/presentation/providers/cart_providers.dart';
import 'package:reem/features/profile/presentation/providers/profile_overview_provider.dart';
import 'package:reem/features/settings/presentation/widgets/about_sheet.dart';
import 'package:reem/features/settings/presentation/widgets/help_sheet.dart';
import 'package:url_launcher/url_launcher.dart';

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
    final cartCount = ref.watch(cartCountProvider);

    return Column(
      children: [
        _Group(
          label: context.l10n.account,
          rows: [
            // The bag is not a tab any more — Rooms took that slot — and it
            // was not anywhere else either, so a woman could fill it and have
            // no way back to it. The count is here for the same reason the
            // rating is on the reviews row: the number is the reason to tap.
            _MenuRow(
              icon: DsIcons.cart,
              label: context.l10n.navCart,
              trailing: cartCount > 0 ? '$cartCount' : null,
              onTap: () => context.push(RoutePaths.cart),
            ),
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
              onTap: () => context.push(RoutePaths.myReviews),
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
              onTap: () => context.push(RoutePaths.securitySettings),
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
              onTap: () => showHelpSheet(context),
            ),
            // Only offered when a real address or number was configured. It
            // used to print an invented email and a Saudi landline, neither of
            // which was even tappable.
            if (AppEnv.hasSupportContact)
              _MenuRow(
                icon: Icons.support_agent_rounded,
                label: context.l10n.supportCentre,
                onTap: () => _supportSheet(context),
              ),
            _MenuRow(
              icon: Icons.policy_outlined,
              label: context.l10n.policiesTitle,
              onTap: () => context.push(RoutePaths.policies),
            ),
            _MenuRow(
              icon: Icons.info_outline_rounded,
              label: context.l10n.aboutReem,
              onTap: () => showAboutSheet(context),
            ),
          ],
        ),
        const SizedBox(height: DsSpacing.md),
        _LogoutCard(onLogout: () => _confirmLogout(context, ref)),
      ],
    );
  }

  // ── Sheets ───────────────────────────────────────────────────────────────
  /// Only reachable when [AppEnv] carries a real address or number, so every
  /// row here both exists and works.
  void _supportSheet(BuildContext context) {
    final email = AppEnv.supportEmail.trim();
    final phone = AppEnv.supportPhone.trim();

    DsBottomSheet.showTitled(
      context,
      title: context.l10n.supportCentre,
      child: Column(
        children: [
          if (email.isNotEmpty)
            _ContactRow(
              icon: Icons.mail_outline_rounded,
              label: context.l10n.emailUs,
              value: email,
              onTap: () => _open(context, Uri(scheme: 'mailto', path: email)),
            ),
          if (phone.isNotEmpty)
            _ContactRow(
              icon: Icons.phone_outlined,
              label: context.l10n.call,
              value: phone,
              onTap: () => _open(
                context,
                Uri(scheme: 'tel', path: phone.replaceAll(' ', '')),
              ),
            ),
        ],
      ),
    );
  }

  /// Hands the address or number to the OS. A handset with no mail app is
  /// real, so a refusal is reported rather than swallowed.
  static Future<void> _open(BuildContext context, Uri uri) async {
    final launched = await launchUrl(uri);
    if (!launched && context.mounted) {
      DsSnackbar.error(context, context.l10n.error);
    }
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
            padding: const EdgeInsets.fromLTRB(DsSpacing.xs, DsSpacing.xxxs, DsSpacing.xxxs, DsSpacing.xs),
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
    return InkWell(
      onTap: onTap,
      borderRadius: DsRadius.borderCard,
      child: Padding(
        padding: const EdgeInsets.symmetric(
            horizontal: DsSpacing.md, vertical: DsSpacing.sm + DsSpacing.xxxs),
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
                  style: context.dsText.tileTitle
                      .copyWith(fontWeight: DsTypography.medium)),
            ),
            if (trailing != null) ...[
              Text(trailing!,
                  style: context.dsText.label
                      .copyWith(color: c.onSurfaceVariant)),
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
                horizontal: DsSpacing.md, vertical: DsSpacing.sm + DsSpacing.xxxs),
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
                      style: context.dsText.tileTitle.copyWith(
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
          style: context.dsText.tileTitle
              .copyWith(fontWeight: DsTypography.semiBold)),
      subtitle: Text(value,
          style: context.dsText.cardSubtitle
              .copyWith(color: c.onSurfaceVariant)),
    );
  }
}

