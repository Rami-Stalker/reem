import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/design_system/design_system.dart';
import '../../../../core/router/route_names.dart';
import '../../../../core/localization/l10n_extension.dart';

class RewardsPointsCard extends StatelessWidget {
  const RewardsPointsCard({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.dsColors;
    return GestureDetector(
      onTap: () => context.pushNamed(RouteNames.rewards),
      child: Container(
        padding: const EdgeInsets.all(DsSpacing.lg),
        decoration: BoxDecoration(
          gradient: context.rewardsGradient,
          borderRadius: DsRadius.borderXxl,
          boxShadow: context.luxuryShadow,
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: colors.onPrimary.withValues(alpha: 0.25),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.stars_rounded, color: colors.onPrimary, size: 28),
            ),
            const SizedBox(width: DsSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '2,450 Points',
                    style: TextStyle(
                      fontFamily: DsTypography.fontFamily,
                      fontSize: DsTypography.titleLarge,
                      fontWeight: DsTypography.bold,
                      color: colors.onPrimary,
                    ),
                  ),
                  Text(
                    context.l10n.homeLoyaltySubtitle,
                    style: TextStyle(
                      color: colors.onPrimary.withValues(alpha: 0.9),
                      fontSize: DsTypography.bodySmall,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: colors.onPrimary,
                borderRadius: DsRadius.borderFull,
              ),
              child: Text(
                context.l10n.redeem,
                style: TextStyle(
                  color: colors.primary,
                  fontWeight: DsTypography.bold,
                  fontSize: DsTypography.labelMedium,
                ),
              ),
            ),
          ],
        ),
      ),
    ).animate().fadeIn(duration: 600.ms).slideX(begin: -0.05);
  }
}
