import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:reem/core/design_system/design_system.dart';
import 'package:reem/features/trends/presentation/widgets/trend_chrome.dart';

/// The two chart primitives: a sparkline for glancing at, and a share
/// bar for comparing a facet against where it was a window ago.

// ── Sparkline ────────────────────────────────────────────────────────────

/// A bare line, no axes, no grid.
///
/// Deliberately not a chart: this sits inside a header beside a number, and
/// its job is to say "up, and lately" in the width of a thumb. Anything that
/// needs reading rather than glancing gets a real chart further down the page.
class TrendSparkline extends StatelessWidget {
  const TrendSparkline({
    super.key,
    required this.values,
    required this.colour,
    this.height = 40,
  });

  final List<double> values;
  final Color colour;
  final double height;

  @override
  Widget build(BuildContext context) {
    if (values.length < 2) return SizedBox(height: height);
    return SizedBox(
      height: height,
      child: CustomPaint(
        painter: _SparklinePainter(values: values, colour: colour),
        size: Size.infinite,
      ),
    );
  }
}

class _SparklinePainter extends CustomPainter {
  const _SparklinePainter({required this.values, required this.colour});

  final List<double> values;
  final Color colour;

  @override
  void paint(Canvas canvas, Size size) {
    final max = values.reduce(math.max);
    final min = values.reduce(math.min);
    // A flat series would otherwise divide by zero and vanish; drawn along the
    // middle instead, which is what "flat" looks like.
    final span = (max - min).abs() < 1e-9 ? 1.0 : max - min;

    final path = Path();
    final fill = Path();
    for (var i = 0; i < values.length; i += 1) {
      final x = size.width * (i / (values.length - 1));
      final y = size.height - ((values[i] - min) / span) * size.height * 0.9;
      if (i == 0) {
        path.moveTo(x, y);
        fill.moveTo(x, size.height);
        fill.lineTo(x, y);
      } else {
        path.lineTo(x, y);
        fill.lineTo(x, y);
      }
    }
    fill
      ..lineTo(size.width, size.height)
      ..close();

    canvas.drawPath(
      fill,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [colour.withValues(alpha: 0.22), colour.withValues(alpha: 0)],
        ).createShader(Offset.zero & size),
    );
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = colour,
    );
  }

  @override
  bool shouldRepaint(_SparklinePainter old) =>
      old.values != values || old.colour != colour;
}

// ── Share bars ───────────────────────────────────────────────────────────

/// A facet's share of demand, now against a window ago.
///
/// Two bars rather than one with an arrow: the question a buyer is asking is
/// "did this take share from something else", and the honest way to show that
/// is to put the two proportions next to each other and let the eye do the
/// subtraction.
class TrendShareBar extends StatelessWidget {
  const TrendShareBar({
    super.key,
    required this.label,
    required this.sharePct,
    required this.previousSharePct,
    required this.colour,
    this.trailing,
  });

  final String label;
  final double sharePct;
  final double previousSharePct;
  final Color colour;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final palette = context.atelier;
    final delta = sharePct - previousSharePct;
    final peak = math.max(math.max(sharePct, previousSharePct), 1);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: DsSpacing.xs),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: colour,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: DsSpacing.xs),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.dsText.labelMedium.semibold.tint(palette.ink),
                ),
              ),
              Text(
                '${sharePct.toStringAsFixed(1)}٪',
                style: context.dsText.labelMedium.bold.tint(palette.ink),
              ),
              const SizedBox(width: DsSpacing.xs),
              TrendDelta(
                value: delta,
                suffix: 'ن',
                fontSize: DsTypography.labelSmall,
              ),
              if (trailing != null) ...[
                const SizedBox(width: DsSpacing.xs),
                trailing!,
              ],
            ],
          ),
          const SizedBox(height: DsSpacing.xs),
          // The faint bar behind is where this facet was a window ago.
          Stack(
            children: [
              _Bar(
                fraction: previousSharePct / peak,
                colour: palette.line,
                height: 8,
              ),
              _Bar(fraction: sharePct / peak, colour: colour, height: 8),
            ],
          ),
        ],
      ),
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar({
    required this.fraction,
    required this.colour,
    required this.height,
  });

  final double fraction;
  final Color colour;
  final double height;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => Container(
        width: constraints.maxWidth * fraction.clamp(0.0, 1.0),
        height: height,
        decoration: BoxDecoration(
          color: colour,
          borderRadius: BorderRadius.circular(height / 2),
        ),
      ),
    );
  }
}
