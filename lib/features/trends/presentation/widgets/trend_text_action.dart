import 'package:flutter/material.dart';

import 'package:ohara/core/design_system/design_system.dart';

/// A compact icon-and-label affordance.
///
/// Shared by the insight card and the unmet-demand card rather than
/// duplicated: they sit next to each other on the admin page, and two
/// copies would drift in padding within a release.
class TrendTextAction extends StatelessWidget {
  const TrendTextAction({
    super.key,
    required this.label,
    required this.icon,
    required this.onTap,
    this.tone,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final Color? tone;

  @override
  Widget build(BuildContext context) {
    final palette = context.atelier;
    final colour = tone ?? palette.primary;
    return InkWell(
      borderRadius: DsRadius.borderSm,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: DsSpacing.xs,
          vertical: DsSpacing.xxxs,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: colour),
            DsGaps.hXxs,
            Text(
              label,
              style: context.dsText.caption.semibold.tint(colour),
            ),
          ],
        ),
      ),
    );
  }
}
