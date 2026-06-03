import 'dart:ui';

import 'package:flutter/material.dart';

class BlurOverlay
    extends StatelessWidget {
  final Widget child;

  const BlurOverlay({
    super.key,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(
          sigmaX: 12,
          sigmaY: 12,
        ),

        child: child,
      ),
    );
  }
}