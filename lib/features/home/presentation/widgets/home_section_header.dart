import 'package:flutter/material.dart';

import 'package:reem/core/design_system/design_system.dart';
import 'package:reem/core/localization/l10n_extension.dart';

/// The editorial section header used across the home page.
///
/// Reads like a magazine masthead rather than a list label: a short rose
/// eyebrow led by a gradient rule, the section name set in the display serif,
/// an optional line of copy underneath, and — when there is somewhere to go —
/// a soft blush pill instead of a bare blue-ish link.
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (eyebrow != null) ...[
            _Eyebrow(text: eyebrow!),
            const SizedBox(height: DsSpacing.xs),
          ],
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: DsTypography.bold,
                    height: 1.15,
                  ),
                ),
              ),
              if (onSeeAll != null) ...[
                const SizedBox(width: DsSpacing.sm),
                _SeeAllPill(onTap: onSeeAll!),
              ],
            ],
          ),
          if (subtitle != null) ...[
            const SizedBox(height: DsSpacing.xxs),
            Text(
              subtitle!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: c.onSurfaceVariant,
                height: 1.4,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// A short gradient rule, then the label — the couture answer to a bullet.
class _Eyebrow extends StatelessWidget {
  const _Eyebrow({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    return Row(
      children: [
        Container(
          width: 18,
          height: 2,
          decoration: BoxDecoration(
            gradient: context.primaryGradient,
            borderRadius: DsRadius.borderPill,
          ),
        ),
        const SizedBox(width: DsSpacing.xs),
        Flexible(
          child: Text(
            text.toUpperCase(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: DsTypography.overline(c.primary),
          ),
        ),
        const SizedBox(width: DsSpacing.xs),
        DsSparkle(size: 9, color: c.accent, opacity: 0.85),
      ],
    );
  }
}

class _SeeAllPill extends StatelessWidget {
  const _SeeAllPill({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: DsSpacing.sm,
          vertical: DsSpacing.xxs + 2,
        ),
        decoration: BoxDecoration(
          color: c.primaryContainer,
          borderRadius: DsRadius.borderPill,
          border: Border.all(color: c.primary.withValues(alpha: 0.18)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              context.l10n.viewAll,
              style: TextStyle(
                color: c.onPrimaryContainer,
                fontSize: DsTypography.labelMedium,
                fontWeight: DsTypography.bold,
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              size: 16,
              color: c.onPrimaryContainer,
            ),
          ],
        ),
      ),
    );
  }
}
