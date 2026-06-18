import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../foundation/theme/extensions/color_extension.dart';
import '../../foundation/theme/extensions/gradient_extension.dart';
import '../../foundation/tokens/ds_motion.dart';
import '../../foundation/tokens/ds_spacing.dart';
import '../../foundation/tokens/ds_typography.dart';

/// A soft, gradient-swept circular loader — the Reem signature spinner.
class DsLoadingIndicator extends StatefulWidget {
  const DsLoadingIndicator({
    super.key,
    this.size = 32,
    this.strokeWidth = 3.5,
    this.label,
  });

  final double size;
  final double strokeWidth;
  final String? label;

  @override
  State<DsLoadingIndicator> createState() => _DsLoadingIndicatorState();
}

class _DsLoadingIndicatorState extends State<DsLoadingIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller =
      AnimationController(vsync: this, duration: DsMotion.slowest)..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final gradient = context.primaryGradient;
    final indicator = RotationTransition(
      turns: _controller,
      child: ShaderMask(
        shaderCallback: (rect) => SweepGradient(
          colors: [
            gradient.colors.last.withValues(alpha: 0.0),
            gradient.colors.first,
            gradient.colors.last,
          ],
          stops: const [0.0, 0.7, 1.0],
          transform: const GradientRotation(-math.pi / 2),
        ).createShader(rect),
        child: SizedBox(
          width: widget.size,
          height: widget.size,
          child: CircularProgressIndicator(
            strokeWidth: widget.strokeWidth,
            strokeCap: StrokeCap.round,
            valueColor: const AlwaysStoppedAnimation(Colors.white),
          ),
        ),
      ),
    );

    if (widget.label == null) return Center(child: indicator);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        indicator,
        const SizedBox(height: DsSpacing.sm),
        Text(
          widget.label!,
          style: TextStyle(
            fontFamily: DsTypography.fontFamily,
            fontSize: DsTypography.bodySmall,
            color: context.dsColors.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

/// Full-bleed blocking overlay with a centered [DsLoadingIndicator].
class DsLoadingOverlay extends StatelessWidget {
  const DsLoadingOverlay({super.key, this.label, this.visible = true});

  final String? label;
  final bool visible;

  @override
  Widget build(BuildContext context) {
    if (!visible) return const SizedBox.shrink();
    final c = context.dsColors;
    return Positioned.fill(
      child: ColoredBox(
        color: c.overlay,
        child: DsLoadingIndicator(label: label, size: 40),
      ),
    );
  }
}
