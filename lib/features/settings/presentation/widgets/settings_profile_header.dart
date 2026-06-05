import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:reem/core/shared/wedgets/app/app_avatar.dart';
import '../../../../core/design_system/design_system.dart';

class SettingsProfileHeader extends StatelessWidget {
  const SettingsProfileHeader({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.dsColors;
    return Padding(
      padding: const EdgeInsets.only(top: DsSpacing.huge, bottom: DsSpacing.lg),
      child: Column(
        children: [
          AppAvatar(radius: 58).animate().scale(duration: 600.ms, curve: Curves.easeOutBack),
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
