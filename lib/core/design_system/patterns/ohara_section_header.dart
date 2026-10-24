import 'package:flutter/material.dart';
import 'package:ohara/core/design_system/design_system.dart';
import 'package:ohara/core/localization/l10n_extension.dart';

class OharaSectionHeader extends StatelessWidget {
  const OharaSectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onSeeAll,
  });

  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onSeeAll;

  @override
  Widget build(BuildContext context) {
    final colors = context.dsColors;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DsGradientText(
                title,
                style: context.dsText.screenTitle.bold,
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 4),
                Text(
                  subtitle!,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                ),
              ],
            ],
          ),
        ),
        if (onSeeAll != null)
          TextButton(
            onPressed: onSeeAll,
            child: Text(
              context.l10n.viewAll,
              style: TextStyle(
                color: colors.primary,
                fontWeight: DsTypography.semiBold,
              ),
            ),
          )
        else ?trailing,
      ],
    );
  }
}
