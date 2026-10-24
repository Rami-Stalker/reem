import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:ohara/core/design_system/design_system.dart';
import 'package:ohara/features/trends/domain/entities/trend_entities.dart';
import 'package:ohara/features/trends/presentation/widgets/trend_palette.dart';

// ── The score dial ───────────────────────────────────────────────────────

/// A Trend Score, drawn as an arc with its confidence around it.
///
/// The inner arc is the score; the faint outer ring is how much of it to
/// believe. Two products can both score 70 and mean completely different
/// things — one from four hundred views, one from nine — and a bare number
/// would present them as identical. Drawing confidence rather than printing it
/// means it is impossible to read the score without also reading it.
class TrendScoreDial extends StatelessWidget {
  const TrendScoreDial({
    super.key,
    required this.score,
    required this.confidence,
    required this.stage,
    this.size = 64,
  });

  final double score;
  final double confidence;
  final TrendStage stage;
  final double size;

  @override
  Widget build(BuildContext context) {
    final palette = context.atelier;
    final colour = stageColour(context, stage);

    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _DialPainter(
          score: score.clamp(0, 100) / 100,
          confidence: confidence.clamp(0, 1),
          colour: colour,
          track: palette.line,
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                score.round().toString(),
                style: context.dsText.hero
              .tint(palette.ink)
              .copyWith(fontSize: size * 0.34, height: 1),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DialPainter extends CustomPainter {
  const _DialPainter({
    required this.score,
    required this.confidence,
    required this.colour,
    required this.track,
  });

  final double score;
  final double confidence;
  final Color colour;
  final Color track;

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = size.width * 0.09;
    final outer = Rect.fromLTWH(
      stroke / 2,
      stroke / 2,
      size.width - stroke,
      size.height - stroke,
    );
    final inner = outer.deflate(stroke * 1.2);
    // Twelve o'clock, clockwise — the direction every dial on a dashboard is
    // read in, whatever the text direction around it.
    const start = -math.pi / 2;
    const sweep = math.pi * 2;

    final trackPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..color = track;

    canvas.drawArc(inner, start, sweep, false, trackPaint);
    canvas.drawArc(
      inner,
      start,
      sweep * score,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round
        ..color = colour,
    );

    // The confidence ring, outside and faint. Present even at zero, because an
    // absent ring and a short one must not look the same.
    canvas.drawArc(
      outer,
      start,
      sweep,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke * 0.45
        ..color = track.withValues(alpha: 0.6),
    );
    if (confidence > 0) {
      canvas.drawArc(
        outer,
        start,
        sweep * confidence,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = stroke * 0.45
          ..strokeCap = StrokeCap.round
          ..color = colour.withValues(alpha: 0.45),
      );
    }
  }

  @override
  bool shouldRepaint(_DialPainter old) =>
      old.score != score ||
      old.confidence != confidence ||
      old.colour != colour ||
      old.track != track;
}
