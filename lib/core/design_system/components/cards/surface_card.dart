import 'package:flutter/material.dart';

import '../../foundation/theme/extensions/color_extension.dart';
import '../../foundation/theme/extensions/shadow_extension.dart';
import '../../foundation/tokens/ds_radius.dart';
import '../../foundation/tokens/ds_spacing.dart';

class SurfaceCard extends StatelessWidget {
  const SurfaceCard({
    super.key,
    required this.child,
    this.padding = DsSpacing.paddingLg,
    this.onTap,
    this.useLuxuryShadow = true,
  });

  final Widget child;
  final EdgeInsets padding;
  final VoidCallback? onTap;
  final bool useLuxuryShadow;

  @override
  Widget build(BuildContext context) {
    final card = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: context.dsColors.card,
        borderRadius: DsRadius.borderXl,
        border: Border.all(
          color: context.dsColors.border.withValues(alpha: 0.4),
        ),
        boxShadow: useLuxuryShadow ? context.softShadow : null,
      ),
      child: child,
    );

    if (onTap == null) return card;
    return InkWell(
      onTap: onTap,
      borderRadius: DsRadius.borderXl,
      child: card,
    );
  }
}
