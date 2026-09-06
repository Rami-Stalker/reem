import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:reem/core/design_system/design_system.dart';
import 'package:reem/core/localization/l10n_extension.dart';
import 'package:reem/core/router/route_paths.dart';
import 'package:reem/core/shared/entities/user.dart';

/// Three-up stat strip: following, followers and saved pieces.
///
/// Each number opens what it counts. They used to be inert — three figures
/// under a heading, with the follower lists sitting behind endpoints nothing
/// called and the saved count beside a wishlist she had to find another way
/// into. A count that cannot be opened reads as a decoration, however real the
/// number behind it is.
class ProfileStats extends StatelessWidget {
  const ProfileStats({super.key, required this.user, required this.savedCount});

  final User user;
  final int savedCount;

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: DsSpacing.lg,
        vertical: DsSpacing.lg,
      ),
      child: SurfaceCard(
        padding: const EdgeInsets.symmetric(vertical: DsSpacing.md),
        child: Row(
          children: [
            _Stat(
              value: user.followingCount,
              label: context.l10n.following,
              onTap: () => context.push(RoutePaths.followingOf(user.id)),
            ),
            _Divider(color: c.divider),
            _Stat(
              value: user.followersCount,
              label: context.l10n.followers,
              onTap: () => context.push(RoutePaths.followersOf(user.id)),
            ),
            _Divider(color: c.divider),
            _Stat(
              value: savedCount,
              label: context.l10n.wishlist,
              onTap: () => context.push(RoutePaths.favorites),
            ),
          ],
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label, this.onTap});

  final int value;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    return Expanded(
      child: Semantics(
        button: onTap != null,
        label: '$label $value',
        child: InkWell(
          onTap: onTap,
          borderRadius: DsRadius.borderLg,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: DsSpacing.xs),
            child: Column(
              children: [
                Text(
                  _format(value),
                  style: context.dsText.sectionTitle.copyWith(
                    fontWeight: DsTypography.bold,
                  ),
                ),
                const SizedBox(height: DsSpacing.xxs),
                Text(
                  label,
                  style: context.dsText.label.copyWith(
                    color: c.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _format(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
    return '$n';
  }
}

class _Divider extends StatelessWidget {
  const _Divider({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) =>
      Container(width: 1, height: 32, color: color);
}
