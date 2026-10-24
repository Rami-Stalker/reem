import 'package:flutter/material.dart';

import 'package:ohara/core/design_system/effects/glassmorphism/glass_container.dart';
import 'package:ohara/core/design_system/foundation/tokens/ds_radius.dart';
import 'package:ohara/core/design_system/foundation/tokens/ds_spacing.dart';

class DsGlassCard extends StatelessWidget {
  const DsGlassCard({
    super.key,
    required this.child,
    this.padding = DsSpacing.paddingLg,
    this.borderRadius = DsRadius.xxxl,
    this.onTap,
  });

  final Widget child;
  final EdgeInsets padding;
  final double borderRadius;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final card = GlassContainer(
      borderRadius: borderRadius,
      padding: padding,
      child: child,
    );

    if (onTap == null) return card;
    return GestureDetector(onTap: onTap, child: card);
  }
}
