import 'package:flutter/material.dart';
import 'package:ohara/core/design_system/foundation/motion/curves/ds_curves.dart';
import 'package:ohara/core/design_system/foundation/tokens/ds_motion.dart';

abstract final class DsScaleAnimations {
  /// The app's one pressable surface: a tap that dips the widget slightly and
  /// springs back.
  ///
  /// It is also where accessibility enters the design system. Nearly every
  /// tappable thing in the app — buttons, icon buttons, cards, story bubbles —
  /// arrives here, and it used to be a bare `GestureDetector`, which announces
  /// nothing. A screen reader met a product card as an unlabelled box.
  ///
  /// So the wrapper declares what it is. [semanticLabel] names the control;
  /// omitting it means the child already carries its own text, which the
  /// framework will read.
  static Widget tapScale({
    required Widget child,
    required VoidCallback onTap,
    double pressedScale = 0.95,
    String? semanticLabel,
    bool enabled = true,

    /// True for a control whose child is decorative — an icon with no text.
    /// The label then replaces the subtree rather than being read before it.
    bool excludeChildSemantics = false,
  }) {
    return _TapScale(
      pressedScale: pressedScale,
      onTap: onTap,
      semanticLabel: semanticLabel,
      enabled: enabled,
      excludeChildSemantics: excludeChildSemantics,
      child: child,
    );
  }
}

class _TapScale extends StatefulWidget {
  const _TapScale({
    required this.child,
    required this.onTap,
    required this.pressedScale,
    required this.enabled,
    required this.excludeChildSemantics,
    this.semanticLabel,
  });

  final Widget child;
  final VoidCallback onTap;
  final double pressedScale;
  final String? semanticLabel;
  final bool enabled;
  final bool excludeChildSemantics;

  @override
  State<_TapScale> createState() => _TapScaleState();
}

class _TapScaleState extends State<_TapScale> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed == value) return;
    setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final press = GestureDetector(
      onTapDown: widget.enabled ? (_) => _setPressed(true) : null,
      onTapUp: widget.enabled ? (_) => _setPressed(false) : null,
      onTapCancel: widget.enabled ? () => _setPressed(false) : null,
      onTap: widget.enabled ? widget.onTap : null,
      child: AnimatedScale(
        scale: _pressed ? widget.pressedScale : 1,
        duration: DsMotion.fast,
        curve: DsCurves.emphasized,
        child: widget.child,
      ),
    );

    return Semantics(
      button: true,
      enabled: widget.enabled,
      label: widget.semanticLabel,
      excludeSemantics: widget.excludeChildSemantics,
      // Gives the gesture a name in the accessibility tree, so TalkBack
      // announces "double tap to activate" rather than leaving a silent box.
      onTap: widget.enabled ? widget.onTap : null,
      child: press,
    );
  }
}
