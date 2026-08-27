import 'package:flutter/material.dart';

import 'package:reem/features/settings/presentation/widgets/settings_tile.dart';

class SettingsItemData {
  const SettingsItemData({
    required this.icon,
    required this.title,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final VoidCallback? onTap;
}

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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsetsDirectional.only(bottom: 18, start: 8),
          child: Text(
            title,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
        ),
        ...items.map(
          (item) => Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: LuxurySettingsTile(
              icon: item.icon,
              title: item.title,
              onTap: item.onTap,
            ),
          ),
        ),
      ],
    );
  }
}
