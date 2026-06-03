import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

import '../../foundation/theme/extensions/color_extension.dart';
import '../../foundation/tokens/ds_radius.dart';

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
    final base = context.dsColors.surfaceVariant;
    final highlight = context.dsColors.surface;

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
