import 'package:flutter/material.dart';

import 'package:ohara/core/design_system/design_system.dart';

class SettingsItemData {
  const SettingsItemData({
    required this.icon,
    required this.title,
    this.onTap,
    this.value,
    this.color,
  });

  final IconData icon;
  final String title;
  final VoidCallback? onTap;

  /// What the row is set to now — the language, the theme — shown at its
  /// end so she need not open it to know.
  final String? value;

  /// For the one row that is not like the others (signing out).
  final Color? color;
}

/// A group of the settings hub: a velvet tray on the vanity.
class SettingsCategoryCard extends StatelessWidget {
  const SettingsCategoryCard({
    super.key,
    required this.title,
    required this.items,
  });

  final String title;
  final List<SettingsItemData> items;

  @override
  Widget build(BuildContext context) {
    final palette = context.boutique;
    return VanityTray(
      title: title,
      children: [
        for (final item in items)
          Opacity(
            // A row she cannot open here stays in its place, quietly.
            opacity: item.onTap == null ? 0.45 : 1,
            child: VanityRow(
              icon: item.icon,
              title: item.title,
              color: item.color,
              onTap: item.onTap,
              trailing: item.value == null
                  ? null
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          item.value!,
                          style: context.dsText.caption.semibold.tint(
                            palette.primary,
                          ),
                        ),
                        Icon(
                          Icons.chevron_right_rounded,
                          size: DsSizes.iconSm,
                          color: palette.gold,
                        ),
                      ],
                    ),
            ),
          ),
      ],
    );
  }
}
