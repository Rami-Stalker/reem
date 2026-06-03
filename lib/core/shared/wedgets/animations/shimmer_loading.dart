import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

class ShimmerLoading
    extends StatelessWidget {
  final double height;
  final double width;
  final double radius;

  const ShimmerLoading({
    super.key,
    required this.height,
    required this.width,
    this.radius = 20,
  });

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: Colors.grey.shade300,
      highlightColor:
          Colors.grey.shade100,

      child: Container(
        width: width,
        height: height,

        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius:
              BorderRadius.circular(
                  radius),
        ),
      ),
    );
  }
}