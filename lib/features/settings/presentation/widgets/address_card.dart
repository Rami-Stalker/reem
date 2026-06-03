import 'dart:ui';

import 'package:flutter/material.dart';

import '../../../../core/design_system/design_system.dart';

class AddressCard extends StatelessWidget {
  const AddressCard({super.key, required this.index});

  final int index;

  @override
  Widget build(BuildContext context) {
    final colors = context.dsColors;
    return ClipRRect(
      borderRadius: DsRadius.borderXxxl,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: DsBlur.light, sigmaY: DsBlur.light),
        child: Container(
          padding: const EdgeInsets.all(DsSpacing.lg),
          decoration: BoxDecoration(
            gradient: context.ds.glassGradient,
            borderRadius: DsRadius.borderXxxl,
            border: Border.all(color: colors.glassBorder),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: colors.primary.withValues(alpha: 0.15),
                ),
                child: Icon(Icons.location_on_rounded, color: colors.primary),
              ),
              const SizedBox(width: DsSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      index == 0 ? 'Home' : 'Office',
                      style: TextStyle(
                        fontWeight: DsTypography.bold,
                        fontSize: DsTypography.titleSmall,
                        color: colors.onSurface,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '123 Rose Avenue, Beauty District',
                      style: TextStyle(
                        color: colors.onSurfaceVariant,
                        height: 1.4,
                      ),
                    ),
                    if (index == 0) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: colors.primary.withValues(alpha: 0.12),
                          borderRadius: DsRadius.borderFull,
                        ),
                        child: Text(
                          'Default',
                          style: TextStyle(
                            color: colors.primary,
                            fontSize: DsTypography.labelSmall,
                            fontWeight: DsTypography.semiBold,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Icon(Icons.edit_outlined, color: colors.onSurfaceVariant, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}
