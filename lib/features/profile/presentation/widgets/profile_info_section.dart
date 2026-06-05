import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../../core/design_system/design_system.dart';
// import 'luxury_avatar.dart';
import 'luxury_highlights.dart';
import 'premium_actions.dart';
import 'premium_stats.dart';

class ProfileInfoSection extends StatelessWidget {
  const ProfileInfoSection({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.dsColors;
    return Column(
      children: [
        // const SizedBox(height: DsSpacing.md),
        // const LuxuryAvatar(),
        const SizedBox(height: DsSpacing.lg),
        DsGradientText(
          'Lujain Beauty',
          style: TextStyle(
            fontFamily: DsTypography.fontFamily,
            fontSize: 30,
            fontWeight: DsTypography.bold,
          ),
        ).animate().fadeIn(duration: 600.ms).slideY(begin: 0.15),
        const SizedBox(height: DsSpacing.sm),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: Text(
            'Fashion • Beauty • Gifts ✨\nSharing my favorite finds with you.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: colors.onSurfaceVariant,
                  height: 1.6,
                ),
          ),
        ).animate().fadeIn(delay: 150.ms),
        const SizedBox(height: DsSpacing.xxl),
        const PremiumStats(),
        const SizedBox(height: DsSpacing.xxl),
        const PremiumActions(),
        const SizedBox(height: DsSpacing.xxl),
        const LuxuryHighlights(),
        const SizedBox(height: DsSpacing.xl),
      ],
    );
  }
}
