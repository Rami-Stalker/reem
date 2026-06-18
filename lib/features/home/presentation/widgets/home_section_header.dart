import 'package:flutter/material.dart';

import '../../../../core/design_system/design_system.dart';

/// A premium section header: a small rose eyebrow, an elegant serif title and
/// an optional subtitle / "See all" affordance. Used across the home page.
class HomeSectionHeader extends StatelessWidget {
  const HomeSectionHeader({
    super.key,
    required this.title,
    this.eyebrow,
    this.subtitle,
    this.onSeeAll,
    this.padding = const EdgeInsets.fromLTRB(
      DsSpacing.lg,
      0,
      DsSpacing.lg,
      DsSpacing.md,
    ),
  });

  final String title;
  final String? eyebrow;
  final String? subtitle;
  final VoidCallback? onSeeAll;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    final theme = Theme.of(context);

    return Padding(
      padding: padding,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (eyebrow != null) ...[
                  Text(eyebrow!.toUpperCase(),
                      style: DsTypography.overline(c.primary)),
                  const SizedBox(height: DsSpacing.xxs),
                ],
                Text(
                  title,
                  style: theme.textTheme.headlineSmall
                      ?.copyWith(fontWeight: DsTypography.bold),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: DsSpacing.xxs),
                  Text(
                    subtitle!,
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: c.onSurfaceVariant),
                  ),
                ],
              ],
            ),
          ),
          if (onSeeAll != null)
            GestureDetector(
              onTap: onSeeAll,
              child: Row(
                children: [
                  Text(
                    'See all',
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: c.primary,
                      fontWeight: DsTypography.semiBold,
                    ),
                  ),
                  Icon(Icons.chevron_right_rounded, size: 18, color: c.primary),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
