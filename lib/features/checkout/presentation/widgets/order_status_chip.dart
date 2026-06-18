import 'package:flutter/material.dart';

import '../../../../core/design_system/design_system.dart';

String humanizeStatus(String status) => status
    .split('_')
    .map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}')
    .join(' ');

class OrderStatusChip extends StatelessWidget {
  const OrderStatusChip({super.key, required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final colors = context.dsColors;
    final color = switch (status) {
      'delivered' => colors.success,
      'paid' || 'shipped' => colors.info,
      'processing' => colors.primary,
      'pending_payment' => colors.warning,
      'cancelled' => colors.error,
      'refunded' => colors.onSurfaceVariant,
      _ => colors.onSurfaceVariant,
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: DsSpacing.sm, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(DsRadius.full),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        humanizeStatus(status),
        style: TextStyle(
          fontFamily: DsTypography.fontFamily,
          fontSize: DsTypography.bodySmall,
          fontWeight: DsTypography.semiBold,
          color: color,
        ),
      ),
    );
  }
}
