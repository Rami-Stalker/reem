import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../../core/design_system/design_system.dart';

class CategoryCard extends StatelessWidget {
  const CategoryCard({
    super.key,
    required this.title,
    required this.icon,
    this.gradient,
  });

  final String title;
  final IconData icon;
  final Gradient? gradient;

  @override
  Widget build(BuildContext context) {
    final colors = context.dsColors;
    return Container(
      width: 100,
      decoration: BoxDecoration(
        borderRadius: DsRadius.borderXxl,
        color: colors.surface.withValues(alpha: 0.9),
        border: Border.all(color: colors.glassBorder),
        boxShadow: context.softShadow,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: gradient ?? context.primaryGradient,
            ),
            child: Icon(icon, color: colors.onPrimary, size: 26),
          ),
          const SizedBox(height: DsSpacing.sm),
          Text(
            title,
            style: TextStyle(
              fontWeight: DsTypography.semiBold,
              fontSize: DsTypography.labelLarge,
              color: colors.onSurface,
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 500.ms).slideY(begin: 0.15);
  }
}
