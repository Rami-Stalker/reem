import 'package:flutter/material.dart';

import '../../../../core/design_system/design_system.dart';
import '../../../../core/shared/entities/user.dart';
import '../../../../core/localization/l10n_extension.dart';

/// Three-up stat strip: following, followers and saved pieces.
class ProfileStats extends StatelessWidget {
  const ProfileStats({super.key, required this.user, required this.savedCount});

  final User user;
  final int savedCount;

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    return Padding(
      padding: const EdgeInsets.symmetric(
          horizontal: DsSpacing.lg, vertical: DsSpacing.lg),
      child: SurfaceCard(
        padding: const EdgeInsets.symmetric(vertical: DsSpacing.md),
        child: Row(
          children: [
            _Stat(value: user.followingCount, label: context.l10n.following),
            _Divider(color: c.divider),
            _Stat(value: user.followersCount, label: context.l10n.followers),
            _Divider(color: c.divider),
            _Stat(value: savedCount, label: context.l10n.unfavorite),
          ],
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label});

  final int value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    final theme = Theme.of(context);
    return Expanded(
      child: Column(
        children: [
          Text(_format(value),
              style: theme.textTheme.titleLarge
                  ?.copyWith(fontWeight: DsTypography.bold)),
          const SizedBox(height: DsSpacing.xxs),
          Text(label,
              style: theme.textTheme.labelMedium
                  ?.copyWith(color: c.onSurfaceVariant)),
        ],
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
