import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:reem/core/design_system/design_system.dart';
import 'package:reem/features/seller_intelligence/domain/entities/intelligence.dart';

/// The small parts the three intelligence screens share.
///
/// Shared because the vocabulary has to be: a severity means the same colour
/// on the radar as it does on a product card, and an unmeasured score has to
/// look the same everywhere or a seller learns three different visual
/// languages for one idea.

// ── Colour ───────────────────────────────────────────────────────────────

Color severityColor(BuildContext context, AdviceSeverity severity) {
  final palette = context.atelier;
  return switch (severity) {
    AdviceSeverity.critical => palette.critical,
    AdviceSeverity.warning => palette.caution,
    AdviceSeverity.opportunity => palette.primary,
  };
}

/// The one place a 0-100 score becomes a colour.
///
/// Deliberately only three steps. A continuous gradient invites her to read
/// two points of difference as meaningful when the confidence behind it is
/// often ±10.
Color scoreColor(BuildContext context, double? score) {
  final palette = context.atelier;
  if (score == null) return palette.muted;
  if (score >= 75) return palette.positive;
  if (score >= 45) return palette.caution;
  return palette.critical;
}

// ── The score dial ───────────────────────────────────────────────────────

/// A score, drawn as an arc with its confidence in the ring.
///
/// The confidence is not decoration. A 92 measured over four orders and a 92
/// measured over four hundred are different claims, and the ring is how the
/// screen says so without making her read a second number.
class IntelligenceDial extends StatelessWidget {
  const IntelligenceDial({
    super.key,
    required this.score,
    this.confidence = 1,
    this.size = 68,
    this.label,
    this.provisional = false,
  });

  final double? score;
  final double confidence;
  final double size;
  final String? label;

  /// Measured, but not on enough evidence to be a verdict yet.
  final bool provisional;

  @override
  Widget build(BuildContext context) {
    final palette = context.atelier;
    final colour = provisional ? palette.muted : scoreColor(context, score);

    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _DialPainter(
          value: (score ?? 0) / 100,
          confidence: confidence.clamp(0, 1).toDouble(),
          colour: colour,
          track: palette.line,
          dim: provisional || score == null,
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                score?.round().toString() ?? '—',
                style: context.dsText.body.semibold.tint(colour),
              ),
              if (label != null)
                Text(label!, style: context.dsText.micro.tint(palette.muted)),
            ],
          ),
        ),
      ),
    );
  }
}

class _DialPainter extends CustomPainter {
  const _DialPainter({
    required this.value,
    required this.confidence,
    required this.colour,
    required this.track,
    required this.dim,
  });

  final double value;
  final double confidence;
  final Color colour;
  final Color track;
  final bool dim;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final centre = rect.center;
    final radius = size.width / 2 - 5;

    final base = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round
      ..color = track;

    canvas.drawCircle(centre, radius, base);

    if (value <= 0) return;

    final arc = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round
      ..color = dim ? colour.withValues(alpha: 0.45) : colour;

    canvas.drawArc(
      Rect.fromCircle(center: centre, radius: radius),
      -math.pi / 2,
      2 * math.pi * value.clamp(0, 1),
      false,
      arc,
    );

    // The confidence ring: a thin inner arc that only completes when the
    // evidence does.
    if (confidence < 1) {
      final inner = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round
        ..color = colour.withValues(alpha: 0.3);
      canvas.drawArc(
        Rect.fromCircle(center: centre, radius: radius - 6),
        -math.pi / 2,
        2 * math.pi * confidence,
        false,
        inner,
      );
    }
  }

  @override
  bool shouldRepaint(_DialPainter old) =>
      old.value != value ||
      old.confidence != confidence ||
      old.colour != colour ||
      old.dim != dim;
}

// ── Advice ───────────────────────────────────────────────────────────────

/// One thing to do.
///
/// The gain is shown only when there is one. Advice about price changes what
/// she earns rather than what she scores, and putting "+0" beside it would
/// make a useful sentence look worthless.
class AdviceTile extends StatelessWidget {
  const AdviceTile({super.key, required this.advice, this.dense = false});

  final Advice advice;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final palette = context.atelier;
    final colour = severityColor(context, advice.severity);

    return Padding(
      padding: EdgeInsets.symmetric(vertical: dense ? 4 : DsSpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 5),
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: colour, shape: BoxShape.circle),
          ),
          const SizedBox(width: DsSpacing.sm),
          Expanded(
            child: Text(
              advice.ar,
              style: (dense ? context.dsText.caption : context.dsText.body)
                  .tint(palette.ink),
            ),
          ),
          if (advice.isScored) ...[
            const SizedBox(width: DsSpacing.xs),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: colour.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(DsRadius.pill),
              ),
              child: Text(
                '+${advice.gainPoints.round()}',
                style: context.dsText.micro.tint(colour),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ── A measured bar ───────────────────────────────────────────────────────

/// One axis or dimension, as a labelled bar.
///
/// An unmeasured one is drawn as an empty track with a word rather than being
/// hidden. "We have not measured your shipping yet" is information she can
/// act on — by shipping something — and a row that silently vanished would
/// read as a bug.
class MeasureBar extends StatelessWidget {
  const MeasureBar({
    super.key,
    required this.label,
    required this.score,
    this.weight,
    this.trailing,
    this.provisional = false,
    this.unmeasuredNote = 'لسا ما قسناها',
  });

  final String label;
  final double? score;
  final double? weight;
  final String? trailing;
  final bool provisional;
  final String unmeasuredNote;

  @override
  Widget build(BuildContext context) {
    final palette = context.atelier;
    final measured = score != null;
    final colour = provisional ? palette.muted : scoreColor(context, score);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: DsSpacing.xs),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: context.dsText.caption.tint(
                    measured ? palette.ink : palette.muted,
                  ),
                ),
              ),
              if (trailing != null)
                Text(trailing!, style: context.dsText.micro.tint(palette.muted))
              else if (measured)
                Text(
                  score!.round().toString(),
                  style: context.dsText.caption.semibold.tint(colour),
                )
              else
                Text(
                  unmeasuredNote,
                  style: context.dsText.micro.tint(palette.muted),
                ),
            ],
          ),
          DsGaps.vXxs,
          ClipRRect(
            borderRadius: BorderRadius.circular(DsRadius.pill),
            child: LinearProgressIndicator(
              value: measured ? (score! / 100).clamp(0, 1) : 0,
              minHeight: 5,
              backgroundColor: palette.line,
              valueColor: AlwaysStoppedAnimation(colour),
            ),
          ),
          if (weight != null && weight! > 0) ...[
            DsGaps.vXxxs,
            Text(
              'وزنها ${weight!.round()}% من الصحّة',
              style: context.dsText.micro.tint(palette.muted),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Section heading ──────────────────────────────────────────────────────

/// A heading between sections — **a sliver, not a box**.
///
/// It returns its own `SliverToBoxAdapter` because every one of the three
/// intelligence screens is a `CustomScrollView` and this is only ever used in
/// a `slivers:` list. Leaving it a plain box compiled and analysed cleanly and
/// then threw `RenderViewport expected a child of type RenderSliver` the
/// instant a screen was rendered — a crash no static check catches and no
/// amount of reading the code makes obvious.
class SectionTitle extends StatelessWidget {
  const SectionTitle({super.key, required this.title, this.subtitle});

  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final palette = context.atelier;
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          DsSpacing.lg,
          DsSpacing.lg,
          DsSpacing.lg,
          DsSpacing.xs,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: context.dsText.cardTitle.tint(palette.ink)),
            if (subtitle != null) ...[
              DsGaps.vXxxs,
              Text(
                subtitle!,
                style: context.dsText.caption.tint(palette.muted),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
