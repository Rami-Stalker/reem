import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:reem/core/design_system/design_system.dart';

/// The tiny trend line that rides inside a metric card.
///
/// The full analytics chart that used to live here was a hand-rolled painter
/// with no axes and nothing to touch; it now lives in `seller_sales_chart.dart`
/// built on `fl_chart`. What remains is the sparkline — deliberately still a
/// painter, because a 90x42 glyph with no labels and no interaction has no use
/// for a charting library.

class MiniSparkline extends StatelessWidget {
  const MiniSparkline({
    super.key,
    required this.values,
    this.color,
    this.height = 32,
    this.width = 64,
  });

  final List<double> values;
  final Color? color;
  final double height;
  final double width;

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    return CustomPaint(
      size: Size(width, height),
      painter: _SparklinePainter(
        values: values,
        color: color ?? c.primary,
      ),
    );
  }
}

class _SparklinePainter extends CustomPainter {
  const _SparklinePainter({required this.values, required this.color});

  final List<double> values;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.length < 2) return;

    final max = values.reduce(math.max);
    final min = values.reduce(math.min);
    final range = (max - min).clamp(1.0, double.infinity);

    Offset pos(int i) => Offset(
          i / (values.length - 1) * size.width,
          size.height - ((values[i] - min) / range) * size.height * 0.8 - size.height * 0.1,
        );

    final path = Path();
    final offsets = List.generate(values.length, pos);
    path.moveTo(offsets[0].dx, offsets[0].dy);
    for (var i = 0; i < offsets.length - 1; i++) {
      final cp1 = Offset(offsets[i].dx + (offsets[i + 1].dx - offsets[i].dx) / 2, offsets[i].dy);
      final cp2 = Offset(offsets[i].dx + (offsets[i + 1].dx - offsets[i].dx) / 2, offsets[i + 1].dy);
      path.cubicTo(cp1.dx, cp1.dy, cp2.dx, cp2.dy, offsets[i + 1].dx, offsets[i + 1].dy);
    }

    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_SparklinePainter old) => old.values != values;
}
