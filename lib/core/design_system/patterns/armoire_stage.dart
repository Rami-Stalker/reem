import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:ohara/core/design_system/foundation/theme/extensions/color_extension.dart';
import 'package:ohara/core/design_system/foundation/theme/extensions/typography_extension.dart';
import 'package:ohara/core/design_system/foundation/tokens/ds_colors.dart';
import 'package:ohara/core/design_system/foundation/tokens/ds_radius.dart';
import 'package:ohara/core/design_system/foundation/tokens/ds_sizes.dart';
import 'package:ohara/core/design_system/foundation/tokens/ds_spacing.dart';

/// Her wardrobe, drawn as one: **the armoire**.
///
/// The closet used to be a grid of photographs under a rail of filter chips —
/// a catalogue that happened to hold her own clothes. A wardrobe is not
/// browsed like that. She opens the drawer the necklace is in. So the closet
/// is drawn as the piece of furniture it is named after, and every part of it
/// is one of the pieces below.
///
/// * [ArmoireCarcass] — the lacquered body that holds everything.
/// * [ArmoireCrown] / [ArmoirePlinth] — the cornice on top and the feet.
/// * [ArmoireRecess] — an open compartment: a lit cavity in the body.
/// * [ArmoireRail], [ArmoireHanger], [ArmoirePeg], [ArmoirePlank] — what
///   clothes hang from and sit on.
/// * [ArmoireDrawerFront] / [ArmoirePull] — a drawer, closed or just ajar.
/// * [ArmoireVelvet] — the lining a drawer opens onto.
/// * [ArmoirePlaque] — an engraved name plate.
/// * [ArmoireBox] — a storage box sitting on top of the wardrobe.
/// * [ArmoireAddKnob] — the small brass "+" each compartment carries.
///
/// Ivory lacquer and champagne brass by day, aubergine lacquer at night:
/// everything resolves from [ArmoirePalette], so the furniture follows the
/// theme like the rest of her pages.
class ArmoirePalette {
  const ArmoirePalette({
    required this.lacquerLight,
    required this.lacquer,
    required this.lacquerDeep,
    required this.inlay,
    required this.cavity,
    required this.cavityDeep,
    required this.velvet,
    required this.velvetDeep,
    required this.brassLight,
    required this.brass,
    required this.brassDeep,
    required this.plaque,
    required this.plaqueInk,
    required this.plank,
    required this.plankEdge,
    required this.glow,
    required this.shade,
    required this.ink,
    required this.muted,
    required this.boxRose,
    required this.boxLinen,
    required this.isDark,
  });

  /// The lacquer of the body, lit side to shadow side.
  final Color lacquerLight;
  final Color lacquer;
  final Color lacquerDeep;

  /// The fine brass line set into the lacquer.
  final Color inlay;

  /// The inside of an open compartment, and the deepest part of it.
  final Color cavity;
  final Color cavityDeep;

  /// Drawer lining.
  final Color velvet;
  final Color velvetDeep;

  /// Hardware: rails, pulls, hooks and knobs.
  final Color brassLight;
  final Color brass;
  final Color brassDeep;

  /// Name plates and the engraving on them.
  final Color plaque;
  final Color plaqueInk;

  /// Shelf boards.
  final Color plank;
  final Color plankEdge;

  /// The warm light inside a compartment.
  final Color glow;

  /// Shadow cast inside and under the furniture.
  final Color shade;

  /// Words written on the lacquer.
  final Color ink;
  final Color muted;

  /// The two storage boxes on top: a rose one and a linen one.
  final Color boxRose;
  final Color boxLinen;

  final bool isDark;

  LinearGradient get lacquerGradient => LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [lacquerLight, lacquer, lacquerDeep],
    stops: const [0, .45, 1],
  );

  LinearGradient get brassGradient => LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [brassLight, brass, brassDeep],
    stops: const [0, .55, 1],
  );

  static ArmoirePalette of(BuildContext context) {
    final c = context.dsColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (isDark) {
      final lacquer = DsColors.secondary900;
      return ArmoirePalette(
        lacquerLight: Color.lerp(DsColors.secondary800, DsColors.surfaceVariantDark, .35)!,
        lacquer: lacquer,
        lacquerDeep: Color.lerp(lacquer, DsColors.backgroundDark, .55)!,
        inlay: DsColors.gold500.withValues(alpha: .55),
        cavity: Color.lerp(DsColors.backgroundDark, lacquer, .45)!,
        cavityDeep: DsColors.surfaceDimDark,
        velvet: Color.lerp(DsColors.secondary800, DsColors.primary900, .5)!,
        velvetDeep: Color.lerp(DsColors.secondary900, DsColors.primary900, .3)!,
        brassLight: DsColors.gold200,
        brass: DsColors.gold400,
        brassDeep: DsColors.gold700,
        plaque: Color.lerp(lacquer, DsColors.black, .28)!,
        plaqueInk: DsColors.gold200,
        plank: Color.lerp(DsColors.secondary800, DsColors.gold700, .3)!,
        plankEdge: Color.lerp(DsColors.secondary900, DsColors.gold700, .45)!,
        glow: DsColors.gold300.withValues(alpha: .20),
        shade: DsColors.black.withValues(alpha: .55),
        ink: c.onSurface,
        muted: c.onSurfaceVariant,
        boxRose: Color.lerp(DsColors.primary800, DsColors.secondary900, .35)!,
        boxLinen: Color.lerp(DsColors.gold700, DsColors.secondary900, .35)!,
        isDark: true,
      );
    }
    return ArmoirePalette(
      lacquerLight: Color.lerp(DsColors.gold50, DsColors.white, .6)!,
      lacquer: DsColors.gold50,
      lacquerDeep: Color.lerp(DsColors.gold100, DsColors.warmBeige, .35)!,
      inlay: DsColors.gold300.withValues(alpha: .75),
      cavity: Color.lerp(DsColors.gold50, DsColors.primary100, .28)!,
      cavityDeep: Color.lerp(DsColors.gold100, DsColors.primary100, .42)!,
      velvet: Color.lerp(DsColors.primary100, DsColors.primary200, .45)!,
      velvetDeep: Color.lerp(DsColors.primary200, DsColors.rosewood, .22)!,
      brassLight: DsColors.gold100,
      brass: DsColors.champagneGold,
      brassDeep: DsColors.gold600,
      plaque: Color.lerp(DsColors.gold50, DsColors.white, .45)!,
      plaqueInk: DsColors.gold700,
      plank: Color.lerp(DsColors.gold100, DsColors.white, .3)!,
      plankEdge: DsColors.gold300,
      glow: DsColors.gold100.withValues(alpha: .85),
      shade: DsColors.gold700.withValues(alpha: .30),
      ink: c.onSurface,
      muted: c.onSurfaceVariant,
      boxRose: DsColors.primary200,
      boxLinen: DsColors.warmBeige,
      isDark: false,
    );
  }
}

extension ArmoireContext on BuildContext {
  ArmoirePalette get armoire => ArmoirePalette.of(this);
}

// ---------------------------------------------------------------------------
// The body
// ---------------------------------------------------------------------------

/// The lacquered body of the wardrobe, with a brass line set into its edge.
class ArmoireCarcass extends StatelessWidget {
  const ArmoireCarcass({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(DsSpacing.sm),
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final a = context.armoire;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: a.lacquerGradient,
        borderRadius: DsRadius.borderMd,
        boxShadow: [
          BoxShadow(
            color: a.shade.withValues(alpha: a.isDark ? .6 : .35),
            blurRadius: DsSpacing.xxl,
            offset: const Offset(0, DsSpacing.md),
          ),
          BoxShadow(
            color: a.shade.withValues(alpha: a.isDark ? .4 : .18),
            blurRadius: DsSpacing.xs,
            offset: const Offset(0, DsSpacing.xxs),
          ),
        ],
      ),
      child: CustomPaint(
        foregroundPainter: _InlayPainter(color: a.inlay),
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}

class _InlayPainter extends CustomPainter {
  const _InlayPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = (Offset.zero & size).deflate(DsSpacing.xxs);
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(DsRadius.sm)),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = color,
    );
  }

  @override
  bool shouldRepaint(_InlayPainter old) => old.color != color;
}

/// The cornice: a stepped moulding wider than the body, with a frieze under
/// it that carries [child] — usually an [ArmoirePlaque].
class ArmoireCrown extends StatelessWidget {
  const ArmoireCrown({super.key, this.child});

  final Widget? child;

  static const double moulding = DsSpacing.md;

  @override
  Widget build(BuildContext context) {
    final a = context.armoire;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: moulding,
          child: CustomPaint(painter: _MouldingPainter(palette: a)),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: DsSpacing.xxs),
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: a.lacquerGradient,
              border: Border(
                bottom: BorderSide(color: a.inlay, width: DsSpacing.xxxs),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: DsSpacing.md,
                vertical: DsSpacing.xs,
              ),
              child: Center(child: child),
            ),
          ),
        ),
      ],
    );
  }
}

class _MouldingPainter extends CustomPainter {
  const _MouldingPainter({required this.palette});

  final ArmoirePalette palette;

  @override
  void paint(Canvas canvas, Size size) {
    final a = palette;
    final w = size.width;
    final h = size.height;
    // The cap: the widest step, a rounded slab.
    final cap = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, w, h * .42),
      const Radius.circular(DsRadius.xs),
    );
    canvas.drawRRect(
      cap.shift(const Offset(0, 2)),
      Paint()
        ..color = a.shade.withValues(alpha: .25)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
    );
    canvas.drawRRect(
      cap,
      Paint()..shader = a.lacquerGradient.createShader(cap.outerRect),
    );
    // The cove: a narrower step that curves back into the body.
    final cove = Path()
      ..moveTo(DsSpacing.xxs, h * .42)
      ..lineTo(w - DsSpacing.xxs, h * .42)
      ..quadraticBezierTo(w - DsSpacing.xxs, h, w - DsSpacing.xs, h)
      ..lineTo(DsSpacing.xs, h)
      ..quadraticBezierTo(DsSpacing.xxs, h, DsSpacing.xxs, h * .42)
      ..close();
    canvas.drawPath(
      cove,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [a.lacquerDeep, a.lacquer],
        ).createShader(Offset.zero & size),
    );
    // A brass bead along the cap's edge.
    canvas.drawLine(
      Offset(DsSpacing.xxs, h * .42),
      Offset(w - DsSpacing.xxs, h * .42),
      Paint()
        ..color = a.brass
        ..strokeWidth = 1.4,
    );
    // Light catching the top of the cap.
    canvas.drawLine(
      const Offset(DsSpacing.xs, 1),
      Offset(w - DsSpacing.xs, 1),
      Paint()
        ..color = DsColors.white.withValues(alpha: a.isDark ? .10 : .7)
        ..strokeWidth = 1,
    );
  }

  @override
  bool shouldRepaint(_MouldingPainter old) => old.palette.isDark != palette.isDark;
}

/// The base of the wardrobe and the two turned feet it stands on.
class ArmoirePlinth extends StatelessWidget {
  const ArmoirePlinth({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: DsSpacing.lg,
      child: CustomPaint(painter: _PlinthPainter(palette: context.armoire)),
    );
  }
}

class _PlinthPainter extends CustomPainter {
  const _PlinthPainter({required this.palette});

  final ArmoirePalette palette;

  @override
  void paint(Canvas canvas, Size size) {
    final a = palette;
    final w = size.width;
    final h = size.height;
    // The floor shadow.
    canvas.drawOval(
      Rect.fromLTWH(w * .04, h * .55, w * .92, h * .45),
      Paint()
        ..color = a.shade.withValues(alpha: a.isDark ? .55 : .30)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );
    // The plinth board.
    final board = RRect.fromRectAndCorners(
      Rect.fromLTWH(DsSpacing.xxs, 0, w - DsSpacing.xs, h * .38),
      bottomLeft: const Radius.circular(DsRadius.xs),
      bottomRight: const Radius.circular(DsRadius.xs),
    );
    canvas.drawRRect(
      board,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [a.lacquerDeep, a.lacquer],
        ).createShader(board.outerRect),
    );
    canvas.drawLine(
      Offset(DsSpacing.xxs, .5),
      Offset(w - DsSpacing.xxs, .5),
      Paint()
        ..color = a.brass
        ..strokeWidth = 1,
    );
    // The feet: tapered brass-capped turnings.
    for (final x in [w * .07, w * .93]) {
      final foot = Path()
        ..moveTo(x - DsSpacing.sm, h * .38)
        ..lineTo(x + DsSpacing.sm, h * .38)
        ..lineTo(x + DsSpacing.xxs, h * .92)
        ..lineTo(x - DsSpacing.xxs, h * .92)
        ..close();
      canvas.drawPath(
        foot,
        Paint()
          ..shader = LinearGradient(
            colors: [a.lacquerLight, a.lacquerDeep],
          ).createShader(foot.getBounds()),
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset(x, h * .92),
            width: DsSpacing.sm,
            height: DsSpacing.xxs,
          ),
          const Radius.circular(DsRadius.xs),
        ),
        Paint()..shader = a.brassGradient.createShader(Offset(x - 6, h * .88) & const Size(12, 4)),
      );
    }
  }

  @override
  bool shouldRepaint(_PlinthPainter old) => old.palette.isDark != palette.isDark;
}

// ---------------------------------------------------------------------------
// Inside the wardrobe
// ---------------------------------------------------------------------------

/// An open compartment: a cavity sunk into the lacquer, lit from the top by
/// a warm strip, with a soft inner shadow round its rim.
///
/// [lit] brightens the strip — the compartment light coming on as she opens
/// it.
class ArmoireRecess extends StatelessWidget {
  const ArmoireRecess({
    super.key,
    required this.child,
    this.lit = 0,
    this.radius = DsRadius.sm,
  });

  final Widget child;

  /// 0 — the resting glow; 1 — fully lit.
  final double lit;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final a = context.armoire;
    final shape = BorderRadius.circular(radius);
    return ClipRRect(
      borderRadius: shape,
      child: CustomPaint(
        painter: _CavityPainter(palette: a, lit: lit),
        foregroundPainter: _InnerShadowPainter(
          color: a.shade,
          radius: radius,
          depth: a.isDark ? 10 : 8,
        ),
        child: child,
      ),
    );
  }
}

class _CavityPainter extends CustomPainter {
  const _CavityPainter({required this.palette, required this.lit});

  final ArmoirePalette palette;
  final double lit;

  @override
  void paint(Canvas canvas, Size size) {
    final a = palette;
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [a.cavity, a.cavityDeep],
        ).createShader(rect),
    );
    // The light strip under the top rail, and the pool it throws.
    final pool = Rect.fromLTWH(
      -size.width * .1,
      -size.height * .55,
      size.width * 1.2,
      size.height * 1.25,
    );
    canvas.drawOval(
      pool,
      Paint()
        ..shader = RadialGradient(
          colors: [
            a.glow.withValues(alpha: (a.glow.a * (0.65 + 0.35 * lit)).clamp(0, 1)),
            a.glow.withValues(alpha: 0),
          ],
        ).createShader(pool),
    );
    if (lit > 0) {
      canvas.drawRect(
        rect,
        Paint()..color = DsColors.white.withValues(alpha: (a.isDark ? .06 : .16) * lit),
      );
    }
  }

  @override
  bool shouldRepaint(_CavityPainter old) =>
      old.lit != lit || old.palette.isDark != palette.isDark;
}

/// A shadow cast inward from every edge of a rounded rectangle.
class _InnerShadowPainter extends CustomPainter {
  const _InnerShadowPainter({
    required this.color,
    required this.radius,
    required this.depth,
  });

  final Color color;
  final double radius;
  final double depth;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final rrect = RRect.fromRectAndRadius(rect, Radius.circular(radius));
    canvas.save();
    canvas.clipRRect(rrect);
    final ring = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(rect.inflate(depth * 3))
      ..addRRect(rrect.shift(Offset(0, depth * .35)));
    canvas.drawPath(
      ring,
      Paint()
        ..color = color
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, depth * .7),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_InnerShadowPainter old) =>
      old.color != color || old.radius != radius || old.depth != depth;
}

/// A brass hanging rod with its two end brackets, across the full width.
class ArmoireRail extends StatelessWidget {
  const ArmoireRail({super.key, this.height = DsSpacing.sm});

  final double height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: height,
      child: CustomPaint(painter: _RailPainter(palette: context.armoire)),
    );
  }
}

class _RailPainter extends CustomPainter {
  const _RailPainter({required this.palette});

  final ArmoirePalette palette;

  @override
  void paint(Canvas canvas, Size size) {
    final a = palette;
    final cy = size.height * .5;
    final thickness = math.max(3.0, size.height * .34);
    final rod = RRect.fromRectAndRadius(
      Rect.fromLTRB(0, cy - thickness / 2, size.width, cy + thickness / 2),
      Radius.circular(thickness),
    );
    canvas.drawRRect(
      rod.shift(Offset(0, thickness * .8)),
      Paint()
        ..color = a.shade.withValues(alpha: .35)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
    );
    canvas.drawRRect(rod, Paint()..shader = a.brassGradient.createShader(rod.outerRect));
    canvas.drawLine(
      Offset(thickness, cy - thickness * .22),
      Offset(size.width - thickness, cy - thickness * .22),
      Paint()
        ..color = DsColors.white.withValues(alpha: .55)
        ..strokeWidth = 1,
    );
    // The brackets that hold it to the sides.
    for (final x in [0.0, size.width]) {
      final bracket = Rect.fromCenter(
        center: Offset(x, cy),
        width: thickness * 1.6,
        height: size.height,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(bracket, Radius.circular(thickness * .5)),
        Paint()..color = a.brassDeep,
      );
    }
  }

  @override
  bool shouldRepaint(_RailPainter old) => old.palette.isDark != palette.isDark;
}

/// A hanger seen from the front: the hook over the rail and the shoulders
/// below it. Sized by the box it is given.
class ArmoireHanger extends StatelessWidget {
  const ArmoireHanger({super.key, this.width = DsSizes.iconXl, this.height = DsSpacing.md});

  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: height,
      child: CustomPaint(painter: _HangerPainter(palette: context.armoire)),
    );
  }
}

class _HangerPainter extends CustomPainter {
  const _HangerPainter({required this.palette});

  final ArmoirePalette palette;

  @override
  void paint(Canvas canvas, Size size) {
    final a = palette;
    final w = size.width;
    final h = size.height;
    final cx = w / 2;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = math.max(1.4, h * .09)
      ..color = a.brassDeep;
    // The hook, curling over the rail at the top.
    final hook = Path()
      ..moveTo(cx, h * .5)
      ..lineTo(cx, h * .3)
      ..arcToPoint(
        Offset(cx - h * .18, h * .1),
        radius: Radius.circular(h * .14),
        clockwise: false,
      );
    canvas.drawPath(hook, paint);
    // The shoulders.
    final shoulders = Path()
      ..moveTo(cx, h * .5)
      ..quadraticBezierTo(cx - w * .2, h * .66, w * .04, h * .96)
      ..lineTo(w * .96, h * .96)
      ..quadraticBezierTo(cx + w * .2, h * .66, cx, h * .5);
    canvas.drawPath(
      shoulders,
      paint
        ..color = a.brass
        ..strokeWidth = math.max(1.6, h * .11),
    );
  }

  @override
  bool shouldRepaint(_HangerPainter old) => old.palette.isDark != palette.isDark;
}

/// A round brass peg for a bag or a scarf to hang from.
class ArmoirePeg extends StatelessWidget {
  const ArmoirePeg({super.key, this.size = DsSpacing.sm});

  final double size;

  @override
  Widget build(BuildContext context) {
    final a = context.armoire;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          center: const Alignment(-.35, -.4),
          colors: [a.brassLight, a.brass, a.brassDeep],
          stops: const [0, .55, 1],
        ),
        boxShadow: [
          BoxShadow(
            color: a.shade.withValues(alpha: .5),
            blurRadius: 2,
            offset: const Offset(0, 1.5),
          ),
        ],
      ),
    );
  }
}

/// A shelf board: its top face, its front edge, and the shadow under it.
/// [slant] tilts the top face back, the way a shoe shelf sits.
class ArmoirePlank extends StatelessWidget {
  const ArmoirePlank({super.key, this.height = DsSpacing.sm, this.slant = false});

  final double height;
  final bool slant;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: height,
      child: CustomPaint(
        painter: _PlankPainter(palette: context.armoire, slant: slant),
      ),
    );
  }
}

class _PlankPainter extends CustomPainter {
  const _PlankPainter({required this.palette, required this.slant});

  final ArmoirePalette palette;
  final bool slant;

  @override
  void paint(Canvas canvas, Size size) {
    final a = palette;
    final w = size.width;
    final h = size.height;
    final faceDepth = h * (slant ? .55 : .42);
    final inset = slant ? h * .9 : h * .45;
    // The top face, receding.
    final face = Path()
      ..moveTo(inset, 0)
      ..lineTo(w - inset, 0)
      ..lineTo(w, faceDepth)
      ..lineTo(0, faceDepth)
      ..close();
    canvas.drawPath(
      face,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color.lerp(a.plank, a.cavityDeep, .35)!, a.plank],
        ).createShader(Rect.fromLTWH(0, 0, w, faceDepth)),
    );
    // The front edge.
    final edge = Rect.fromLTWH(0, faceDepth, w, h * .38);
    canvas.drawRect(
      edge,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [a.plankEdge, Color.lerp(a.plankEdge, a.shade, .35)!],
        ).createShader(edge),
    );
    canvas.drawLine(
      Offset(0, faceDepth),
      Offset(w, faceDepth),
      Paint()
        ..color = DsColors.white.withValues(alpha: a.isDark ? .12 : .65)
        ..strokeWidth = 1,
    );
    // The shadow it casts on the back of the cavity.
    final shadow = Rect.fromLTWH(0, edge.bottom, w, h - edge.bottom);
    canvas.drawRect(
      shadow,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [a.shade.withValues(alpha: .45), a.shade.withValues(alpha: 0)],
        ).createShader(shadow),
    );
  }

  @override
  bool shouldRepaint(_PlankPainter old) =>
      old.slant != slant || old.palette.isDark != palette.isDark;
}

// ---------------------------------------------------------------------------
// Drawers
// ---------------------------------------------------------------------------

/// A brass bar pull on two posts.
class ArmoirePull extends StatelessWidget {
  const ArmoirePull({super.key, this.width = DsSizes.iconXl});

  final double width;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: DsSpacing.sm,
      child: CustomPaint(painter: _PullPainter(palette: context.armoire)),
    );
  }
}

class _PullPainter extends CustomPainter {
  const _PullPainter({required this.palette});

  final ArmoirePalette palette;

  @override
  void paint(Canvas canvas, Size size) {
    final a = palette;
    final w = size.width;
    final h = size.height;
    final bar = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, h * .15, w, h * .42),
      Radius.circular(h),
    );
    // Its shadow on the lacquer.
    canvas.drawRRect(
      bar.shift(Offset(0, h * .35)),
      Paint()
        ..color = a.shade.withValues(alpha: .45)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.2),
    );
    // The two posts.
    for (final x in [w * .12, w * .88]) {
      canvas.drawCircle(Offset(x, h * .62), h * .28, Paint()..color = a.brassDeep);
    }
    canvas.drawRRect(bar, Paint()..shader = a.brassGradient.createShader(bar.outerRect));
    canvas.drawLine(
      Offset(w * .14, h * .26),
      Offset(w * .86, h * .26),
      Paint()
        ..color = DsColors.white.withValues(alpha: .6)
        ..strokeWidth = 1,
    );
  }

  @override
  bool shouldRepaint(_PullPainter old) => old.palette.isDark != palette.isDark;
}

/// A drawer front: a raised lacquer panel inside a fine bevel.
///
/// [peek], when given, is drawn as the velvet just showing above the front —
/// the drawer left a finger's width open, so she can see there is something
/// inside before she opens it. [pulled] (0..1) slides it towards her.
class ArmoireDrawerFront extends StatelessWidget {
  const ArmoireDrawerFront({
    super.key,
    required this.child,
    this.peek,
    this.peekHeight = DsSpacing.lg,
    this.pulled = 0,
  });

  final Widget child;
  final Widget? peek;
  final double peekHeight;
  final double pulled;

  @override
  Widget build(BuildContext context) {
    final a = context.armoire;
    final front = DecoratedBox(
      decoration: BoxDecoration(
        gradient: a.lacquerGradient,
        borderRadius: DsRadius.borderSm,
        border: Border.all(color: a.inlay),
        boxShadow: [
          BoxShadow(
            color: a.shade.withValues(alpha: .35 + .25 * pulled),
            blurRadius: DsSpacing.xxs + DsSpacing.sm * pulled,
            offset: Offset(0, 1.5 + DsSpacing.xs * pulled),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(DsSpacing.xxs),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: DsRadius.borderXs,
            border: Border.all(
              color: DsColors.white.withValues(alpha: a.isDark ? .07 : .7),
            ),
          ),
          child: child,
        ),
      ),
    );

    return Transform.translate(
      offset: Offset(0, DsSpacing.xxs * pulled),
      child: Transform.scale(
        scale: 1 + .025 * pulled,
        child: peek == null
            ? front
            : Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(
                    height: peekHeight + DsSpacing.xs * pulled,
                    child: ArmoireRecess(
                      radius: DsRadius.xs,
                      child: ArmoireVelvet(radius: 0, child: peek!),
                    ),
                  ),
                  front,
                ],
              ),
      ),
    );
  }
}

/// Velvet lining: a deep, slightly lustrous ground for small precious things.
class ArmoireVelvet extends StatelessWidget {
  const ArmoireVelvet({super.key, required this.child, this.radius = DsRadius.md});

  final Widget child;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final a = context.armoire;
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: const Alignment(-.3, -.6),
            radius: 1.4,
            colors: [a.velvet, a.velvetDeep],
          ),
        ),
        child: child,
      ),
    );
  }
}

/// A recessed velvet cushion — one slot of a jewellery tray.
class ArmoireCushion extends StatelessWidget {
  const ArmoireCushion({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final a = context.armoire;
    return ClipRRect(
      borderRadius: DsRadius.borderMd,
      child: CustomPaint(
        foregroundPainter: _InnerShadowPainter(
          color: Color.lerp(a.velvetDeep, DsColors.black, .45)!.withValues(alpha: .55),
          radius: DsRadius.md,
          depth: 7,
        ),
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [a.velvetDeep, a.velvet],
            ),
          ),
          child: child,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Plates, knobs, boxes
// ---------------------------------------------------------------------------

/// An engraved name plate: a short [label], an optional [caption] under it
/// and an optional [icon] before it.
class ArmoirePlaque extends StatelessWidget {
  const ArmoirePlaque({
    super.key,
    required this.label,
    this.caption,
    this.icon,
    this.large = false,
  });

  final String label;
  final String? caption;
  final IconData? icon;

  /// The crown's plate and a drawer's open header: the display serif, bigger.
  final bool large;

  @override
  Widget build(BuildContext context) {
    final a = context.armoire;
    final text = context.dsText;
    final labelStyle = (large ? text.cardTitle.displayFamily.bold : text.captionStrong)
        .tint(a.plaqueInk);
    final captionStyle = text.micro.tint(a.plaqueInk.withValues(alpha: .78));

    return DecoratedBox(
      decoration: BoxDecoration(
        color: a.plaque,
        borderRadius: DsRadius.borderPill,
        border: Border.all(color: a.brass.withValues(alpha: .85)),
        boxShadow: [
          BoxShadow(
            color: a.shade.withValues(alpha: .25),
            blurRadius: 3,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: large ? DsSpacing.lg : DsSpacing.sm,
          vertical: large ? DsSpacing.xs : DsSpacing.xxs,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: large ? DsSizes.iconSm : DsSizes.iconXxs, color: a.brassDeep),
              const SizedBox(width: DsSpacing.xxs),
            ],
            Flexible(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: labelStyle,
                  ),
                  if (caption != null)
                    Text(
                      caption!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: captionStyle,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The small brass "+" on a compartment: add a piece straight to it.
class ArmoireAddKnob extends StatelessWidget {
  const ArmoireAddKnob({
    super.key,
    required this.tooltip,
    required this.onPressed,
    this.size = DsSizes.iconMd,
  });

  final String tooltip;
  final VoidCallback onPressed;
  final double size;

  @override
  Widget build(BuildContext context) {
    final a = context.armoire;
    // The knob is small to look at and full size to press: the visible brass
    // sits centred in a target that meets the minimum touch size.
    return Tooltip(
      message: tooltip,
      child: Semantics(
        button: true,
        label: tooltip,
        excludeSemantics: true,
        child: InkResponse(
          onTap: onPressed,
          radius: DsSizes.minTouchTarget / 2,
          child: SizedBox(
            width: math.max(size, DsSizes.controlSm),
            height: math.max(size, DsSizes.controlSm),
            child: Center(
              child: Container(
                width: size,
                height: size,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  // A porcelain knob in a brass collar.
                  gradient: RadialGradient(
                    center: const Alignment(-.35, -.45),
                    colors: [
                      Color.lerp(a.plaque, DsColors.white, a.isDark ? .08 : .7)!,
                      a.plaque,
                      Color.lerp(a.plaque, a.brass, .25)!,
                    ],
                    stops: const [0, .6, 1],
                  ),
                  border: Border.all(color: a.brass, width: 1.6),
                  boxShadow: [
                    BoxShadow(
                      color: a.shade.withValues(alpha: .5),
                      blurRadius: 3,
                      offset: const Offset(0, 1.5),
                    ),
                  ],
                ),
                child: Icon(
                  Icons.add_rounded,
                  size: size * .7,
                  color: a.isDark ? a.brassLight : a.brassDeep,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A lidded storage box with a ribbon round it, sitting on top of the
/// wardrobe. [rose] picks the rose box over the linen one.
class ArmoireBox extends StatelessWidget {
  const ArmoireBox({
    super.key,
    required this.child,
    this.rose = false,
    this.pressed = 0,
  });

  final Widget child;
  final bool rose;

  /// 0..1 — the lid lifting as she opens it.
  final double pressed;

  @override
  Widget build(BuildContext context) {
    final a = context.armoire;
    final body = rose ? a.boxRose : a.boxLinen;
    final ribbon = rose ? a.brass : DsColors.rosewood;
    return CustomPaint(
      painter: _BoxPainter(
        body: body,
        ribbon: ribbon,
        shade: a.shade,
        lift: pressed,
        dark: a.isDark,
        rtl: Directionality.of(context) == TextDirection.rtl,
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          DsSpacing.sm,
          DsSpacing.md + DsSpacing.xxs,
          DsSpacing.sm,
          DsSpacing.xs,
        ),
        child: child,
      ),
    );
  }
}

class _BoxPainter extends CustomPainter {
  const _BoxPainter({
    required this.body,
    required this.ribbon,
    required this.shade,
    required this.lift,
    required this.dark,
    required this.rtl,
  });

  final bool rtl;
  final Color body;
  final Color ribbon;
  final Color shade;
  final double lift;
  final bool dark;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    const lidH = DsSpacing.sm;
    final lidLift = DsSpacing.xxs * lift;
    final boxRect = Rect.fromLTWH(DsSpacing.xxs, lidH * .6, w - DsSpacing.xs, h - lidH * .6);
    // Its shadow on the cornice.
    canvas.drawOval(
      Rect.fromLTWH(w * .04, h - DsSpacing.xxs, w * .92, DsSpacing.xs),
      Paint()
        ..color = shade.withValues(alpha: .45)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
    );
    final bodyRRect = RRect.fromRectAndCorners(
      boxRect,
      bottomLeft: const Radius.circular(DsRadius.xs),
      bottomRight: const Radius.circular(DsRadius.xs),
    );
    canvas.drawRRect(
      bodyRRect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color.lerp(body, DsColors.white, dark ? .08 : .45)!,
            body,
            Color.lerp(body, DsColors.black, dark ? .3 : .08)!,
          ],
        ).createShader(boxRect),
    );
    // The ribbon round the box, off-centre like one tied by hand — towards
    // the end, clear of the words.
    final rx = rtl ? w * .16 : w * .84;
    canvas.drawRect(
      Rect.fromLTWH(rx - 3, boxRect.top, 6, boxRect.height),
      Paint()..color = ribbon.withValues(alpha: .9),
    );
    // The lid, a little wider than the box.
    final lid = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, -lidLift, w, lidH),
      const Radius.circular(DsRadius.xs),
    );
    canvas.drawRRect(
      lid.shift(const Offset(0, 1.5)),
      Paint()
        ..color = shade.withValues(alpha: .35)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
    );
    canvas.drawRRect(
      lid,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color.lerp(body, DsColors.white, dark ? .12 : .55)!,
            Color.lerp(body, DsColors.white, dark ? .02 : .2)!,
          ],
        ).createShader(lid.outerRect),
    );
    canvas.drawRect(
      Rect.fromLTWH(rx - 3, -lidLift, 6, lidH),
      Paint()..color = ribbon,
    );
    // The bow.
    final bow = Offset(rx, -lidLift + lidH * .2);
    final loop = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4
      ..color = ribbon;
    canvas.drawOval(Rect.fromCenter(center: bow.translate(-5, -2), width: 9, height: 6), loop);
    canvas.drawOval(Rect.fromCenter(center: bow.translate(5, -2), width: 9, height: 6), loop);
    canvas.drawCircle(bow, 2.4, Paint()..color = ribbon);
  }

  @override
  bool shouldRepaint(_BoxPainter old) =>
      old.body != body ||
      old.ribbon != ribbon ||
      old.lift != lift ||
      old.dark != dark ||
      old.rtl != rtl;
}
