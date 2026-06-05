import 'package:flutter/material.dart';

import '../../../../core/design_system/design_system.dart';

class LuxuryHighlights extends StatelessWidget {
  const LuxuryHighlights({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 100,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: DsSpacing.lg),
        itemCount: 5,
        separatorBuilder: (_, _) => const SizedBox(width: DsSpacing.md),
        itemBuilder: (context, index) {
          return Container(
            width: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: context.primaryGradient,
              boxShadow: context.softShadow,
              border: Border.all(
                color: context.dsColors.glassBorder,
                width: 2,
              ),
            ),
            child: Icon(
              Icons.add,
              color: context.dsColors.onPrimary,
            ),
          );
        },
      ),
    );
  }
}
