import 'package:flutter/material.dart';
import 'package:reem/core/design_system/foundation/theme/extensions/color_extension.dart';
import 'package:reem/core/design_system/foundation/tokens/ds_radius.dart';
import 'package:shimmer/shimmer.dart';

class DsShimmerLoader extends StatelessWidget {
  const DsShimmerLoader({
    super.key,
    this.width,
    this.height = 16,
    this.borderRadius = DsRadius.md,
  });

  final double? width;
  final double height;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    final base = context.dsColors.shimmerBase;
    final highlight = context.dsColors.shimmerHighlight;

    return Shimmer.fromColors(
      baseColor: base,
      highlightColor: highlight,
      child: Container(
        width: width ?? double.infinity,
        height: height,
        decoration: BoxDecoration(
          color: base,
          borderRadius: BorderRadius.circular(borderRadius),
        ),
      ),
    );
  }
}
