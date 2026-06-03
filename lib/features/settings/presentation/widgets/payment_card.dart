import 'dart:ui';

import 'package:flutter/material.dart';

import '../../../../core/design_system/design_system.dart';

class PaymentCard extends StatelessWidget {
  const PaymentCard({super.key, required this.index});

  final int index;

  @override
  Widget build(BuildContext context) {
    final colors = context.dsColors;
    return ClipRRect(
      borderRadius: DsRadius.borderXxxl,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: DsBlur.medium, sigmaY: DsBlur.medium),
        child: Container(
          padding: const EdgeInsets.all(DsSpacing.xl),
          decoration: BoxDecoration(
            gradient: index == 0
                ? context.primaryGradient
                : context.ds.glassGradient,
            borderRadius: DsRadius.borderXxxl,
            border: Border.all(color: colors.glassBorder),
            boxShadow: context.luxuryShadow,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.credit_card_rounded,
                    size: 32,
                    color: index == 0 ? colors.onPrimary : colors.onSurface,
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: (index == 0 ? colors.onPrimary : colors.success)
                          .withValues(alpha: 0.2),
                      borderRadius: DsRadius.borderFull,
                    ),
                    child: Text(
                      'Active',
                      style: TextStyle(
                        color: index == 0 ? colors.onPrimary : colors.success,
                        fontWeight: DsTypography.bold,
                        fontSize: DsTypography.labelSmall,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: DsSpacing.xl),
              Text(
                '**** **** **** 482${index}',
                style: TextStyle(
                  fontSize: 22,
                  letterSpacing: 2,
                  fontWeight: DsTypography.bold,
                  color: index == 0 ? colors.onPrimary : colors.onSurface,
                ),
              ),
              const SizedBox(height: DsSpacing.lg),
              Row(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Card holder',
                        style: TextStyle(
                          color: index == 0
                              ? colors.onPrimary.withValues(alpha: 0.8)
                              : colors.onSurfaceVariant,
                          fontSize: DsTypography.labelSmall,
                        ),
                      ),
                      Text(
                        'Lujain Beauty',
                        style: TextStyle(
                          fontWeight: DsTypography.bold,
                          color: index == 0 ? colors.onPrimary : colors.onSurface,
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Expires',
                        style: TextStyle(
                          color: index == 0
                              ? colors.onPrimary.withValues(alpha: 0.8)
                              : colors.onSurfaceVariant,
                          fontSize: DsTypography.labelSmall,
                        ),
                      ),
                      Text(
                        '09/28',
                        style: TextStyle(
                          fontWeight: DsTypography.bold,
                          color: index == 0 ? colors.onPrimary : colors.onSurface,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
