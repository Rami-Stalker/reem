import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../../core/design_system/design_system.dart';

class SettingsProfileHeader extends StatelessWidget {
  const SettingsProfileHeader({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.dsColors;
    return Padding(
      padding: const EdgeInsets.only(top: 100, bottom: DsSpacing.lg),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: context.storyRingGradient,
              boxShadow: context.luxuryShadow,
            ),
            child: CircleAvatar(
              radius: 50,
              backgroundColor: colors.surface,
              backgroundImage: const NetworkImage(
                'https://images.unsplash.com/photo-1494790108377-be9c29b29330',
              ),
            ),
          ).animate().scale(duration: 600.ms, curve: Curves.easeOutBack),
          const SizedBox(height: DsSpacing.md),
          DsGradientText(
            'Lujain',
            style: TextStyle(
              fontFamily: DsTypography.fontFamily,
              fontSize: 28,
              fontWeight: DsTypography.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'lujain@reem.shop',
            style: TextStyle(color: colors.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}
