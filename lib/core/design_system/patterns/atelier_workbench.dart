import 'dart:math' as math;
import 'dart:ui' show PathMetric;

import 'package:flutter/material.dart';

import 'package:reem/core/design_system/design_system.dart';

/// The seller's home register: **the workbench of an atelier**.
///
/// A boutique owner is not an analyst. She makes, stocks, ships and answers,
/// so her home is drawn from the room she does that in rather than from a
/// reporting tool:
///
/// * [AtelierHero] — a length of plum cloth with a champagne stitch around
///   its edge: the greeting, the day's takings, and the month's goal.
/// * [ThreadSpool] — progress toward a goal, as thread wound on a spool.
/// * [StitchedCard] — the one thing to do now, tacked to the bench with a
///   running stitch in the colour of its urgency.
/// * [OrderSeam] — the order pipeline as a seam: every stage a stitch-point,
///   the ones holding work lit in gold.
/// * [SewingButton] — her tools, as buttons from a sewing tin.
/// * [HangerRail] / [HangingPiece] — what sells, hanging on the rail, each
///   with a swing tag saying how many went or how few are left.
/// * [ThreadChart] — the takings over time, sewn as a line on pattern paper.
///
/// Everything resolves from [SellerAtelierPalette], so the bench follows dark
/// mode with the rest of the seller's pages.

// ---------------------------------------------------------------------------
// Stitching
// ---------------------------------------------------------------------------

/// Draws [path] as a running stitch: short dashes with gaps, round-capped.
void _stitch(
  Canvas canvas,
  Path path,
  Paint paint, {
  double dash = 7,
  double gap = 5,
}) {
  for (final PathMetric metric in path.computeMetrics()) {
    var distance = 0.0;
    while (distance < metric.length) {
      final end = math.min(distance + dash, metric.length);
      canvas.drawPath(metric.extractPath(distance, end), paint);
      distance = end + gap;
    }
  }
}

class _StitchBorderPainter extends CustomPainter {
  const _StitchBorderPainter({
    required this.color,
    required this.radius,
    this.inset = DsSpacing.xs,
    this.width = 1.4,
  });

  final Color color;
  final double radius;
  final double inset;
  final double width;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = (Offset.zero & size).deflate(inset);
    final path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          rect,
          Radius.circular(math.max(0, radius - inset)),
        ),
      );
    _stitch(
      canvas,
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = width
        ..strokeCap = StrokeCap.round
        ..color = color,
    );
  }

  @override
  bool shouldRepaint(_StitchBorderPainter old) =>
      old.color != color ||
      old.radius != radius ||
      old.inset != inset ||
      old.width != width;
}

// ---------------------------------------------------------------------------
// The hero
// ---------------------------------------------------------------------------

/// A length of plum cloth: the atelier's header gradient, a fine linen weave,
/// champagne light from the far corner, and a stitch around the edge.
/// Copy on it is set in [DsColors.onMedia].
class AtelierHero extends StatelessWidget {
  const AtelierHero({super.key, required this.child, this.padding});

  final Widget child;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final palette = context.atelier;
    final rtl = Directionality.of(context) == TextDirection.rtl;
    return Container(
      decoration: BoxDecoration(
        borderRadius: DsRadius.borderXxl,
        gradient: palette.headerGradient,
        boxShadow: context.glowShadow(DsColors.mauve700, blur: 30, alpha: 0.28),
      ),
      child: ClipRRect(
        borderRadius: DsRadius.borderXxl,
        child: CustomPaint(
          painter: _ClothPainter(rtl: rtl),
          foregroundPainter: _StitchBorderPainter(
            color: DsColors.gold200.withValues(alpha: 0.55),
            radius: DsRadius.xxl,
          ),
          child: Padding(padding: padding ?? DsSpacing.paddingXl, child: child),
        ),
      ),
    );
  }
}

class _ClothPainter extends CustomPainter {
  const _ClothPainter({required this.rtl});

  final bool rtl;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;

    // Champagne light from the far top corner, as from a workroom window.
    final light = Offset(rtl ? size.width * 0.1 : size.width * 0.9, 0);
    canvas.drawRect(
      rect,
      Paint()
        ..shader =
            RadialGradient(
              colors: [
                DsColors.gold300.withValues(alpha: 0.26),
                DsColors.gold300.withValues(alpha: 0),
              ],
            ).createShader(
              Rect.fromCircle(center: light, radius: size.width * 0.7),
            ),
    );

    // Linen: a fine weave of crossing threads, barely there.
    final weave = Paint()
      ..strokeWidth = 1
      ..color = DsColors.onMedia.withValues(alpha: 0.035);
    for (double d = -size.height; d < size.width; d += 9) {
      canvas.drawLine(
        Offset(d, 0),
        Offset(d + size.height, size.height),
        weave,
      );
    }
    for (double d = 0; d < size.width + size.height; d += 9) {
      canvas.drawLine(
        Offset(d, 0),
        Offset(d - size.height, size.height),
        weave,
      );
    }
  }

  @override
  bool shouldRepaint(_ClothPainter oldDelegate) => oldDelegate.rtl != rtl;
}

// ---------------------------------------------------------------------------
// The spool
// ---------------------------------------------------------------------------

/// Progress toward a goal, as thread wound onto a wooden spool.
///
/// The wound thread rises with [progress] (0–1); past the goal the spool is
/// full and the thread turns champagne. The loose end trails away from the
/// last wrap, so an empty spool still reads as a spool and not as a gap.
class ThreadSpool extends StatelessWidget {
  const ThreadSpool({
    super.key,
    required this.progress,
    this.width = 64,
    this.semanticLabel,
  });

  final double progress;
  final double width;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final spool = TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: progress.clamp(0.0, 1.0)),
      duration: DsReducedMotion.duration(DsMotion.slowest),
      curve: DsMotion.gentle,
      builder: (context, value, _) => CustomPaint(
        size: Size(width, width * 1.4),
        painter: _SpoolPainter(progress: value, full: progress >= 1),
      ),
    );
    return Semantics(
      image: true,
      label: semanticLabel,
      child: ExcludeSemantics(child: spool),
    );
  }
}

class _SpoolPainter extends CustomPainter {
  const _SpoolPainter({required this.progress, required this.full});

  final double progress;
  final bool full;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final flange = h * 0.1;
    final coreLeft = w * 0.24;
    final coreRight = w * 0.76;
    final coreTop = flange;
    final coreBottom = h - flange;

    // The wooden core.
    final core = Rect.fromLTRB(coreLeft, coreTop, coreRight, coreBottom);
    canvas.drawRect(
      core,
      Paint()
        ..shader = const LinearGradient(
          colors: [DsColors.gold600, DsColors.gold300, DsColors.gold600],
        ).createShader(core),
    );

    // The wound thread, from the bottom up, each wrap bulging a little.
    final wound = (coreBottom - coreTop) * progress;
    const wrap = 3.2;
    final threadA = full ? DsColors.gold200 : DsColors.primary400;
    final threadB = full ? DsColors.gold300 : DsColors.primary500;
    var i = 0;
    for (double y = coreBottom - wrap / 2; y > coreBottom - wound; y -= wrap) {
      final path = Path()
        ..moveTo(coreLeft - 3, y)
        ..quadraticBezierTo(w / 2, y + wrap * 0.9, coreRight + 3, y);
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = wrap * 0.95
          ..strokeCap = StrokeCap.round
          ..color = i.isEven ? threadA : threadB,
      );
      i++;
    }

    // The loose end, trailing off the last wrap.
    final endY = math.max(coreTop + 4, coreBottom - wound);
    final tail = Path()
      ..moveTo(coreRight + 2, endY)
      ..cubicTo(
        w * 1.02,
        endY - h * 0.05,
        w * 0.98,
        endY + h * 0.18,
        w * 1.1,
        endY + h * 0.28,
      );
    canvas.drawPath(
      tail,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4
        ..strokeCap = StrokeCap.round
        ..color = threadA,
    );

    // The two flanges, top and bottom.
    for (final top in [0.0, h - flange]) {
      final r = RRect.fromRectAndRadius(
        Rect.fromLTWH(0, top, w, flange),
        Radius.circular(flange / 2),
      );
      canvas.drawRRect(
        r,
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [DsColors.gold200, DsColors.gold500],
          ).createShader(r.outerRect),
      );
    }
  }

  @override
  bool shouldRepaint(_SpoolPainter old) =>
      old.progress != progress || old.full != full;
}

// ---------------------------------------------------------------------------
// The stitched card
// ---------------------------------------------------------------------------

/// A card tacked to the bench with a running stitch in [accent].
class StitchedCard extends StatelessWidget {
  const StitchedCard({
    super.key,
    required this.child,
    this.accent,
    this.padding = DsSpacing.paddingXl,
  });

  final Widget child;
  final Color? accent;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final palette = context.atelier;
    final stitch = accent ?? palette.gold;
    return Container(
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: DsRadius.borderXxl,
        boxShadow: context.glowShadow(stitch, blur: 26, alpha: 0.14),
      ),
      child: CustomPaint(
        foregroundPainter: _StitchBorderPainter(
          color: stitch.withValues(alpha: 0.75),
          radius: DsRadius.xxl,
          inset: DsSpacing.xs - DsSpacing.xxxs,
          width: 1.6,
        ),
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// The seam
// ---------------------------------------------------------------------------

/// One stitch-point on the [OrderSeam].
@immutable
class SeamStation {
  const SeamStation({
    required this.label,
    required this.count,
    required this.icon,
    this.lit = false,
  });

  final String label;
  final String count;
  final IconData icon;

  /// Holding work that waits on her.
  final bool lit;
}

/// The order pipeline as a seam, sewn in reading order.
///
/// A running stitch joins the stages; each stage is a stitch-point holding
/// its count. The stages where orders wait on *her* are lit in gold with
/// plum ink, so the eye goes to the work, not to the three thousand already
/// delivered.
class OrderSeam extends StatelessWidget {
  const OrderSeam({super.key, required this.stations, this.onTap});

  final List<SeamStation> stations;
  final ValueChanged<int>? onTap;

  static const double _point = 48;

  @override
  Widget build(BuildContext context) {
    final palette = context.atelier;
    return Stack(
      children: [
        Positioned(
          top: _point / 2 - 1,
          left: 0,
          right: 0,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final span = constraints.maxWidth / stations.length;
              return Padding(
                padding: EdgeInsets.symmetric(horizontal: span / 2),
                child: CustomPaint(
                  size: Size(constraints.maxWidth - span, 2),
                  painter: _SeamPainter(color: palette.gold),
                ),
              );
            },
          ),
        ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var i = 0; i < stations.length; i++)
              Expanded(
                child: _SeamPoint(
                  station: stations[i],
                  palette: palette,
                  onTap: onTap == null ? null : () => onTap!(i),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _SeamPainter extends CustomPainter {
  const _SeamPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(0, size.height / 2)
      ..lineTo(size.width, size.height / 2);
    _stitch(
      canvas,
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round
        ..color = color.withValues(alpha: 0.7),
      dash: 8,
      gap: 6,
    );
  }

  @override
  bool shouldRepaint(_SeamPainter old) => old.color != color;
}

class _SeamPoint extends StatelessWidget {
  const _SeamPoint({required this.station, required this.palette, this.onTap});

  final SeamStation station;
  final SellerAtelierPalette palette;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final lit = station.lit;
    final point = Container(
      width: OrderSeam._point,
      height: OrderSeam._point,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: lit ? palette.goldGradient : null,
        color: lit ? null : palette.surface,
        border: Border.all(
          color: lit ? DsColors.gold200 : palette.line,
          width: lit ? 2 : 1,
        ),
        boxShadow: lit
            ? context.glowShadow(palette.gold, blur: 16, alpha: 0.4)
            : null,
      ),
      alignment: Alignment.center,
      child: Text(
        station.count,
        style: context.dsText.metricSmall.displayFamily.tint(
          lit ? DsColors.onGold : palette.muted,
        ),
      ),
    );

    final content = Column(
      children: [
        point,
        DsGaps.vXs,
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              station.icon,
              size: DsSizes.iconXs,
              color: lit ? palette.primary : palette.muted,
            ),
            DsGaps.hXxs,
            Flexible(
              child: Text(
                station.label,
                maxLines: 2,
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
                style:
                    (lit
                            ? context.dsText.labelStrong
                            : context.dsText.labelMedium)
                        .tint(lit ? palette.ink : palette.muted),
              ),
            ),
          ],
        ),
      ],
    );

    if (onTap == null) return content;
    return DsScaleAnimations.tapScale(
      onTap: onTap!,
      semanticLabel: '${station.label}، ${station.count}',
      excludeChildSemantics: true,
      child: content,
    );
  }
}

// ---------------------------------------------------------------------------
// The sewing tin
// ---------------------------------------------------------------------------

/// A tool, as a button from a sewing tin: a disc with a raised rim and four
/// thread holes, the tool's icon set in its face, its name underneath.
class SewingButton extends StatelessWidget {
  const SewingButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.color,
    this.size = 60,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? color;
  final double size;

  @override
  Widget build(BuildContext context) {
    final palette = context.atelier;
    final tint = color ?? palette.primary;
    return DsScaleAnimations.tapScale(
      onTap: onTap,
      semanticLabel: label,
      excludeChildSemantics: true,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox.square(
            dimension: size,
            child: CustomPaint(
              painter: _ButtonPainter(
                tint: tint,
                face: palette.surface,
                shadow: palette.shadow.isEmpty
                    ? DsColors.transparent
                    : palette.shadow.first.color,
              ),
              child: Center(
                child: Icon(icon, size: size * 0.38, color: tint),
              ),
            ),
          ),
          DsGaps.vXs,
          Text(
            label,
            maxLines: 2,
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
            style: context.dsText.labelMedium.semibold.tint(palette.ink),
          ),
        ],
      ),
    );
  }
}

class _ButtonPainter extends CustomPainter {
  const _ButtonPainter({
    required this.tint,
    required this.face,
    required this.shadow,
  });

  final Color tint;
  final Color face;
  final Color shadow;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.shortestSide / 2;

    canvas.drawCircle(
      c.translate(0, 3),
      r,
      Paint()
        ..color = shadow
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );
    // The disc, lit from above.
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(0, -0.4),
          colors: [Color.lerp(face, tint, 0.06)!, Color.lerp(face, tint, 0.2)!],
        ).createShader(Rect.fromCircle(center: c, radius: r)),
    );
    // The raised rim.
    canvas.drawCircle(
      c,
      r * 0.86,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4
        ..color = tint.withValues(alpha: 0.35),
    );
    canvas.drawCircle(
      c,
      r - 0.7,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = tint.withValues(alpha: 0.25),
    );
    // Four thread holes on the diagonals, inside the rim.
    final hole = Paint()..color = tint.withValues(alpha: 0.45);
    for (var k = 0; k < 4; k++) {
      final a = math.pi / 4 + k * math.pi / 2;
      canvas.drawCircle(
        c + Offset(math.cos(a), math.sin(a)) * r * 0.68,
        r * 0.055,
        hole,
      );
    }
  }

  @override
  bool shouldRepaint(_ButtonPainter old) =>
      old.tint != tint || old.face != face || old.shadow != shadow;
}

// ---------------------------------------------------------------------------
// The rail
// ---------------------------------------------------------------------------

/// The shop rail: a brass rod the pieces hang from, scrolling sideways.
class HangerRail extends StatelessWidget {
  const HangerRail({super.key, required this.children, this.padding});

  final List<Widget> children;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: padding,
      child: Stack(
        children: [
          // The rod, the full length of the rail.
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: DsSpacing.xs,
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: DsRadius.borderPill,
                gradient: const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    DsColors.gold200,
                    DsColors.gold500,
                    DsColors.gold700,
                  ],
                ),
              ),
            ),
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var i = 0; i < children.length; i++) ...[
                if (i > 0) DsGaps.hMd,
                children[i],
              ],
            ],
          ),
        ],
      ),
    );
  }
}

/// A piece on the rail: a hanger hooked over the rod, the photograph cut to
/// Reem's arch, its name, and a swing tag.
class HangingPiece extends StatelessWidget {
  const HangingPiece({
    super.key,
    required this.image,
    required this.title,
    required this.tag,
    this.tagColor,
    this.onTap,
    this.width = 136,
  });

  /// The photograph, or its fallback, filling the arch.
  final Widget image;
  final String title;

  /// The swing tag's line: «١٣٤ قطعة» on a good seller, «باقي ٢» on one
  /// running out.
  final String tag;

  /// The tag's colour — the champagne of a good seller by default, the
  /// critical red on stock that is nearly gone.
  final Color? tagColor;
  final VoidCallback? onTap;
  final double width;

  static const double _hangerHeight = 30;

  @override
  Widget build(BuildContext context) {
    final palette = context.atelier;
    final tint = tagColor ?? palette.gold;

    final piece = SizedBox(
      width: width,
      child: Column(
        children: [
          SizedBox(
            width: width,
            height: _hangerHeight,
            child: CustomPaint(painter: _HangerPainter(color: palette.muted)),
          ),
          Stack(
            clipBehavior: Clip.none,
            children: [
              // The shadow follows the arch, not the box around it.
              PhysicalShape(
                clipper: const DsArchClipper(),
                clipBehavior: Clip.antiAlias,
                color: palette.surface,
                elevation: 3,
                shadowColor: palette.shadow.isEmpty
                    ? DsColors.transparent
                    : palette.shadow.first.color,
                child: SizedBox(
                  width: width,
                  height: width * 1.25,
                  child: image,
                ),
              ),
              // The swing tag, tied on at the shoulder.
              PositionedDirectional(
                top: width * 0.42,
                end: -DsSpacing.xxs,
                child: _SwingTag(label: tag, color: tint, palette: palette),
              ),
            ],
          ),
          DsGaps.vXs,
          Text(
            title,
            maxLines: 2,
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
            style: context.dsText.labelMedium.semibold.tint(palette.ink),
          ),
        ],
      ),
    );

    if (onTap == null) return piece;
    return DsScaleAnimations.tapScale(
      onTap: onTap!,
      semanticLabel: '$title، $tag',
      excludeChildSemantics: true,
      child: piece,
    );
  }
}

class _HangerPainter extends CustomPainter {
  const _HangerPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = color;
    final cx = size.width / 2;
    // The hook, curled over the rod.
    final hook = Path()
      ..moveTo(cx, size.height * 0.55)
      ..lineTo(cx, size.height * 0.3)
      ..arcToPoint(
        Offset(cx - 7, size.height * 0.1),
        radius: const Radius.circular(6),
        clockwise: false,
      );
    canvas.drawPath(hook, paint);
    // The shoulders, sloping down to the piece.
    final shoulders = Path()
      ..moveTo(size.width * 0.16, size.height)
      ..lineTo(cx, size.height * 0.55)
      ..lineTo(size.width * 0.84, size.height);
    canvas.drawPath(shoulders, paint..strokeWidth = 2.2);
  }

  @override
  bool shouldRepaint(_HangerPainter old) => old.color != color;
}

class _SwingTag extends StatelessWidget {
  const _SwingTag({
    required this.label,
    required this.color,
    required this.palette,
  });

  final String label;
  final Color color;
  final SellerAtelierPalette palette;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _TagPainter(fill: palette.surface, edge: color),
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(
          DsSpacing.md + DsSpacing.xxs,
          DsSpacing.xxs,
          DsSpacing.sm,
          DsSpacing.xxs,
        ),
        child: Text(label, style: context.dsText.badge.tint(color)),
      ),
    );
  }
}

/// A swing tag: a card with a clipped point on its leading side and an
/// eyelet for the string.
class _TagPainter extends CustomPainter {
  const _TagPainter({required this.fill, required this.edge});

  final Color fill;
  final Color edge;

  @override
  void paint(Canvas canvas, Size size) {
    final h = size.height;
    final w = size.width;
    final point = h * 0.45;
    // Painted in logical left-to-right; the tag's point faces the piece,
    // which in either direction is the same physical shape mirrored by the
    // directional position it is placed at, so a symmetric point is used.
    final path = Path()
      ..moveTo(point, 0)
      ..lineTo(w - 4, 0)
      ..quadraticBezierTo(w, 0, w, 4)
      ..lineTo(w, h - 4)
      ..quadraticBezierTo(w, h, w - 4, h)
      ..lineTo(point, h)
      ..lineTo(0, h / 2)
      ..close();
    canvas.drawShadow(path, edge.withValues(alpha: 0.4), 3, false);
    canvas.drawPath(path, Paint()..color = fill);
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = edge,
    );
    canvas.drawCircle(
      Offset(point * 0.85, h / 2),
      2,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = edge,
    );
  }

  @override
  bool shouldRepaint(_TagPainter old) => old.fill != fill || old.edge != edge;
}

// ---------------------------------------------------------------------------
// The thread chart
// ---------------------------------------------------------------------------

/// Takings over time, sewn as a line on pattern paper.
///
/// A dotted pattern grid, a soft fill under the line, the line itself drawn
/// as a champagne running stitch over a plum thread, and a knot at every
/// point — the last one larger, because it is today.
class ThreadChart extends StatelessWidget {
  const ThreadChart({
    super.key,
    required this.values,
    required this.labels,
    this.height = 180,
    this.semanticLabel,
  });

  final List<double> values;
  final List<String> labels;
  final double height;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final palette = context.atelier;
    return Semantics(
      image: true,
      label: semanticLabel,
      child: ExcludeSemantics(
        child: Column(
          children: [
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: 1),
              duration: DsReducedMotion.duration(DsMotion.slowest),
              curve: DsMotion.gentle,
              builder: (context, progress, _) => CustomPaint(
                size: Size(double.infinity, height),
                painter: _ThreadChartPainter(
                  values: values,
                  progress: progress,
                  thread: palette.primary,
                  stitch: palette.gold,
                  grid: palette.line,
                  ground: palette.surface,
                ),
              ),
            ),
            if (labels.isNotEmpty) ...[
              DsGaps.vXs,
              Row(
                children: [
                  for (final label in labels)
                    Expanded(
                      child: Text(
                        label,
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.clip,
                        style: context.dsText.caption.tint(palette.muted),
                      ),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ThreadChartPainter extends CustomPainter {
  const _ThreadChartPainter({
    required this.values,
    required this.progress,
    required this.thread,
    required this.stitch,
    required this.grid,
    required this.ground,
  });

  final List<double> values;
  final double progress;
  final Color thread;
  final Color stitch;
  final Color grid;
  final Color ground;

  @override
  void paint(Canvas canvas, Size size) {
    // Pattern paper: a dot at every grid crossing.
    final dot = Paint()..color = grid;
    const step = 16.0;
    for (double y = step / 2; y < size.height; y += step) {
      for (double x = step / 2; x < size.width; x += step) {
        canvas.drawCircle(Offset(x, y), 0.9, dot);
      }
    }

    if (values.length < 2) return;
    final top = values.reduce(math.max);
    final bottom = values.reduce(math.min);
    final span = (top - bottom).abs() < 1e-9 ? 1.0 : top - bottom;
    final slot = size.width / values.length;

    final points = [
      for (var i = 0; i < values.length; i++)
        Offset(
          slot * (i + 0.5),
          size.height * 0.12 +
              (size.height * 0.76) *
                  (1 - (values[i] - bottom) / span) *
                  progress +
              (size.height * 0.76) * (1 - progress),
        ),
    ];

    final line = Path()..moveTo(points.first.dx, points.first.dy);
    for (var i = 1; i < points.length; i++) {
      final a = points[i - 1];
      final b = points[i];
      final mid = (a.dx + b.dx) / 2;
      line.cubicTo(mid, a.dy, mid, b.dy, b.dx, b.dy);
    }

    final area = Path.from(line)
      ..lineTo(points.last.dx, size.height)
      ..lineTo(points.first.dx, size.height)
      ..close();
    canvas.drawPath(
      area,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [thread.withValues(alpha: 0.22), thread.withValues(alpha: 0)],
        ).createShader(Offset.zero & size),
    );

    // The plum thread, and the champagne stitch over it.
    canvas.drawPath(
      line,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round
        ..color = thread,
    );
    _stitch(
      canvas,
      line,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6
        ..strokeCap = StrokeCap.round
        ..color = DsColors.gold100,
      dash: 5,
      gap: 5,
    );

    // A knot at every point; today's is larger and ringed in gold.
    for (var i = 0; i < points.length; i++) {
      final last = i == points.length - 1;
      canvas.drawCircle(points[i], last ? 7 : 4.5, Paint()..color = ground);
      canvas.drawCircle(
        points[i],
        last ? 7 : 4.5,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = last ? 2.4 : 1.6
          ..color = last ? stitch : thread,
      );
      if (last) canvas.drawCircle(points[i], 3, Paint()..color = stitch);
    }
  }

  @override
  bool shouldRepaint(_ThreadChartPainter old) =>
      old.values != values ||
      old.progress != progress ||
      old.thread != thread ||
      old.stitch != stitch ||
      old.grid != grid ||
      old.ground != ground;
}

/// A chapter heading on the bench: the name, a short line under it, and a
/// trailing link — with a tiny needle-and-thread mark before the name.
class AtelierHeading extends StatelessWidget {
  const AtelierHeading({
    super.key,
    required this.title,
    this.caption,
    this.trailing,
  });

  final String title;
  final String? caption;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final palette = context.atelier;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CustomPaint(
                    size: const Size(DsSpacing.lg, DsSpacing.md),
                    painter: _NeedleMarkPainter(
                      needle: palette.muted,
                      thread: palette.gold,
                      rtl: Directionality.of(context) == TextDirection.rtl,
                    ),
                  ),
                  DsGaps.hXs,
                  Flexible(
                    child: Text(
                      title,
                      style: context.dsText.sectionTitle.displayFamily.bold
                          .tint(palette.ink),
                    ),
                  ),
                ],
              ),
              if (caption != null) ...[
                DsGaps.vXxs,
                Text(
                  caption!,
                  style: context.dsText.cardSubtitle.tint(palette.muted),
                ),
              ],
            ],
          ),
        ),
        ?trailing,
      ],
    );
  }
}

class _NeedleMarkPainter extends CustomPainter {
  const _NeedleMarkPainter({
    required this.needle,
    required this.thread,
    required this.rtl,
  });

  final Color needle;
  final Color thread;
  final bool rtl;

  @override
  void paint(Canvas canvas, Size size) {
    if (rtl) {
      canvas.translate(size.width, 0);
      canvas.scale(-1, 1);
    }
    final h = size.height;
    final w = size.width;
    // The needle, pointing toward the title.
    canvas.drawLine(
      Offset(w * 0.15, h * 0.5),
      Offset(w, h * 0.5),
      Paint()
        ..strokeWidth = 1.8
        ..strokeCap = StrokeCap.round
        ..color = needle,
    );
    // The thread through its eye, looping back.
    final loop = Path()
      ..moveTo(w * 0.2, h * 0.5)
      ..cubicTo(0, h * 0.5, w * 0.05, h, w * 0.4, h * 0.85);
    canvas.drawPath(
      loop,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4
        ..strokeCap = StrokeCap.round
        ..color = thread,
    );
  }

  @override
  bool shouldRepaint(_NeedleMarkPainter old) =>
      old.needle != needle || old.thread != thread || old.rtl != rtl;
}
