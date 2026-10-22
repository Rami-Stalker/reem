import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:reem/core/design_system/foundation/theme/extensions/color_extension.dart';
import 'package:reem/core/design_system/foundation/theme/extensions/gradient_extension.dart';
import 'package:reem/core/design_system/foundation/theme/extensions/typography_extension.dart';
import 'package:reem/core/design_system/foundation/tokens/ds_colors.dart';
import 'package:reem/core/design_system/foundation/tokens/ds_gaps.dart';
import 'package:reem/core/design_system/foundation/tokens/ds_motion.dart';
import 'package:reem/core/design_system/foundation/tokens/ds_sizes.dart';

/// A soft, gradient-swept circular loader — the Reem signature spinner.
///
/// One spinner for the whole app: a page loading, a section loading and a
/// button busy with a request all turn the same way. [color] sweeps the
/// same shape in a single tint, for the places the brand gradient would
/// vanish into — a rose button, a plum card, a photograph.
class DsLoadingIndicator extends StatefulWidget {
  const DsLoadingIndicator({
    super.key,
    this.size = DsSizes.iconLg,
    this.strokeWidth = 3.5,
    this.label,
    this.color,
  }) : _inline = false;

  /// The size that sits inside a button or beside a line of text.
  const DsLoadingIndicator.inline({super.key, this.color})
    : size = DsSizes.iconXs,
      strokeWidth = 2,
      label = null,
      _inline = true;

  final double size;
  final double strokeWidth;
  final String? label;

  /// A single tint instead of the brand gradient.
  final Color? color;

  /// An inline spinner keeps its own size. A page spinner centres itself in
  /// the space it is given — which inside a button would stretch the button
  /// to the full width of its row.
  final bool _inline;

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
          colors: switch (widget.color) {
            final tint? => [tint.withValues(alpha: 0.0), tint, tint],
            null => [
              gradient.colors.last.withValues(alpha: 0.0),
              gradient.colors.first,
              gradient.colors.last,
            ],
          },
          stops: const [0.0, 0.7, 1.0],
          transform: const GradientRotation(-math.pi / 2),
        ).createShader(rect),
        child: SizedBox(
          width: widget.size,
          height: widget.size,
          child: CircularProgressIndicator(
            strokeWidth: widget.strokeWidth,
            strokeCap: StrokeCap.round,
            valueColor: const AlwaysStoppedAnimation(DsColors.onMedia),
          ),
        ),
      ),
    );

    if (widget.label == null) {
      return widget._inline ? indicator : Center(child: indicator);
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        indicator,
        DsGaps.vSm,
        Text(widget.label!, style: context.dsText.cardSubtitle),
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
        child: DsLoadingIndicator(label: label, size: DsSizes.iconXl),
      ),
    );
  }
}
