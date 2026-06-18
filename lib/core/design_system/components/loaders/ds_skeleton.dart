import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

import '../../foundation/theme/extensions/color_extension.dart';
import '../../foundation/tokens/ds_motion.dart';
import '../../foundation/tokens/ds_radius.dart';

/// Wraps any subtree in a theme-aware shimmer sweep. Compose with [DsSkeleton]
/// blocks to build content-shaped placeholders.
///
/// ```dart
/// DsShimmer(child: Column(children: [DsSkeleton.line(width: 120), ...]))
/// ```
class DsShimmer extends StatelessWidget {
  const DsShimmer({super.key, required this.child, this.enabled = true});

  final Widget child;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    if (!enabled) return child;
    final c = context.dsColors;
    return Shimmer.fromColors(
      baseColor: c.shimmerBase,
      highlightColor: c.shimmerHighlight,
      period: DsMotion.slower,
      child: child,
    );
  }
}

/// A single placeholder block. Use inside a [DsShimmer].
class DsSkeleton extends StatelessWidget {
  const DsSkeleton({
    super.key,
    this.width,
    this.height = 16,
    this.borderRadius = DsRadius.sm,
    this.shape = BoxShape.rectangle,
  });

  /// Text-line shaped skeleton.
  const DsSkeleton.line({super.key, this.width, this.height = 12})
      : borderRadius = DsRadius.xs,
        shape = BoxShape.rectangle;

  /// Square/rectangular block (image, card).
  const DsSkeleton.box({
    super.key,
    this.width,
    this.height = 80,
    this.borderRadius = DsRadius.lg,
  }) : shape = BoxShape.rectangle;

  /// Circular block (avatar).
  const DsSkeleton.circle({super.key, required double size})
      : width = size,
        height = size,
        borderRadius = 0,
        shape = BoxShape.circle;

  final double? width;
  final double height;
  final double borderRadius;
  final BoxShape shape;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width ?? double.infinity,
      height: height,
      decoration: BoxDecoration(
        color: context.dsColors.shimmerBase,
        shape: shape,
        borderRadius:
            shape == BoxShape.circle ? null : BorderRadius.circular(borderRadius),
      ),
    );
  }
}
