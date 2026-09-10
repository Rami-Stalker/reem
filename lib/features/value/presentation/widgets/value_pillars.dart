import 'package:flutter/material.dart';
import 'package:reem/core/design_system/design_system.dart';
import 'package:reem/features/value/domain/entities/value_standing.dart';

/// The six dimensions, drawn.
///
/// This is the widget that makes Reem Value legible as something other than a
/// points balance: a balance is one bar, and this is six. Seeing that شراء is
/// full while رأي is empty is the whole argument of the programme, delivered
/// without a sentence.
class ValuePillarBars extends StatelessWidget {
  const ValuePillarBars({super.key, required this.pillars});

  final List<ValuePillar> pillars;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final pillar in pillars) ...[
          _PillarRow(pillar: pillar),
          const SizedBox(height: DsSpacing.sm),
        ],
      ],
    );
  }
}

class _PillarRow extends StatelessWidget {
  const _PillarRow({required this.pillar});

  final ValuePillar pillar;

  @override
  Widget build(BuildContext context) {
    final colors = context.dsColors;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(pillar.label, style: context.dsText.labelStrong),
            ),
            if (pillar.capped)
              // The commerce ceiling, made visible. A woman who has filled this
              // pillar is told plainly that more spending will not move her —
              // which is the honest thing to say, and the thing a shop is least
              // inclined to.
              Text(
                'وصلتي للحد',
                style: context.dsText.micro.tint(colors.onSurfaceVariant),
              )
            else if (!pillar.isKnown)
              Text(
                'لسا ما منعرف',
                style: context.dsText.micro.tint(colors.onSurfaceVariant),
              ),
          ],
        ),
        DsGaps.vXxs,
        ClipRRect(
          borderRadius: BorderRadius.circular(DsRadius.pill),
          child: LinearProgressIndicator(
            value: (pillar.score / 100).clamp(0.0, 1.0),
            minHeight: 6,
            backgroundColor: colors.surfaceVariant,
            // A pillar with no evidence is drawn muted rather than empty-red:
            // not knowing is not failing.
            color: pillar.isKnown ? colors.primary : colors.outline,
          ),
        ),
        DsGaps.vXxxs,
        Text(
          pillar.isKnown
              ? pillar.blurb
              : '${pillar.blurb} — ما في كفاية بعد لنحكم.',
          style: context.dsText.micro,
        ),
      ],
    );
  }
}

/// What would move her next.
///
/// Rendered as dimensions rather than as a number of points, because the
/// arithmetic that produced it was a division of the shortfall across the
/// pillars with the most headroom. "٦٠ نقطة" would be a truthful summary of a
/// points system; this is a truthful summary of what Reem Value actually
/// computed.
class ValueAdviceList extends StatelessWidget {
  const ValueAdviceList({super.key, required this.advice, this.limit = 3});

  final List<ValueAdvice> advice;
  final int limit;

  @override
  Widget build(BuildContext context) {
    final colors = context.dsColors;
    if (advice.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final entry in advice.take(limit))
          Padding(
            padding: const EdgeInsets.only(bottom: DsSpacing.xs),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.arrow_outward_rounded,
                  size: 14,
                  color: colors.primary,
                ),
                const SizedBox(width: DsSpacing.xs),
                Expanded(
                  child: Text(entry.blurb, style: context.dsText.body),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// Ninety days of standing.
///
/// A sparkline rather than a chart: the shape is the message — rising, steady,
/// fading — and axes would invite her to read a precision the number does not
/// have.
class ValueHistoryLine extends StatelessWidget {
  const ValueHistoryLine({super.key, required this.history});

  final List<ValueSnapshot> history;

  @override
  Widget build(BuildContext context) {
    if (history.length < 2) return const SizedBox.shrink();
    return SizedBox(
      height: 48,
      child: CustomPaint(
        painter: _SparklinePainter(
          values: history.map((point) => point.score.toDouble()).toList(),
          color: context.dsColors.primary,
          fill: context.dsColors.primaryContainer,
        ),
        size: Size.infinite,
      ),
    );
  }
}

class _SparklinePainter extends CustomPainter {
  _SparklinePainter({
    required this.values,
    required this.color,
    required this.fill,
  });

  final List<double> values;
  final Color color;
  final Color fill;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.length < 2) return;

    final lowest = values.reduce((a, b) => a < b ? a : b);
    final highest = values.reduce((a, b) => a > b ? a : b);
    // A flat line is a real answer — a standing that held steady for three
    // months. Without this guard it divides by zero and disappears.
    final span = (highest - lowest).abs() < 1 ? 1.0 : highest - lowest;

    final path = Path();
    final area = Path();

    for (var i = 0; i < values.length; i += 1) {
      final x = size.width * (i / (values.length - 1));
      final y = size.height * (1 - (values[i] - lowest) / span);
      if (i == 0) {
        path.moveTo(x, y);
        area.moveTo(x, size.height);
        area.lineTo(x, y);
      } else {
        path.lineTo(x, y);
        area.lineTo(x, y);
      }
    }
    area.lineTo(size.width, size.height);
    area.close();

    canvas.drawPath(area, Paint()..color = fill.withValues(alpha: 0.5));
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
  bool shouldRepaint(_SparklinePainter oldDelegate) =>
      oldDelegate.values != values;
}
