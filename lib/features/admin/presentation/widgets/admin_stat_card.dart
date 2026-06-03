import 'package:flutter/material.dart';

import '../../../../core/design_system/design_system.dart';

class AdminStatCard extends StatelessWidget {
  const AdminStatCard({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    this.trend,
    this.trendUp = true,
  });

  final String label;
  final String value;
  final IconData icon;
  final String? trend;
  final bool trendUp;

  @override
  Widget build(BuildContext context) {
    final colors = context.dsColors;
    return Container(
      padding: const EdgeInsets.all(DsSpacing.lg),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: DsRadius.borderLg,
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(DsSpacing.sm),
                decoration: BoxDecoration(
                  color: colors.primary.withValues(alpha: 0.1),
                  borderRadius: DsRadius.borderMd,
                ),
                child: Icon(icon, color: colors.primary, size: 22),
              ),
              const Spacer(),
              if (trend != null)
                Row(
                  children: [
                    Icon(
                      trendUp ? Icons.trending_up : Icons.trending_down,
                      size: 16,
                      color: trendUp ? colors.success : colors.error,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      trend!,
                      style: TextStyle(
                        fontSize: DsTypography.labelSmall,
                        fontWeight: DsTypography.semiBold,
                        color: trendUp ? colors.success : colors.error,
                      ),
                    ),
                  ],
                ),
            ],
          ),
          const SizedBox(height: DsSpacing.md),
          Text(
            value,
            style: TextStyle(
              fontSize: DsTypography.headlineSmall,
              fontWeight: DsTypography.bold,
              color: colors.onSurface,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: DsTypography.bodySmall,
              color: colors.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
