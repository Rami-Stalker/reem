import 'dart:math' as math;
import 'dart:ui' show PathMetric;

import 'package:flutter/material.dart';

import 'package:reem/core/design_system/design_system.dart';
import 'package:reem/core/router/open_route.dart';

/// The seller's home register: **her boutique, behind the counter**.
///
/// A boutique owner is not an analyst — and she is not necessarily a
/// dressmaker. She may sell perfume, flowers, jewellery, make-up or clothes,
/// so nothing here is drawn from one trade. It is drawn from what every
/// women's shop shares: the counter, the display shelf, the gift tag, the
/// ribbon a purchase leaves in, and Reem's own arch.
///
/// * [AtelierHero] — a length of satin with a champagne edge: the greeting,
///   the day's takings, and the month's goal.
/// * [ArchGauge] — progress toward a goal, as Reem's arch filling with gold.
/// * [AtelierFocusCard] — the one thing to do now, edged in the colour of its
///   urgency.
/// * [OrderPath] — the order pipeline as a dotted path: every stage a stop,
///   the ones holding work lit in gold.
/// * [PearlButton] — her tools, as polished pearl buttons.
/// * [DisplayShelf] / [ShelfPiece] — what sells, standing on the shelf, each
///   with a gift tag saying how many went or how few are left.
/// * [RibbonChart] — the takings over time, as a satin ribbon with a pearl at
///   every period.
///
/// Everything resolves from [SellerAtelierPalette], so the shop follows dark
/// mode with the rest of the seller's pages.

// ---------------------------------------------------------------------------
// Dashed lines
// ---------------------------------------------------------------------------

/// Draws [path] as a dashed line: short dashes with gaps, round-capped.
void _dashed(
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

class _DashedBorderPainter extends CustomPainter {
  const _DashedBorderPainter({
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
    _dashed(
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
  bool shouldRepaint(_DashedBorderPainter old) =>
      old.color != color ||
      old.radius != radius ||
      old.inset != inset ||
      old.width != width;
}

// ---------------------------------------------------------------------------
// The hero
// ---------------------------------------------------------------------------

/// A length of plum satin: the seller's header gradient, two bands of sheen,
/// champagne light from the far corner, and a dotted champagne edge.
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
          painter: _SatinPainter(rtl: rtl),
          foregroundPainter: _DashedBorderPainter(
            color: DsColors.gold200.withValues(alpha: 0.55),
            radius: DsRadius.xxl,
          ),
          child: Padding(padding: padding ?? DsSpacing.paddingXl, child: child),
        ),
      ),
    );
  }
}

class _SatinPainter extends CustomPainter {
  const _SatinPainter({required this.rtl});

  final bool rtl;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;

    // Champagne light from the far top corner, as from a shop window.
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

    // Satin: two soft bands of sheen running across the cloth, the way light
    // lies on a wrapped box.
    for (final (offset, width, alpha) in const [
      (0.18, 0.16, 0.07),
      (0.52, 0.08, 0.05),
    ]) {
      final x = size.width * offset;
      final band = Path()
        ..moveTo(x, 0)
        ..lineTo(x + size.width * width, 0)
        ..lineTo(x + size.width * width - size.height * 0.6, size.height)
        ..lineTo(x - size.height * 0.6, size.height)
        ..close();
      canvas.drawPath(
        rtl
            ? band.transform(
                (Matrix4.identity()
                      ..translateByDouble(size.width, 0, 0, 1)
                      ..scaleByDouble(-1, 1, 1, 1))
                    .storage,
              )
            : band,
        Paint()
          ..shader = LinearGradient(
            colors: [
              DsColors.onMedia.withValues(alpha: 0),
              DsColors.onMedia.withValues(alpha: alpha),
              DsColors.onMedia.withValues(alpha: 0),
            ],
          ).createShader(rect),
      );
    }
  }

  @override
  bool shouldRepaint(_SatinPainter oldDelegate) => oldDelegate.rtl != rtl;
}

// ---------------------------------------------------------------------------
// The goal
// ---------------------------------------------------------------------------

/// Progress toward a goal, as Reem's arch filling with gold.
///
/// The arch is the brand's window; here it fills from the floor with
/// champagne light as the month gets closer to its goal, the surface of the
/// light gently curved. Full, it glows. It belongs to no trade — it reads as
/// a lantern to one woman and a perfume bottle to the next.
class ArchGauge extends StatelessWidget {
  const ArchGauge({
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
    final gauge = TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: progress.clamp(0.0, 1.0)),
      duration: DsReducedMotion.duration(DsMotion.slowest),
      curve: DsMotion.gentle,
      builder: (context, value, _) => CustomPaint(
        size: Size(width, width * 1.4),
        painter: _ArchGaugePainter(progress: value, full: progress >= 1),
      ),
    );
    return Semantics(
      image: true,
      label: semanticLabel,
      child: ExcludeSemantics(child: gauge),
    );
  }
}

class _ArchGaugePainter extends CustomPainter {
  const _ArchGaugePainter({required this.progress, required this.full});

  final double progress;
  final bool full;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final arch = dsArchPath(rect.deflate(2));

    if (full) {
      canvas.drawPath(
        arch,
        Paint()
          ..color = DsColors.gold300.withValues(alpha: 0.5)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
      );
    }

    // The empty window: a faint glass.
    canvas.drawPath(
      arch,
      Paint()..color = DsColors.onMedia.withValues(alpha: 0.08),
    );

    // The light, risen to [progress], its surface gently curved.
    canvas.save();
    canvas.clipPath(arch);
    final level = size.height * (1 - progress);
    final surface = Path()..moveTo(0, size.height);
    surface.lineTo(0, level);
    surface.quadraticBezierTo(
      size.width * 0.25,
      level - 3,
      size.width * 0.5,
      level,
    );
    surface.quadraticBezierTo(size.width * 0.75, level + 3, size.width, level);
    surface
      ..lineTo(size.width, size.height)
      ..close();
    canvas.drawPath(
      surface,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [DsColors.gold200, DsColors.gold500],
        ).createShader(rect),
    );
    // A glint on the glass.
    canvas.drawLine(
      Offset(size.width * 0.28, size.height * 0.3),
      Offset(size.width * 0.28, size.height * 0.62),
      Paint()
        ..strokeWidth = 2.4
        ..strokeCap = StrokeCap.round
        ..color = DsColors.onMedia.withValues(alpha: 0.35),
    );
    canvas.restore();

    // The frame.
    canvas.drawPath(
      arch,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = DsColors.gold200,
    );
  }

  @override
  bool shouldRepaint(_ArchGaugePainter old) =>
      old.progress != progress || old.full != full;
}

// ---------------------------------------------------------------------------
// The focus card
// ---------------------------------------------------------------------------

/// The one thing to do now: a card edged with a dotted line in [accent], the
/// colour of its urgency.
class AtelierFocusCard extends StatelessWidget {
  const AtelierFocusCard({
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
    final edge = accent ?? palette.gold;
    return Container(
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: DsRadius.borderXxl,
        boxShadow: context.glowShadow(edge, blur: 26, alpha: 0.14),
      ),
      child: CustomPaint(
        foregroundPainter: _DashedBorderPainter(
          color: edge.withValues(alpha: 0.75),
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
// The order path
// ---------------------------------------------------------------------------

/// One stop on the [OrderPath].
@immutable
class PathStop {
  const PathStop({
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

/// The order pipeline as a dotted path, in reading order.
///
/// A dotted line joins the stages; each stage is a stop holding its count. The stages where orders wait on *her* are lit in gold with
/// plum ink, so the eye goes to the work, not to the three thousand already
/// delivered.
class OrderPath extends StatelessWidget {
  const OrderPath({super.key, required this.stations, this.onTap});

  final List<PathStop> stations;
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
                  painter: _PathPainter(color: palette.gold),
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
                child: _PathStopView(
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

class _PathPainter extends CustomPainter {
  const _PathPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(0, size.height / 2)
      ..lineTo(size.width, size.height / 2);
    _dashed(
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
  bool shouldRepaint(_PathPainter old) => old.color != color;
}

class _PathStopView extends StatelessWidget {
  const _PathStopView({
    required this.station,
    required this.palette,
    this.onTap,
  });

  final PathStop station;
  final SellerAtelierPalette palette;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final lit = station.lit;
    final point = Container(
      width: OrderPath._point,
      height: OrderPath._point,
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
// The tools
// ---------------------------------------------------------------------------

/// A tool, as a polished pearl: a lustrous disc with a fine rim and a glint,
/// the tool's icon set in its face, its name underneath.
class PearlButton extends StatelessWidget {
  const PearlButton({
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
    canvas.drawCircle(
      c,
      r - 0.7,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = tint.withValues(alpha: 0.25),
    );
    // The pearl's glint: a soft crescent of light high on the disc.
    canvas.drawArc(
      Rect.fromCircle(center: c, radius: r * 0.72),
      math.pi * 1.1,
      math.pi * 0.5,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * 0.12
        ..strokeCap = StrokeCap.round
        ..color = DsColors.onMedia.withValues(alpha: 0.55),
    );
  }

  @override
  bool shouldRepaint(_ButtonPainter old) =>
      old.tint != tint || old.face != face || old.shadow != shadow;
}

// ---------------------------------------------------------------------------
// The rail
// ---------------------------------------------------------------------------

/// The display shelf: a polished board the pieces stand on, scrolling
/// sideways. A bottle, a bouquet, a box of jewellery or a folded dress all
/// stand on a shelf the same way.
class DisplayShelf extends StatelessWidget {
  const DisplayShelf({
    super.key,
    required this.children,
    this.padding,
    this.pieceWidth = ShelfPiece.defaultWidth,
  });

  final List<Widget> children;
  final EdgeInsetsGeometry? padding;

  /// The width of the [ShelfPiece]s, so the board sits under their photos.
  final double pieceWidth;

  @override
  Widget build(BuildContext context) {
    final palette = context.atelier;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: padding,
      child: Stack(
        children: [
          // The board, the full length of the shelf, under the photographs.
          Positioned(
            top: ShelfPiece.photoHeightFor(pieceWidth),
            left: 0,
            right: 0,
            height: ShelfPiece.board,
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: DsRadius.borderXs,
                gradient: const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    DsColors.gold200,
                    DsColors.gold400,
                    DsColors.gold700,
                  ],
                  stops: [0, 0.45, 1],
                ),
                boxShadow: [
                  BoxShadow(
                    color: palette.shadow.isEmpty
                        ? DsColors.transparent
                        : palette.shadow.first.color,
                    blurRadius: 10,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
            ),
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var i = 0; i < children.length; i++) ...[
                if (i > 0) DsGaps.hLg,
                children[i],
              ],
            ],
          ),
        ],
      ),
    );
  }
}

/// A piece on the shelf: the photograph cut to Reem's arch, standing on the
/// board, a gift tag tied at its side, and its name under the shelf.
class ShelfPiece extends StatelessWidget {
  const ShelfPiece({
    super.key,
    required this.image,
    required this.title,
    required this.tag,
    this.tagColor,
    this.onTap,
    this.width = defaultWidth,
  });

  /// The photograph, or its fallback, filling the arch.
  final Widget image;
  final String title;

  /// The tag's line: «بيعت ٩٧» on a good seller, «باقي ٢» on one running out.
  final String tag;

  /// The tag's colour — champagne for a good seller by default, the critical
  /// red on stock that is nearly gone.
  final Color? tagColor;
  final VoidCallback? onTap;
  final double width;

  static const double defaultWidth = 128;
  static const double board = DsSpacing.sm;

  static double photoHeightFor(double width) => width * 1.25;

  @override
  Widget build(BuildContext context) {
    final palette = context.atelier;
    final tint = tagColor ?? palette.gold;

    final piece = SizedBox(
      width: width,
      child: Column(
        children: [
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
                  height: photoHeightFor(width),
                  child: image,
                ),
              ),
              // The gift tag, tied at the side.
              PositionedDirectional(
                top: width * 0.5,
                end: -DsSpacing.xs,
                child: _SwingTag(label: tag, color: tint, palette: palette),
              ),
            ],
          ),
          // Room for the board.
          const SizedBox(height: board + DsSpacing.sm),
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

/// A gift tag: a card with a clipped point on its leading side and an eyelet
/// for the ribbon.
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
// The ribbon chart
// ---------------------------------------------------------------------------

/// Takings over time, as a satin ribbon laid across a dotted grid.
///
/// A soft fill under the line, the line itself a plum ribbon with a fine
/// champagne sheen along it, and a pearl at every point — the last one
/// larger and gold, because it is now.
class RibbonChart extends StatelessWidget {
  const RibbonChart({
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
                painter: _RibbonChartPainter(
                  values: values,
                  progress: progress,
                  ribbon: palette.primary,
                  pearl: palette.gold,
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

class _RibbonChartPainter extends CustomPainter {
  const _RibbonChartPainter({
    required this.values,
    required this.progress,
    required this.ribbon,
    required this.pearl,
    required this.grid,
    required this.ground,
  });

  final List<double> values;
  final double progress;
  final Color ribbon;
  final Color pearl;
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
          colors: [ribbon.withValues(alpha: 0.22), ribbon.withValues(alpha: 0)],
        ).createShader(Offset.zero & size),
    );

    // The plum ribbon, and the sheen of light along it.
    canvas.drawPath(
      line,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4
        ..strokeCap = StrokeCap.round
        ..color = ribbon,
    );
    canvas.drawPath(
      line.shift(const Offset(0, -0.8)),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..strokeCap = StrokeCap.round
        ..color = DsColors.gold100.withValues(alpha: 0.75),
    );

    // A pearl at every point; the latest is larger and set in gold.
    for (var i = 0; i < points.length; i++) {
      final last = i == points.length - 1;
      canvas.drawCircle(points[i], last ? 7 : 4.5, Paint()..color = ground);
      canvas.drawCircle(
        points[i],
        last ? 7 : 4.5,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = last ? 2.4 : 1.6
          ..color = last ? pearl : ribbon,
      );
      if (last) canvas.drawCircle(points[i], 3, Paint()..color = pearl);
    }
  }

  @override
  bool shouldRepaint(_RibbonChartPainter old) =>
      old.values != values ||
      old.progress != progress ||
      old.ribbon != ribbon ||
      old.pearl != pearl ||
      old.grid != grid ||
      old.ground != ground;
}

/// A chapter heading in the shop: the name, a short line under it, and a
/// trailing link — with a small champagne sparkle before the name.
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
                    painter: _SparkleMarkPainter(
                      minor: palette.muted,
                      major: palette.gold,
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

class _SparkleMarkPainter extends CustomPainter {
  const _SparkleMarkPainter({
    required this.minor,
    required this.major,
    required this.rtl,
  });

  final Color minor;
  final Color major;
  final bool rtl;

  @override
  void paint(Canvas canvas, Size size) {
    // A four-pointed sparkle, and a smaller one beside it.
    void sparkle(Offset c, double r, Color color) {
      final path = Path()
        ..moveTo(c.dx, c.dy - r)
        ..quadraticBezierTo(c.dx, c.dy, c.dx + r, c.dy)
        ..quadraticBezierTo(c.dx, c.dy, c.dx, c.dy + r)
        ..quadraticBezierTo(c.dx, c.dy, c.dx - r, c.dy)
        ..quadraticBezierTo(c.dx, c.dy, c.dx, c.dy - r)
        ..close();
      canvas.drawPath(path, Paint()..color = color);
    }

    final h = size.height;
    final w = size.width;
    final big = Offset(rtl ? w * 0.38 : w * 0.62, h * 0.5);
    final small = Offset(rtl ? w * 0.82 : w * 0.18, h * 0.22);
    sparkle(big, h * 0.5, major);
    sparkle(small, h * 0.22, minor);
  }

  @override
  bool shouldRepaint(_SparkleMarkPainter old) =>
      old.minor != minor || old.major != major || old.rtl != rtl;
}

// ---------------------------------------------------------------------------
// The banner
// ---------------------------------------------------------------------------

/// A figure set on the [AtelierAppBar]'s banner.
@immutable
class AtelierHighlight {
  const AtelierHighlight({required this.value, required this.label});

  final String value;
  final String label;
}

/// The top of every seller page: a banner of the shop's plum satin.
///
/// Open, it is a length of satin hung across the top of the page — the
/// room's medallion, its name in the display serif, a line on what it is
/// for, and its figures in champagne. As she scrolls it folds up into a slim
/// plum bar carrying the name alone, with the dotted champagne edge still
/// along its bottom, so every seller page wears the same satin.
///
/// The same arguments as [PremiumAppBar] for the common case, so a page
/// moves across by changing one name.
class AtelierAppBar extends StatelessWidget {
  const AtelierAppBar({
    super.key,
    required this.title,
    this.subtitle,
    this.icon,
    this.showBack = false,
    this.onBack,
    this.actions,
    this.highlights = const [],
  });

  final String title;
  final String? subtitle;
  final IconData? icon;
  final bool showBack;
  final VoidCallback? onBack;
  final List<Widget>? actions;
  final List<AtelierHighlight> highlights;

  @override
  Widget build(BuildContext context) {
    final body =
        DsSpacing.md +
        (subtitle == null ? 44 : 68) +
        (highlights.isEmpty ? 0 : 48) +
        DsSpacing.xl;
    return SliverAppBar(
      pinned: true,
      elevation: 0,
      scrolledUnderElevation: 0,
      expandedHeight: DsSizes.appBarHeight + body,
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      foregroundColor: DsColors.onMedia,
      iconTheme: const IconThemeData(color: DsColors.onMedia),
      actionsIconTheme: const IconThemeData(color: DsColors.onMedia),
      automaticallyImplyLeading: false,
      leading: showBack
          ? IconButton(
              icon: const Icon(
                DsIcons.back,
                color: DsColors.onMedia,
                size: DsSizes.iconSm,
              ),
              tooltip: MaterialLocalizations.of(context).backButtonTooltip,
              onPressed: onBack ?? () => popOrHome(context),
            )
          : null,
      actions: actions,
      flexibleSpace: LayoutBuilder(
        builder: (context, constraints) {
          final top = MediaQuery.paddingOf(context).top;
          final collapsed = DsSizes.appBarHeight + top;
          final expanded = DsSizes.appBarHeight + body + top;
          final t =
              ((constraints.maxHeight - collapsed) / (expanded - collapsed))
                  .clamp(0.0, 1.0);
          return _Banner(
            openness: t,
            title: title,
            subtitle: subtitle,
            icon: icon,
            highlights: highlights,
            topInset: top,
          );
        },
      ),
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({
    required this.openness,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.highlights,
    required this.topInset,
  });

  final double openness;
  final String title;
  final String? subtitle;
  final IconData? icon;
  final List<AtelierHighlight> highlights;
  final double topInset;

  @override
  Widget build(BuildContext context) {
    final palette = context.atelier;
    final rtl = Directionality.of(context) == TextDirection.rtl;
    final radius = Radius.circular(DsRadius.xxl * (0.4 + 0.6 * openness));
    final gutter = MediaQuery.sizeOf(context).width < 600
        ? DsSpacing.md
        : DsSpacing.xl;
    final barOpacity = (1 - openness * 2.2).clamp(0.0, 1.0);
    final openOpacity = ((openness - 0.35) / 0.65).clamp(0.0, 1.0);

    return Stack(
      fit: StackFit.expand,
      children: [
        // The satin, edged at the bottom.
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: palette.headerGradient,
            borderRadius: BorderRadius.vertical(bottom: radius),
            boxShadow: context.glowShadow(
              DsColors.mauve700,
              blur: 20,
              alpha: 0.22,
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.vertical(bottom: radius),
            child: CustomPaint(
              painter: _SatinPainter(rtl: rtl),
              foregroundPainter: _HemPainter(
                color: DsColors.gold200.withValues(alpha: 0.6),
                radius: radius.x,
              ),
            ),
          ),
        ),
        // The slim bar's title, as the banner folds away. Built only while it
        // shows, so the page has one title and not two.
        if (barOpacity > 0)
          Positioned(
            top: topInset,
            left: DsSizes.appBarHeight + DsSpacing.xs,
            right: DsSizes.appBarHeight + DsSpacing.xs,
            height: DsSizes.appBarHeight,
            child: Opacity(
              opacity: barOpacity,
              child: Center(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.dsText.sectionTitle.displayFamily.bold.tint(
                    DsColors.onMedia,
                  ),
                ),
              ),
            ),
          ),
        // The open banner's content, rising and fading as it folds.
        if (openOpacity > 0)
          Positioned(
            left: gutter,
            right: gutter,
            bottom: DsSpacing.xl,
            child: IgnorePointer(
              ignoring: openness < 0.5,
              child: Opacity(
                opacity: openOpacity,
                child: Transform.translate(
                  offset: Offset(0, (1 - openness) * DsSpacing.lg),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          if (icon != null) ...[
                            _Medallion(icon: icon!),
                            DsGaps.hMd,
                          ],
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: context
                                      .dsText
                                      .pageTitle
                                      .displayFamily
                                      .bold
                                      .tint(DsColors.onMedia),
                                ),
                                if (subtitle != null) ...[
                                  DsGaps.vXxs,
                                  Text(
                                    subtitle!,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: context.dsText.body.tint(
                                      DsColors.onMediaMuted,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                      if (highlights.isNotEmpty) ...[
                        DsGaps.vMd,
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              for (final (i, h) in highlights.indexed) ...[
                                if (i > 0)
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: DsSpacing.md,
                                    ),
                                    child: Text(
                                      '·',
                                      style: context.dsText.bodyLarge.tint(
                                        DsColors.onMediaFaint,
                                      ),
                                    ),
                                  ),
                                Text(
                                  h.value,
                                  style: context.dsText.metric.displayFamily
                                      .tint(DsColors.gold200),
                                ),
                                DsGaps.hXs,
                                Text(
                                  h.label,
                                  style: context.dsText.labelMedium.tint(
                                    DsColors.onMediaMuted,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// The edge: a dotted champagne line just above the banner's bottom.
class _HemPainter extends CustomPainter {
  const _HemPainter({required this.color, required this.radius});

  final Color color;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final y = size.height - DsSpacing.xs;
    final inset = math.max(radius * 0.7, DsSpacing.md);
    final path = Path()
      ..moveTo(inset, y)
      ..lineTo(size.width - inset, y);
    _dashed(
      canvas,
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4
        ..strokeCap = StrokeCap.round
        ..color = color,
    );
  }

  @override
  bool shouldRepaint(_HemPainter old) =>
      old.color != color || old.radius != radius;
}

/// A room's medallion on the banner: a champagne ring round a plum face, like
/// the seal on a gift box, with the room's icon in it.
class _Medallion extends StatelessWidget {
  const _Medallion({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: DsSizes.controlLg,
      height: DsSizes.controlLg,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const RadialGradient(
          colors: [DsColors.mauve600, DsColors.mauve800],
        ),
        border: Border.all(color: DsColors.gold300, width: 2.5),
      ),
      child: Icon(icon, color: DsColors.gold100, size: DsSizes.iconMd),
    );
  }
}

/// The side margin of a seller page: the full gutter on a tablet, a phone's
/// narrower one below 600dp.
double atelierGutter(BuildContext context) =>
    MediaQuery.sizeOf(context).width < 600 ? DsSpacing.md : DsSpacing.xl;

// ---------------------------------------------------------------------------
// The ticket
// ---------------------------------------------------------------------------

/// An order ticket: a card with a tear-off stub on its far side.
///
/// The body says what the job is and what to do next; the stub — divided
/// off by a perforation with a notch punched top and bottom — carries the
/// figure and the state, tinted in [stubColor], so a column of tickets reads
/// as a column of states before a word of it is read.
class OrderTicket extends StatelessWidget {
  const OrderTicket({
    super.key,
    required this.body,
    required this.stub,
    required this.stubColor,
    this.onTap,
    this.stubWidth = 108,
  });

  final Widget body;
  final Widget stub;
  final Color stubColor;
  final VoidCallback? onTap;
  final double stubWidth;

  static const double _notch = 9;

  @override
  Widget build(BuildContext context) {
    final palette = context.atelier;
    final rtl = Directionality.of(context) == TextDirection.rtl;
    final clipper = _TicketClipper(stubWidth: stubWidth, rtl: rtl);

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: DsRadius.borderXl,
        boxShadow: [
          for (final shadow in palette.shadow)
            BoxShadow(
              color: shadow.color.withValues(alpha: shadow.color.a * 0.6),
              blurRadius: shadow.blurRadius,
              offset: shadow.offset * 0.5,
            ),
        ],
      ),
      child: ClipPath(
        clipper: clipper,
        child: Material(
          color: palette.surface,
          child: InkWell(
            onTap: onTap,
            child: CustomPaint(
              painter: _TicketPainter(
                stubWidth: stubWidth,
                rtl: rtl,
                stub: stubColor,
                line: palette.line,
              ),
              child: IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: Padding(padding: DsSpacing.paddingMd, child: body),
                    ),
                    SizedBox(
                      width: stubWidth,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: DsSpacing.sm,
                          vertical: DsSpacing.md,
                        ),
                        child: stub,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

Path _ticketPath(Size size, double stubWidth, bool rtl) {
  final x = rtl ? stubWidth : size.width - stubWidth;
  const n = OrderTicket._notch;
  final outline = Path()
    ..addRRect(
      RRect.fromRectAndRadius(
        Offset.zero & size,
        const Radius.circular(DsRadius.xl),
      ),
    );
  final notches = Path()
    ..addOval(Rect.fromCircle(center: Offset(x, 0), radius: n))
    ..addOval(Rect.fromCircle(center: Offset(x, size.height), radius: n));
  return Path.combine(PathOperation.difference, outline, notches);
}

class _TicketClipper extends CustomClipper<Path> {
  const _TicketClipper({required this.stubWidth, required this.rtl});

  final double stubWidth;
  final bool rtl;

  @override
  Path getClip(Size size) => _ticketPath(size, stubWidth, rtl);

  @override
  bool shouldReclip(_TicketClipper old) =>
      old.stubWidth != stubWidth || old.rtl != rtl;
}

class _TicketPainter extends CustomPainter {
  const _TicketPainter({
    required this.stubWidth,
    required this.rtl,
    required this.stub,
    required this.line,
  });

  final double stubWidth;
  final bool rtl;
  final Color stub;
  final Color line;

  @override
  void paint(Canvas canvas, Size size) {
    final x = rtl ? stubWidth : size.width - stubWidth;
    final stubRect = rtl
        ? Rect.fromLTRB(0, 0, x, size.height)
        : Rect.fromLTRB(x, 0, size.width, size.height);
    canvas.drawRect(
      stubRect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [stub.withValues(alpha: 0.14), stub.withValues(alpha: 0.06)],
        ).createShader(stubRect),
    );
    // The perforation.
    _dashed(
      canvas,
      Path()
        ..moveTo(x, OrderTicket._notch + 3)
        ..lineTo(x, size.height - OrderTicket._notch - 3),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4
        ..strokeCap = StrokeCap.round
        ..color = stub.withValues(alpha: 0.5),
      dash: 4,
      gap: 4,
    );
    // The outline, notches and all.
    canvas.drawPath(
      _ticketPath(size, stubWidth, rtl),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = line,
    );
  }

  @override
  bool shouldRepaint(_TicketPainter old) =>
      old.stubWidth != stubWidth ||
      old.rtl != rtl ||
      old.stub != stub ||
      old.line != line;
}

/// Filters as a row of beads, in the seller's colours: the chosen bead
/// plum with a champagne edge, the rest quiet, each with its count.
class AtelierBeads<T> extends StatelessWidget {
  const AtelierBeads({
    super.key,
    required this.options,
    required this.selected,
    required this.onSelected,
    this.padding,
  });

  final List<({T value, String label, int? count})> options;
  final T selected;
  final ValueChanged<T> onSelected;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final palette = context.atelier;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: padding,
      child: Row(
        children: [
          for (final option in options)
            Padding(
              padding: const EdgeInsetsDirectional.only(end: DsSpacing.xs),
              child: _AtelierBead(
                label: option.label,
                count: option.count,
                selected: option.value == selected,
                palette: palette,
                onTap: () => onSelected(option.value),
              ),
            ),
        ],
      ),
    );
  }
}

class _AtelierBead extends StatelessWidget {
  const _AtelierBead({
    required this.label,
    required this.count,
    required this.selected,
    required this.palette,
    required this.onTap,
  });

  final String label;
  final int? count;
  final bool selected;
  final SellerAtelierPalette palette;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ink = selected ? DsColors.onMedia : palette.ink;
    return Semantics(
      button: true,
      selected: selected,
      label: count == null ? label : '$label، $count',
      excludeSemantics: true,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: DsRadius.borderPill,
          onTap: onTap,
          child: AnimatedContainer(
            duration: DsReducedMotion.duration(DsMotion.normal),
            curve: DsMotion.gentle,
            padding: const EdgeInsets.symmetric(
              horizontal: DsSpacing.md,
              vertical: DsSpacing.xs,
            ),
            decoration: BoxDecoration(
              borderRadius: DsRadius.borderPill,
              gradient: selected ? palette.headerGradient : null,
              color: selected ? null : palette.surface,
              border: Border.all(
                color: selected
                    ? DsColors.gold300.withValues(alpha: 0.7)
                    : palette.line,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: context.dsText.labelLarge
                      .copyWith(
                        fontWeight: selected
                            ? DsTypography.semiBold
                            : DsTypography.medium,
                      )
                      .tint(ink),
                ),
                if (count != null) ...[
                  DsGaps.hXs,
                  Container(
                    constraints: const BoxConstraints(minWidth: DsSpacing.lg),
                    padding: const EdgeInsets.symmetric(
                      horizontal: DsSpacing.xxs + DsSpacing.xxxs,
                    ),
                    decoration: BoxDecoration(
                      color: selected ? DsColors.gold200 : palette.goldSoft,
                      borderRadius: DsRadius.borderPill,
                    ),
                    child: Text(
                      '$count',
                      textAlign: TextAlign.center,
                      style: context.dsText.badge.tint(
                        selected ? DsColors.onGold : palette.gold,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// One pearl on a dotted line, for a journey drawn down the page: an order's
/// steps, a return's history. Painted the full height of its row so a list of
/// them reads as one line; [done] lights the pearl champagne.
class JourneyBead extends StatelessWidget {
  const JourneyBead({
    super.key,
    required this.first,
    required this.last,
    this.done = false,
  });

  final bool first;
  final bool last;
  final bool done;

  @override
  Widget build(BuildContext context) {
    final palette = context.atelier;
    return SizedBox(
      width: DsSizes.iconMd,
      child: CustomPaint(
        painter: _AtelierBeadPainter(
          first: first,
          last: last,
          done: done,
          silk: palette.primary,
          gold: palette.gold,
          ground: palette.surface,
        ),
      ),
    );
  }
}

class _AtelierBeadPainter extends CustomPainter {
  const _AtelierBeadPainter({
    required this.first,
    required this.last,
    required this.done,
    required this.silk,
    required this.gold,
    required this.ground,
  });

  final bool first;
  final bool last;
  final bool done;
  final Color silk;
  final Color gold;
  final Color ground;

  static const double _beadY = DsSpacing.sm;

  @override
  void paint(Canvas canvas, Size size) {
    final x = size.width / 2;
    _dashed(
      canvas,
      Path()
        ..moveTo(x, first ? _beadY : 0)
        ..lineTo(x, last ? _beadY : size.height),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.8
        ..strokeCap = StrokeCap.round
        ..color = silk.withValues(alpha: 0.5),
      dash: 5,
      gap: 4,
    );
    final bead = Offset(x, _beadY);
    canvas.drawCircle(bead, 6.5, Paint()..color = ground);
    canvas.drawCircle(
      bead,
      6.5,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = done ? gold : silk.withValues(alpha: 0.6),
    );
    canvas.drawCircle(bead, 3, Paint()..color = done ? gold : silk);
  }

  @override
  bool shouldRepaint(_AtelierBeadPainter old) =>
      old.first != first ||
      old.last != last ||
      old.done != done ||
      old.silk != silk ||
      old.gold != gold ||
      old.ground != ground;
}

// ---------------------------------------------------------------------------
// The gift tag
// ---------------------------------------------------------------------------

/// A product as a gift tag: a card whose leading corners are clipped like a
/// tag's, with an eyelet punched near its leading edge. Every boutique ties a
/// tag to what it sells, whatever it sells.
class GiftTagCard extends StatelessWidget {
  const GiftTagCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding = DsSpacing.paddingMd,
  });

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final palette = context.atelier;
    final rtl = Directionality.of(context) == TextDirection.rtl;
    final clipper = _TagClipper(rtl: rtl);
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: DsRadius.borderXl,
        boxShadow: [
          for (final shadow in palette.shadow)
            BoxShadow(
              color: shadow.color.withValues(alpha: shadow.color.a * 0.6),
              blurRadius: shadow.blurRadius,
              offset: shadow.offset * 0.5,
            ),
        ],
      ),
      child: ClipPath(
        clipper: clipper,
        child: Material(
          color: palette.surface,
          child: InkWell(
            onTap: onTap,
            child: CustomPaint(
              foregroundPainter: _TagEdgePainter(rtl: rtl, line: palette.line),
              child: Padding(
                padding: padding.add(
                  EdgeInsetsDirectional.only(start: _TagClipper.tooth * 2),
                ),
                child: child,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

Path _tagPath(Size size, bool rtl) {
  const cut = _TagClipper.tooth * 3;
  const r = DsRadius.xl;
  // Built left-to-right with the tag's clipped corners on the left, then
  // mirrored for a right-to-left page so they are always on the leading
  // side.
  final path = Path()
    ..moveTo(cut, 0)
    ..lineTo(size.width - r, 0)
    ..quadraticBezierTo(size.width, 0, size.width, r)
    ..lineTo(size.width, size.height - r)
    ..quadraticBezierTo(size.width, size.height, size.width - r, size.height)
    ..lineTo(cut, size.height)
    ..lineTo(0, size.height - cut)
    ..lineTo(0, cut)
    ..close();
  // The eyelet, punched through.
  final eyelet = Path()
    ..addOval(
      Rect.fromCircle(
        center: Offset(_TagClipper.tooth * 1.6, size.height / 2),
        radius: _TagClipper.tooth * 0.7,
      ),
    );
  final tag = Path.combine(PathOperation.difference, path, eyelet);
  if (!rtl) return tag;
  return tag.transform(
    (Matrix4.identity()
          ..translateByDouble(size.width, 0, 0, 1)
          ..scaleByDouble(-1, 1, 1, 1))
        .storage,
  );
}

class _TagClipper extends CustomClipper<Path> {
  const _TagClipper({required this.rtl});

  final bool rtl;

  static const double tooth = 6;

  @override
  Path getClip(Size size) => _tagPath(size, rtl);

  @override
  bool shouldReclip(_TagClipper old) => old.rtl != rtl;
}

class _TagEdgePainter extends CustomPainter {
  const _TagEdgePainter({required this.rtl, required this.line});

  final bool rtl;
  final Color line;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawPath(
      _tagPath(size, rtl),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = line,
    );
  }

  @override
  bool shouldRepaint(_TagEdgePainter old) => old.rtl != rtl || old.line != line;
}

/// A level as a length of satin ribbon: a champagne track, filled up to
/// [value] of [max] in [color], with a line of sheen along the top.
class RibbonGauge extends StatelessWidget {
  const RibbonGauge({
    super.key,
    required this.value,
    required this.max,
    required this.color,
    this.height = DsSpacing.sm,
  });

  final double value;
  final double max;
  final Color color;
  final double height;

  @override
  Widget build(BuildContext context) {
    final palette = context.atelier;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: max <= 0 ? 0 : (value / max).clamp(0.0, 1.0)),
      duration: DsReducedMotion.duration(DsMotion.slow),
      curve: DsMotion.gentle,
      builder: (context, fraction, _) => CustomPaint(
        size: Size(double.infinity, height),
        painter: _RibbonGaugePainter(
          fraction: fraction,
          color: color,
          track: palette.goldSoft,
          tick: palette.gold,
          rtl: Directionality.of(context) == TextDirection.rtl,
        ),
      ),
    );
  }
}

class _RibbonGaugePainter extends CustomPainter {
  const _RibbonGaugePainter({
    required this.fraction,
    required this.color,
    required this.track,
    required this.tick,
    required this.rtl,
  });

  final double fraction;
  final Color color;
  final Color track;
  final Color tick;
  final bool rtl;

  @override
  void paint(Canvas canvas, Size size) {
    final r = Radius.circular(size.height / 2);
    canvas.drawRRect(
      RRect.fromRectAndRadius(Offset.zero & size, r),
      Paint()..color = track,
    );
    final w = size.width * fraction;
    if (w <= 0) return;
    final filled = rtl
        ? Rect.fromLTWH(size.width - w, 0, w, size.height)
        : Rect.fromLTWH(0, 0, w, size.height);
    canvas.drawRRect(
      RRect.fromRectAndRadius(filled, r),
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color.lerp(color, DsColors.onMedia, 0.25)!, color],
        ).createShader(filled),
    );
    // The sheen, a fine light line along the top of the satin.
    final y = size.height * 0.3;
    canvas.drawLine(
      Offset(filled.left + size.height / 2, y),
      Offset(
        math.max(filled.left + size.height / 2, filled.right - size.height / 2),
        y,
      ),
      Paint()
        ..strokeWidth = math.max(1, size.height * 0.14)
        ..strokeCap = StrokeCap.round
        ..color = DsColors.onMedia.withValues(alpha: 0.4),
    );
  }

  @override
  bool shouldRepaint(_RibbonGaugePainter old) =>
      old.fraction != fraction ||
      old.color != color ||
      old.track != track ||
      old.tick != tick ||
      old.rtl != rtl;
}
