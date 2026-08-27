import 'dart:ui';

import 'package:flutter/material.dart';

import 'package:reem/core/design_system/design_system.dart';
import 'package:reem/features/product_details/presentation/widgets/animated_add_to_cart_button.dart';

class FloatingBuyBar extends StatelessWidget {
  const FloatingBuyBar({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.dsColors;
    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: DsBlur.heavy, sigmaY: DsBlur.heavy),
        child: Container(
          padding: const EdgeInsets.fromLTRB(
            DsSpacing.lg, DsSpacing.md, DsSpacing.lg, DsSpacing.xl,
          ),
          decoration: BoxDecoration(
            color: colors.surface.withValues(alpha: 0.92),
            border: Border(top: BorderSide(color: colors.border)),
            boxShadow: context.softShadow,
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Total',
                      style: TextStyle(
                        color: colors.onSurfaceVariant,
                        fontSize: DsTypography.labelMedium,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '\$240',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: DsTypography.bold,
                        color: colors.onSurface,
                      ),
                    ),
                  ],
                ),
              ),
              const AnimatedAddToCartButton(),
            ],
          ),
        ),
      ),
    );
  }
}
