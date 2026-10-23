import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:reem/core/design_system/design_system.dart';

/// The buying register: **a boutique's paper bag, a ticket, a receipt**.
///
/// Buying on Reem is shopping in a street of boutiques, and these are the
/// things that street hands you:
///
/// * [BoutiqueBag] — one bag per boutique, rope handles and all, with its name
///   on a hanging gift tag. The cart is the bags she is carrying.
/// * [ArchFrame] — a piece's photograph cut to Reem's arch.
/// * [TicketBar] — the floating ticket the total and the next step ride on,
///   notched at both ends like a stub.
/// * [JourneyStep] — checkout as stations on one silk thread, each marked by
///   a small arch that fills once the station is done.
/// * [PerforatedTicket] — a coupon, cut out along its perforations.
/// * [ReceiptCard] — the summary on paper with a torn, zigzag foot.

// ---------------------------------------------------------------------------
// Boutique bag
// ---------------------------------------------------------------------------

/// One boutique's share of the basket, drawn as its shopping bag.
class BoutiqueBag extends StatelessWidget {
  const BoutiqueBag({
    super.key,
    required this.name,
    required this.child,
    this.avatar,
    this.caption,
    this.trailing,
  });

  /// The boutique's name, written on the tag.
  final String name;

  /// Its mark, beside the name.
  final Widget? avatar;

  /// A line under the name — how many pieces, for instance.
  final String? caption;

  /// At the far end of the tag row — the bag's subtotal.
  final Widget? trailing;
  final Widget child;

  static const double _handleHeight = 30;

  @override
  Widget build(BuildContext context) {
    final colors = context.dsColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final paper = isDark ? colors.surfaceElevated : colors.surface;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: _handleHeight,
          child: CustomPaint(
            painter: _HandlesPainter(
              front: DsColors.gold400,
              back: DsColors.gold300.withValues(alpha: 0.45),
              rivet: DsColors.gold600,
            ),
          ),
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: const BorderRadius.only(
              topLeft: DsRadius.circularSm,
              topRight: DsRadius.circularSm,
              bottomLeft: DsRadius.circularXxl,
              bottomRight: DsRadius.circularXxl,
            ),
            boxShadow: [
              BoxShadow(
                color: colors.shadow,
                blurRadius: 30,
                offset: const Offset(0, 14),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: const BorderRadius.only(
              topLeft: DsRadius.circularSm,
              topRight: DsRadius.circularSm,
              bottomLeft: DsRadius.circularXxl,
              bottomRight: DsRadius.circularXxl,
            ),
            child: DecoratedBox(
              decoration: BoxDecoration(
                // The bag's paper, with its folded sides catching less light.
                gradient: LinearGradient(
                  colors: [
                    Color.alphaBlend(
                      colors.primary.withValues(alpha: 0.05),
                      paper,
                    ),
                    paper,
                    paper,
                    Color.alphaBlend(
                      colors.primary.withValues(alpha: 0.05),
                      paper,
                    ),
                  ],
                  stops: const [0, 0.08, 0.92, 1],
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // The folded rim at the mouth of the bag.
                  Container(
                    height: DsSpacing.sm,
                    decoration: const BoxDecoration(gradient: DsGradients.gold),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      DsSpacing.md,
                      DsSpacing.md,
                      DsSpacing.md,
                      DsSpacing.xs,
                    ),
                    child: _GiftTag(
                      name: name,
                      avatar: avatar,
                      caption: caption,
                      trailing: trailing,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      DsSpacing.md,
                      DsSpacing.xs,
                      DsSpacing.md,
                      DsSpacing.md,
                    ),
                    child: child,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _HandlesPainter extends CustomPainter {
  const _HandlesPainter({
    required this.front,
    required this.back,
    required this.rivet,
  });

  final Color front;
  final Color back;
  final Color rivet;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    void rope(double from, double to, Color colour, double lift) {
      final path = Path()
        ..moveTo(w * from, h + 2)
        ..cubicTo(w * from, lift, w * to, lift, w * to, h + 2);
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3.2
          ..strokeCap = StrokeCap.round
          ..color = colour,
      );
    }

    // The back handle first, a shade lighter and a little offset.
    rope(0.38, 0.70, back, -h * 0.35);
    rope(0.33, 0.67, front, -h * 0.55);
    for (final x in const [0.33, 0.67]) {
      canvas.drawCircle(Offset(w * x, h - 1), 3.5, Paint()..color = rivet);
    }
  }

  @override
  bool shouldRepaint(_HandlesPainter old) =>
      old.front != front || old.back != back || old.rivet != rivet;
}

/// The tag tied to the bag: a card with a pointed end and a punched hole.
class _GiftTag extends StatelessWidget {
  const _GiftTag({
    required this.name,
    required this.avatar,
    required this.caption,
    required this.trailing,
  });

  final String name;
  final Widget? avatar;
  final String? caption;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final colors = context.dsColors;
    final rtl = Directionality.of(context) == TextDirection.rtl;
    return CustomPaint(
      painter: _TagPainter(
        fill: colors.accentContainer.withValues(alpha: 0.7),
        edge: DsColors.gold300.withValues(alpha: 0.7),
        hole: colors.surface,
        pointAtStart: true,
        rtl: rtl,
      ),
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(
          DsSpacing.xl + DsSpacing.xs,
          DsSpacing.xs,
          DsSpacing.sm,
          DsSpacing.xs,
        ),
        child: Row(
          children: [
            if (avatar != null) ...[avatar!, DsGaps.hSm],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.dsText.cardTitle.bold,
                  ),
                  if (caption != null)
                    Text(caption!, style: context.dsText.caption),
                ],
              ),
            ),
            ?trailing,
          ],
        ),
      ),
    );
  }
}

class _TagPainter extends CustomPainter {
  const _TagPainter({
    required this.fill,
    required this.edge,
    required this.hole,
    required this.pointAtStart,
    required this.rtl,
  });

  final Color fill;
  final Color edge;
  final Color hole;
  final bool pointAtStart;
  final bool rtl;

  @override
  void paint(Canvas canvas, Size size) {
    final pointLeft = pointAtStart != rtl;
    const notch = 18.0;
    const r = 10.0;
    final w = size.width;
    final h = size.height;

    final path = Path();
    if (pointLeft) {
      path
        ..moveTo(notch, 0)
        ..lineTo(w - r, 0)
        ..quadraticBezierTo(w, 0, w, r)
        ..lineTo(w, h - r)
        ..quadraticBezierTo(w, h, w - r, h)
        ..lineTo(notch, h)
        ..lineTo(0, h / 2)
        ..close();
    } else {
      path
        ..moveTo(w - notch, 0)
        ..lineTo(r, 0)
        ..quadraticBezierTo(0, 0, 0, r)
        ..lineTo(0, h - r)
        ..quadraticBezierTo(0, h, r, h)
        ..lineTo(w - notch, h)
        ..lineTo(w, h / 2)
        ..close();
    }
    canvas.drawPath(path, Paint()..color = fill);
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = edge,
    );
    final holeAt = Offset(pointLeft ? notch + 2 : w - notch - 2, h / 2);
    canvas.drawCircle(holeAt, 4, Paint()..color = hole);
    canvas.drawCircle(
      holeAt,
      4,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = edge,
    );
  }

  @override
  bool shouldRepaint(_TagPainter old) =>
      old.fill != fill ||
      old.edge != edge ||
      old.hole != hole ||
      old.pointAtStart != pointAtStart ||
      old.rtl != rtl;
}

// ---------------------------------------------------------------------------
// Arch frame
// ---------------------------------------------------------------------------

/// A piece's photograph cut to the arch, with a fine champagne line inside.
class ArchFrame extends StatelessWidget {
  const ArchFrame({
    super.key,
    required this.child,
    this.width = 76,
    this.dimmed = false,
  });

  final Widget child;
  final double width;

  /// Greys the picture — for a piece that can no longer be bought.
  final bool dimmed;

  @override
  Widget build(BuildContext context) {
    final height = width * 1.28;
    Widget picture = ClipPath(
      clipper: const DsArchClipper(),
      child: SizedBox(width: width, height: height, child: child),
    );
    if (dimmed) {
      picture = ColorFiltered(
        colorFilter: const ColorFilter.matrix(<double>[
          0.33, 0.33, 0.33, 0, 0, //
          0.33, 0.33, 0.33, 0, 0,
          0.33, 0.33, 0.33, 0, 0,
          0, 0, 0, 0.6, 0,
        ]),
        child: picture,
      );
    }
    return SizedBox(
      width: width,
      height: height,
      child: CustomPaint(
        foregroundPainter: _ArchLinePainter(
          colour: DsColors.onMedia.withValues(alpha: 0.55),
        ),
        child: picture,
      ),
    );
  }
}

class _ArchLinePainter extends CustomPainter {
  const _ArchLinePainter({required this.colour});

  final Color colour;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawPath(
      dsArchPath((Offset.zero & size).deflate(4)),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = colour,
    );
  }

  @override
  bool shouldRepaint(_ArchLinePainter old) => old.colour != colour;
}

// ---------------------------------------------------------------------------
// Tickets
// ---------------------------------------------------------------------------

/// A shape with a semicircular notch cut into each end at mid-height — the
/// outline of a ticket stub.
class TicketBorder extends ShapeBorder {
  const TicketBorder({
    this.radius = DsRadius.xl,
    this.notch = 10,
    this.side = BorderSide.none,
  });

  final double radius;
  final double notch;
  final BorderSide side;

  @override
  EdgeInsetsGeometry get dimensions => EdgeInsets.all(side.width);

  Path _path(Rect rect) {
    final outer = Path()
      ..addRRect(RRect.fromRectAndRadius(rect, Radius.circular(radius)));
    final cuts = Path()
      ..addOval(
        Rect.fromCircle(
          center: Offset(rect.left, rect.center.dy),
          radius: notch,
        ),
      )
      ..addOval(
        Rect.fromCircle(
          center: Offset(rect.right, rect.center.dy),
          radius: notch,
        ),
      );
    return Path.combine(PathOperation.difference, outer, cuts);
  }

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) =>
      _path(rect.deflate(side.width));

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) => _path(rect);

  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {
    if (side.style == BorderStyle.none || side.width == 0) return;
    canvas.drawPath(_path(rect.deflate(side.width / 2)), side.toPaint());
  }

  @override
  ShapeBorder scale(double t) =>
      TicketBorder(radius: radius * t, notch: notch * t, side: side.scale(t));
}

/// The floating ticket a total and its next step ride on, held clear of the
/// screen's edges and its home indicator.
class TicketBar extends StatelessWidget {
  const TicketBar({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = context.dsColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        DsSpacing.md,
        DsSpacing.xs,
        DsSpacing.md,
        DsSpacing.md + MediaQuery.paddingOf(context).bottom,
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: DsSpacing.lg,
          vertical: DsSpacing.md,
        ),
        decoration: ShapeDecoration(
          color: (isDark ? colors.surfaceElevated : colors.surface).withValues(
            alpha: 0.97,
          ),
          shape: TicketBorder(
            notch: 9,
            side: BorderSide(color: DsColors.gold300.withValues(alpha: 0.6)),
          ),
          shadows: [
            BoxShadow(
              color: colors.shadow,
              blurRadius: 30,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: child,
      ),
    );
  }
}

/// A coupon field cut out of a perforated ticket, with scissors at the cut.
class PerforatedTicket extends StatelessWidget {
  const PerforatedTicket({super.key, required this.child, this.active = false});

  final Widget child;

  /// Lit once a code has been accepted.
  final bool active;

  @override
  Widget build(BuildContext context) {
    final colors = context.dsColors;
    final edge = active ? colors.success : DsColors.gold300;
    return Container(
      padding: const EdgeInsetsDirectional.fromSTEB(
        DsSpacing.md,
        DsSpacing.sm,
        DsSpacing.md,
        DsSpacing.sm,
      ),
      decoration: ShapeDecoration(
        color: active
            ? colors.successContainer
            : colors.accentContainer.withValues(alpha: 0.45),
        shape: TicketBorder(
          radius: DsRadius.lg,
          notch: 8,
          side: BorderSide(color: edge.withValues(alpha: 0.8)),
        ),
      ),
      child: Row(
        children: [
          Icon(
            active ? Icons.check_circle_rounded : Icons.content_cut_rounded,
            size: DsSizes.iconSm,
            color: active ? colors.success : DsColors.gold600,
          ),
          DsGaps.hSm,
          // The perforation between the stub and the field.
          CustomPaint(
            size: const Size(1, 40),
            painter: _DashPainter(colour: edge, vertical: true),
          ),
          DsGaps.hSm,
          Expanded(child: child),
        ],
      ),
    );
  }
}

class _DashPainter extends CustomPainter {
  const _DashPainter({required this.colour, this.vertical = false});

  final Color colour;
  final bool vertical;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = colour
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round;
    const dash = 4.0;
    const gap = 4.0;
    final length = vertical ? size.height : size.width;
    for (var at = 0.0; at < length; at += dash + gap) {
      final end = math.min(at + dash, length);
      if (vertical) {
        canvas.drawLine(Offset(0, at), Offset(0, end), paint);
      } else {
        canvas.drawLine(Offset(at, 0), Offset(end, 0), paint);
      }
    }
  }

  @override
  bool shouldRepaint(_DashPainter old) =>
      old.colour != colour || old.vertical != vertical;
}

/// A dashed hairline across a receipt.
class DashedRule extends StatelessWidget {
  const DashedRule({super.key, this.color});

  final Color? color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 1,
      width: double.infinity,
      child: CustomPaint(
        painter: _DashPainter(colour: color ?? context.dsColors.outline),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Journey
// ---------------------------------------------------------------------------

/// One station on the checkout's thread: an arch marker with its number — a
/// tick once the station is done — a title, and what is asked there.
///
/// The thread runs down from each marker to the next, rose where she has
/// been and faint where she has not, so the page shows how far she is.
class JourneyStep extends StatelessWidget {
  const JourneyStep({
    super.key,
    required this.number,
    required this.title,
    required this.child,
    this.complete = false,
    this.isLast = false,
  });

  final int number;
  final String title;
  final Widget child;
  final bool complete;
  final bool isLast;

  static const double _rail = 36;

  @override
  Widget build(BuildContext context) {
    final colors = context.dsColors;
    return Stack(
      children: [
        if (!isLast)
          PositionedDirectional(
            start: _rail / 2 - 1,
            top: 44,
            bottom: 0,
            width: 2,
            child: AnimatedContainer(
              duration: DsMotion.slow,
              decoration: BoxDecoration(
                borderRadius: DsRadius.borderPill,
                gradient: complete
                    ? LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [colors.primary, DsColors.gold300],
                      )
                    : null,
                color: complete ? null : colors.outline.withValues(alpha: 0.6),
              ),
            ),
          ),
        Padding(
          padding: EdgeInsets.only(bottom: isLast ? 0 : DsSpacing.xl),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _StepMarker(number: number, complete: complete),
              DsGaps.hMd,
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: DsSpacing.xs),
                      child: Text(
                        title,
                        style: context.dsText.sectionTitle.bold,
                      ),
                    ),
                    DsGaps.vMd,
                    child,
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _StepMarker extends StatelessWidget {
  const _StepMarker({required this.number, required this.complete});

  final int number;
  final bool complete;

  @override
  Widget build(BuildContext context) {
    final colors = context.dsColors;
    return SizedBox(
      width: JourneyStep._rail,
      height: 44,
      child: CustomPaint(
        painter: _MarkerPainter(
          fill: complete ? null : colors.surface,
          gradient: complete ? context.primaryGradient : null,
          edge: complete ? colors.primary : colors.outline,
        ),
        child: Align(
          alignment: const Alignment(0, 0.3),
          child: AnimatedSwitcher(
            duration: DsMotion.moderate,
            transitionBuilder: (child, animation) =>
                ScaleTransition(scale: animation, child: child),
            child: complete
                ? const Icon(
                    Icons.check_rounded,
                    key: ValueKey('done'),
                    size: DsSizes.iconXs,
                    color: DsColors.onMedia,
                  )
                : Text(
                    '$number',
                    key: ValueKey(number),
                    style: context.dsText.labelStrong.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

class _MarkerPainter extends CustomPainter {
  const _MarkerPainter({
    required this.fill,
    required this.gradient,
    required this.edge,
  });

  final Color? fill;
  final Gradient? gradient;
  final Color edge;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = (Offset.zero & size).deflate(1);
    final path = dsArchPath(rect);
    final paint = Paint();
    if (gradient != null) {
      paint.shader = gradient!.createShader(rect);
    } else {
      paint.color = fill!;
    }
    canvas.drawPath(path, paint);
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4
        ..color = edge,
    );
  }

  @override
  bool shouldRepaint(_MarkerPainter old) =>
      old.fill != fill || old.gradient != gradient || old.edge != edge;
}

// ---------------------------------------------------------------------------
// Receipt
// ---------------------------------------------------------------------------

/// The order summary on a strip of receipt paper with a torn, zigzag foot.
class ReceiptCard extends StatelessWidget {
  const ReceiptCard({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = context.dsColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return CustomPaint(
      painter: _ReceiptPainter(
        paper: isDark ? colors.surfaceElevated : colors.surface,
        shadow: colors.shadow,
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          DsSpacing.lg,
          DsSpacing.lg,
          DsSpacing.lg,
          DsSpacing.xl,
        ),
        child: child,
      ),
    );
  }
}

class _ReceiptPainter extends CustomPainter {
  const _ReceiptPainter({required this.paper, required this.shadow});

  final Color paper;
  final Color shadow;

  @override
  void paint(Canvas canvas, Size size) {
    const tooth = 8.0;
    const r = DsRadius.lg;
    final w = size.width;
    final h = size.height;
    final teeth = (w / (tooth * 2)).floor();
    final step = w / teeth;

    final path = Path()
      ..moveTo(0, r)
      ..quadraticBezierTo(0, 0, r, 0)
      ..lineTo(w - r, 0)
      ..quadraticBezierTo(w, 0, w, r)
      ..lineTo(w, h - tooth);
    for (var i = teeth; i > 0; i--) {
      final x = i * step;
      path
        ..lineTo(x - step / 2, h)
        ..lineTo(x - step, h - tooth);
    }
    path.close();

    canvas.drawShadow(path, shadow, 10, false);
    canvas.drawPath(path, Paint()..color = paper);
  }

  @override
  bool shouldRepaint(_ReceiptPainter old) =>
      old.paper != paper || old.shadow != shadow;
}
