import 'package:flutter/material.dart';

import '../../../../core/design_system/design_system.dart';
import '../../../../core/localization/l10n_extension.dart';

/// A premium section header for the profile centre: optional rose eyebrow, an
/// elegant title and an optional "See all" affordance. Carries its own padding.
class ProfileSectionHeader extends StatelessWidget {
  const ProfileSectionHeader({
    super.key,
    required this.title,
    this.eyebrow,
    this.onSeeAll,
    this.seeAllLabel,
    this.padding = const EdgeInsets.fromLTRB(
      DsSpacing.lg,
      0,
      DsSpacing.lg,
      DsSpacing.md,
    ),
  });

  final String title;
  final String? eyebrow;
  final VoidCallback? onSeeAll;
  /// Defaults to the localised "see all" when omitted.
  final String? seeAllLabel;
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
              ],
            ),
          ),
          if (onSeeAll != null)
            GestureDetector(
              onTap: onSeeAll,
              child: Row(
                children: [
                  Text(
                    seeAllLabel ?? context.l10n.viewAll,
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
