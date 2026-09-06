import 'package:flutter/material.dart';

import 'package:reem/core/design_system/design_system.dart';

/// The count of unread messages on one conversation.
///
/// Caps at 99+: the difference between 140 and 200 unread is not a difference
/// she acts on, and an uncapped count stretches the row.
class UnreadBadge extends StatelessWidget {
  const UnreadBadge({super.key, required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    if (count <= 0) return const SizedBox.shrink();
    final c = context.dsColors;
    final label = count > 99 ? '99+' : '$count';

    return Container(
      constraints: const BoxConstraints(minWidth: DsSizes.iconMd),
      padding: DsSpacing.badgePadding,
      decoration: BoxDecoration(
        gradient: context.primaryGradient,
        borderRadius: DsRadius.borderFull,
        boxShadow: [
          BoxShadow(
            color: c.primary.withValues(alpha: 0.28),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: context.dsText.caption.copyWith(
              color: c.onPrimary,
              fontWeight: DsTypography.bold,
            ),
      ),
    );
  }
}
