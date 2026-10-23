import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:reem/core/design_system/design_system.dart';
import 'package:reem/core/localization/l10n_extension.dart';
import 'package:reem/core/router/open_route.dart';
import 'package:reem/core/router/route_paths.dart';
import 'package:reem/core/shared/entities/user.dart';
import 'package:reem/core/shared/services/share_service.dart';

/// The top of her own profile: her portrait in the arch, her name, where her
/// account stands, the three counts she can open, and the way to edit it all.
///
/// It replaces the gradient cover, the identity block and the stat strip,
/// which were three cards saying one thing.
class ProfileHeader extends StatelessWidget {
  const ProfileHeader({
    super.key,
    required this.user,
    required this.savedCount,
  });

  final User user;
  final int savedCount;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = context.dsColors;
    final canPop = Navigator.of(context).canPop();
    final bio = user.bio?.trim();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ProfileHero(
          name: user.name,
          imageUrl: user.imageUrl,
          leading: canPop
              ? ProfileCircleButton(
                  icon: DsIcons.back,
                  tooltip: l10n.back,
                  onPressed: () => popOrHome(context),
                )
              : null,
          actions: [
            ProfileCircleButton(
              icon: Icons.ios_share_rounded,
              tooltip: l10n.profileShare,
              onPressed: () => ShareService.profile(
                context: context,
                userId: user.id,
                name: user.name,
                imageUrl: user.imageUrl,
              ),
            ),
            ProfileCircleButton(
              icon: Icons.settings_rounded,
              tooltip: l10n.settings,
              onPressed: () => context.push(RoutePaths.settings),
            ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: DsSpacing.lg),
          child: ProfileNameplate(
            name: user.name,
            username: user.username,
            isVerified: user.isVerified,
            verifiedLabel: l10n.verified,
            location: user.location,
            roleLabel: l10n.roleBuyer,
          ),
        ),
        DsGaps.vSm,
        // Where her account stands, and the number it is tied to — hers to
        // see, on her own page only.
        Wrap(
          alignment: WrapAlignment.center,
          spacing: DsSpacing.xs,
          runSpacing: DsSpacing.xs,
          children: [
            _Chip(
              icon: user.isVerified
                  ? Icons.verified_user_rounded
                  : Icons.gpp_maybe_rounded,
              label: user.isVerified ? l10n.verified : l10n.unverified,
              tone: user.isVerified ? colors.success : colors.warning,
            ),
            if (user.phone.isNotEmpty)
              _Chip(
                icon: Icons.phone_iphone_rounded,
                label: user.phone,
                ltr: true,
              ),
          ],
        ),
        if (bio != null && bio.isNotEmpty) ...[
          DsGaps.vXl,
          ProfileQuote(text: bio),
          DsGaps.vMd,
        ],
        DsGaps.vXl,
        // Each count opens what it counts.
        ProfileArchStats(
          items: [
            ProfileStatItem(
              value: _compact(user.followingCount),
              label: l10n.following,
              onTap: () => context.push(RoutePaths.followingOf(user.id)),
            ),
            ProfileStatItem(
              value: _compact(user.followersCount),
              label: l10n.followers,
              onTap: () => context.push(RoutePaths.followersOf(user.id)),
            ),
            ProfileStatItem(
              value: _compact(savedCount),
              label: l10n.wishlist,
              onTap: () => context.push(RoutePaths.favorites),
            ),
          ],
        ),
        DsGaps.vXl,
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: DsSpacing.lg),
          child: DsButton(
            label: l10n.editProfile,
            icon: Icons.edit_rounded,
            variant: DsButtonVariant.tonal,
            size: DsButtonSize.md,
            isExpanded: true,
            onPressed: () => context.push(RoutePaths.editProfile),
          ),
        ),
      ],
    );
  }

  static String _compact(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
    return '$n';
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.icon,
    required this.label,
    this.tone,
    this.ltr = false,
  });

  final IconData icon;
  final String label;
  final Color? tone;

  /// A phone number reads left to right even on an Arabic page.
  final bool ltr;

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: DsSpacing.sm,
        vertical: DsSpacing.xxs,
      ),
      decoration: BoxDecoration(
        color: c.surface.withValues(alpha: 0.8),
        borderRadius: DsRadius.borderPill,
        border: Border.all(color: c.border.withValues(alpha: 0.6)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: DsSizes.iconXxs, color: tone ?? c.onSurfaceVariant),
          DsGaps.hXxs,
          Text(
            label,
            textDirection: ltr ? TextDirection.ltr : null,
            style: context.dsText.caption.semibold.tint(c.onSurface),
          ),
        ],
      ),
    );
  }
}
