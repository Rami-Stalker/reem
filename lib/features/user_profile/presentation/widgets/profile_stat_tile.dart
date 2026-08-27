import 'package:flutter/material.dart';

import 'package:reem/core/design_system/design_system.dart';

class ProfileStatTile extends StatelessWidget {
  const ProfileStatTile({
    super.key,
    required this.value,
    required this.label,
    this.onTap,
  });

  final String value;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.dsColors;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(DsRadius.md),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: DsSpacing.sm,
          vertical: DsSpacing.xs,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              value,
              style: TextStyle(
                fontFamily: DsTypography.fontFamily,
                fontSize: DsTypography.titleMedium,
                fontWeight: DsTypography.bold,
                color: colors.onSurface,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontFamily: DsTypography.fontFamily,
                fontSize: DsTypography.bodySmall,
                color: colors.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
