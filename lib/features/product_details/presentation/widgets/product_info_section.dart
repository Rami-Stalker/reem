import 'package:flutter/material.dart';

import '../../../../core/design_system/design_system.dart';
import 'interactive_reaction_bar.dart';
import 'luxury_rating_bar.dart';

class ProductInfoSection extends StatelessWidget {
  const ProductInfoSection({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.dsColors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Dresses · New in',
          style: TextStyle(
            color: colors.onSurfaceVariant,
            fontSize: DsTypography.bodyMedium,
          ),
        ),
        const SizedBox(height: DsSpacing.sm),
        DsGradientText(
          'Elegant Silk Midi Dress',
          style: TextStyle(
            fontFamily: DsTypography.fontFamily,
            fontSize: 30,
            fontWeight: DsTypography.bold,
          ),
        ),
        const SizedBox(height: DsSpacing.lg),
        const LuxuryRatingBar(),
        const SizedBox(height: DsSpacing.lg),
        const InteractiveReactionBar(),
      ],
    );
  }
}
