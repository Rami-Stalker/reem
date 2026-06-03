import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../../core/design_system/design_system.dart';

class CouponsStrip extends StatelessWidget {
  const CouponsStrip({super.key});

  static const _coupons = [
    ('SUMMER20', '20% off'),
    ('GIFT50', '\$50 gifts'),
    ('VIP15', 'VIP 15%'),
    ('FREESHIP', 'Free ship'),
  ];

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _coupons.length,
        separatorBuilder: (_, __) => const SizedBox(width: DsSpacing.sm),
        itemBuilder: (context, index) {
          final (code, label) = _coupons[index];
          return _CouponChip(code: code, label: label, index: index);
        },
      ),
    );
  }
}

class _CouponChip extends StatelessWidget {
  const _CouponChip({
    required this.code,
    required this.label,
    required this.index,
  });

  final String code;
  final String label;
  final int index;

  @override
  Widget build(BuildContext context) {
    final colors = context.dsColors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: DsSpacing.md, vertical: DsSpacing.xs),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: DsRadius.borderFull,
        border: Border.all(color: colors.primary.withValues(alpha: 0.35)),
        boxShadow: context.softShadow,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.local_offer_rounded, size: 16, color: colors.primary),
          const SizedBox(width: 6),
          Text(
            code,
            style: TextStyle(
              fontWeight: DsTypography.bold,
              fontSize: DsTypography.labelMedium,
              color: colors.primary,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: DsTypography.labelSmall,
              color: colors.onSurfaceVariant,
            ),
          ),
        ],
      ),
    ).animate().fadeIn(delay: (80 * index).ms).slideX(begin: 0.1);
  }
}
