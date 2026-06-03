import 'dart:ui';

import 'package:flutter/material.dart';

import '../../../../core/design_system/design_system.dart';

class OrderCard extends StatelessWidget {
  const OrderCard({super.key, required this.index});

  final int index;

  @override
  Widget build(BuildContext context) {
    final colors = context.dsColors;
    return ClipRRect(
      borderRadius: DsRadius.borderXxxl,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: DsBlur.light, sigmaY: DsBlur.light),
        child: Container(
          padding: const EdgeInsets.all(DsSpacing.md),
          decoration: BoxDecoration(
            gradient: context.ds.glassGradient,
            borderRadius: DsRadius.borderXxxl,
            border: Border.all(color: colors.glassBorder),
            boxShadow: context.softShadow,
          ),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: DsRadius.borderLg,
                child: Image.network(
                  'https://images.unsplash.com/photo-1515886657613-9f3515b0c78f?w=200&sig=$index',
                  width: 88,
                  height: 88,
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(width: DsSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Silk Evening Dress',
                      style: TextStyle(
                        fontSize: DsTypography.titleSmall,
                        fontWeight: DsTypography.bold,
                        color: colors.onSurface,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Order #${45870 + index}',
                      style: TextStyle(color: colors.onSurfaceVariant),
                    ),
                    const SizedBox(height: DsSpacing.sm),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: colors.success.withValues(alpha: 0.15),
                        borderRadius: DsRadius.borderFull,
                      ),
                      child: Text(
                        index.isEven ? 'Delivered' : 'In transit',
                        style: TextStyle(
                          color: colors.success,
                          fontWeight: DsTypography.semiBold,
                          fontSize: DsTypography.labelSmall,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
