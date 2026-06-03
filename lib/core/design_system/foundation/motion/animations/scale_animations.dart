import 'package:flutter/material.dart';

import '../../tokens/ds_motion.dart';
import '../curves/ds_curves.dart';

abstract final class DsScaleAnimations {
  static Widget tapScale({
    required Widget child,
    required VoidCallback onTap,
    double pressedScale = 0.95,
  }) {
    return _TapScale(
      pressedScale: pressedScale,
      onTap: onTap,
      child: child,
    );
  }
}

class _TapScale extends StatefulWidget {
  const _TapScale({
    required this.child,
    required this.onTap,
    required this.pressedScale,
  });

  final Widget child;
  final VoidCallback onTap;
  final double pressedScale;

  @override
  State<_TapScale> createState() => _TapScaleState();
}

class _TapScaleState extends State<_TapScale> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _pressed ? widget.pressedScale : 1,
        duration: DsMotion.fast,
        curve: DsCurves.emphasized,
        child: widget.child,
      ),
    );
  }
}
