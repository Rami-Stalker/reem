import 'package:flutter/material.dart';
import 'package:ohara/core/design_system/foundation/theme/extensions/color_extension.dart';
import 'package:ohara/core/design_system/foundation/tokens/ds_colors.dart';

/// A round gradient action button.
///
/// Nothing uses this yet. That is precisely why [tooltip] is **required**: an
/// icon has no text of its own, and a `GestureDetector` around one announces
/// as nothing at all to a screen reader — so the first screen that reaches for
/// this would have shipped a control a blind customer cannot find. A required
/// parameter is the only version of that rule which survives contact with a
/// deadline.
class GradientIconButton
    extends StatefulWidget {
  final IconData icon;
  final VoidCallback onTap;

  /// What the tap does, read aloud. Required — see the class comment.
  final String tooltip;

  const GradientIconButton({
    super.key,
    required this.icon,
    required this.onTap,
    required this.tooltip,
  });

  @override
  State<GradientIconButton>
      createState() =>
          _GradientIconButtonState();
}

class _GradientIconButtonState
    extends State<GradientIconButton> {
  bool pressed = false;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: widget.tooltip,
      child: GestureDetector(
      onTapDown: (_) {
        setState(() {
          pressed = true;
        });
      },

      onTapUp: (_) {
        setState(() {
          pressed = false;
        });

        widget.onTap();
      },

      child: AnimatedScale(
        scale: pressed ? .90 : 1,

        duration:
            const Duration(
                milliseconds: 180),

        child: Container(
          width: 56,
          height: 56,

          decoration: BoxDecoration(
            shape: BoxShape.circle,

            gradient:
                const LinearGradient(
              colors: [
                DsColors.primary300,
                DsColors.primary500,
              ],
            ),

            boxShadow: [
              BoxShadow(
                color: context.dsColors.primary.withValues(alpha: .25),
                blurRadius: 25,
                spreadRadius: 2,
              ),
            ],
          ),

            child: Icon(
              widget.icon,
              color: DsColors.onMedia,
            ),
          ),
        ),
      ),
    );
  }
}