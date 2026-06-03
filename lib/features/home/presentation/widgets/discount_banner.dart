import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../../core/design_system/design_system.dart';

class DiscountBanner extends StatelessWidget {
  const DiscountBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.dsColors;
    return Container(
      decoration: BoxDecoration(
        borderRadius: DsRadius.borderXxxl,
        gradient: DsGradients.sunset,
        boxShadow: context.luxuryShadow,
      ),
      child: Stack(
        children: [
          Positioned(
            right: -40,
            top: -40,
            child: Icon(
              Icons.spa_rounded,
              size: 140,
              color: colors.onPrimary.withValues(alpha: 0.12),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(DsSpacing.xl),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: colors.onPrimary.withValues(alpha: 0.22),
                    borderRadius: DsRadius.borderFull,
                  ),
                  child: Text(
                    'Limited time',
                    style: TextStyle(
                      color: colors.onPrimary,
                      fontWeight: DsTypography.semiBold,
                      fontSize: DsTypography.labelSmall,
                    ),
                  ),
                ),
                const SizedBox(height: DsSpacing.md),
                Text(
                  'Summer Glow Sale',
                  style: TextStyle(
                    fontFamily: DsTypography.fontFamily,
                    color: colors.onPrimary,
                    fontSize: 28,
                    fontWeight: DsTypography.bold,
                  ),
                ),
                const SizedBox(height: DsSpacing.sm),
                Text(
                  'Up to 70% off dresses, accessories & gifts',
                  style: TextStyle(
                    color: colors.onPrimary.withValues(alpha: 0.92),
                    fontSize: DsTypography.bodyMedium,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: DsSpacing.lg),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: DsSpacing.xl,
                    vertical: DsSpacing.sm,
                  ),
                  decoration: BoxDecoration(
                    color: colors.onPrimary,
                    borderRadius: DsRadius.borderFull,
                    boxShadow: context.softShadow,
                  ),
                  child: Text(
                    'Shop the sale',
                    style: TextStyle(
                      color: colors.primary,
                      fontWeight: DsTypography.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 700.ms).slideY(begin: 0.12);
  }
}
