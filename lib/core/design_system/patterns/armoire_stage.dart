import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:ohara/core/design_system/foundation/theme/extensions/typography_extension.dart';
import 'package:ohara/core/design_system/foundation/tokens/ds_colors.dart';
import 'package:ohara/core/design_system/foundation/tokens/ds_radius.dart';
import 'package:ohara/core/design_system/foundation/tokens/ds_sizes.dart';
import 'package:ohara/core/design_system/foundation/tokens/ds_spacing.dart';

/// Her closet, drawn as a modern fitted wardrobe.
///
/// Not an antique armoire and not a grid of cards: the built-in wardrobe of a
/// new flat — flush matte panels, wood inside, an LED strip lighting every
/// compartment, slim metal pulls, a glass-fronted jewellery drawer. The parts:
///
/// * [ArmoireCarcass] / [ArmoirePlinth] — the body and the recessed kick.
/// * [ArmoireCell] — an open compartment, drawn in depth: ceiling, side
///   walls, floor and back wall, lit from the front by its LED strip.
/// * [ArmoireRod], [ArmoireHanger], [ArmoirePeg], [ArmoireShelf] — what
///   clothes hang from and stand on.
/// * [ArmoireDrawer] — a flush drawer, solid or glass-fronted.
/// * [ArmoireDoor] — a top-cabinet door that swings open on its hinge.
/// * [ArmoireHandle] — the slim metal bar every front carries.
/// * [ArmoireVelvet] / [ArmoireCushion] — a drawer's lining.
/// * [ArmoireLabel] — the name on a board, set like engraving.
/// * [ArmoireAddKnob] — the small "+" each compartment carries.
/// * [ArmoireFinishSwatch] — one finish she can choose for it.
///
/// Three finishes — light oak, matte white, walnut — chosen by her and passed
/// down through [ArmoireFinishScope]. In dark mode the room's lights go down
/// and the LEDs stay on.
enum ArmoireFinish { oak, white, walnut }

/// The finish the wardrobe below is built in.
class ArmoireFinishScope extends InheritedWidget {
  const ArmoireFinishScope({super.key, required this.finish, required super.child});

  final ArmoireFinish finish;

  static ArmoireFinish of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<ArmoireFinishScope>()?.finish ??
      ArmoireFinish.oak;

  @override
  bool updateShouldNotify(ArmoireFinishScope old) => old.finish != finish;
}

class ArmoirePalette {
  const ArmoirePalette({
    required this.finish,
    required this.isDark,
    required this.panelLight,
    required this.panel,
    required this.panelDeep,
    required this.panelGrain,
    required this.panelInk,
    required this.panelMuted,
    required this.gap,
    required this.woodLight,
    required this.wood,
    required this.woodDeep,
    required this.grain,
    required this.led,
    required this.metalLight,
    required this.metal,
    required this.metalDeep,
    required this.glass,
    required this.velvet,
    required this.velvetDeep,
    required this.hanger,
    required this.shade,
    required this.wall,
    required this.wallDeep,
  });

  /// The back wall behind a whole page — an open compartment seen from
  /// inside. Kept light by day whatever the finish, so the app's own text
  /// reads on it.
  final Color wall;
  final Color wallDeep;

  final ArmoireFinish finish;
  final bool isDark;

  /// The outside: doors, drawer fronts, the frame between compartments.
  final Color panelLight;
  final Color panel;
  final Color panelDeep;

  /// Grain on the outside; null for a matte lacquer finish.
  final Color? panelGrain;

  /// Words written on the outside.
  final Color panelInk;
  final Color panelMuted;

  /// The shadow gap between two fronts.
  final Color gap;

  /// The inside: back walls, shelves, floors.
  final Color woodLight;
  final Color wood;
  final Color woodDeep;
  final Color grain;

  /// The warm white of the LED strips.
  final Color led;

  /// Rods, pulls, frames.
  final Color metalLight;
  final Color metal;
  final Color metalDeep;

  /// Smoked glass.
  final Color glass;

  final Color velvet;
  final Color velvetDeep;

  /// The wood of the hangers.
  final Color hanger;

  final Color shade;

  LinearGradient get panelGradient => LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [panelLight, panel, panelDeep],
    stops: const [0, .5, 1],
  );

  LinearGradient get metalGradient => LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [metalLight, metal, metalDeep],
    stops: const [0, .5, 1],
  );

  static ArmoirePalette of(BuildContext context) {
    final finish = ArmoireFinishScope.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return resolve(finish, isDark: isDark);
  }

  static ArmoirePalette resolve(ArmoireFinish finish, {required bool isDark}) {
    // Outside and inside per finish, in daylight.
    final (pl, p, pd, pg, ink) = switch (finish) {
      ArmoireFinish.oak => (
        DsColors.oakLight,
        DsColors.oak,
        DsColors.oakDeep,
        DsColors.oakGrain as Color?,
        DsColors.oakInk,
      ),
      ArmoireFinish.white => (
        DsColors.mattePanelLight,
        DsColors.mattePanel,
        DsColors.mattePanelDeep,
        null,
        DsColors.mattePanelInk,
      ),
      ArmoireFinish.walnut => (
        DsColors.walnutLight,
        DsColors.walnut,
        DsColors.walnutDeep,
        DsColors.walnutGrain as Color?,
        DsColors.walnutInk,
      ),
    };
    // White wardrobes are oak inside; oak and walnut are themselves inside,
    // a shade lighter, the way the carcass board of a real one is.
    final (wl, w, wd, g) = switch (finish) {
      ArmoireFinish.walnut => (
        Color.lerp(DsColors.walnutLight, DsColors.oakDeep, .25)!,
        DsColors.walnutLight,
        DsColors.walnut,
        DsColors.walnutGrain,
      ),
      _ => (
        Color.lerp(DsColors.oakLight, DsColors.white, .35)!,
        DsColors.oakLight,
        DsColors.oak,
        DsColors.oakGrain,
      ),
    };

    // At night the room is dark but the wood stays warm: everything sinks
    // towards a deep brown-black rather than towards grey.
    final dusk = Color.lerp(DsColors.nightRoom, DsColors.walnutGrain, .45)!;
    Color night(Color c, double amount) => isDark ? Color.lerp(c, dusk, amount)! : c;

    return ArmoirePalette(
      finish: finish,
      isDark: isDark,
      panelLight: night(pl, .55),
      panel: night(p, .6),
      panelDeep: night(pd, .66),
      panelGrain: pg == null ? null : night(pg, .5),
      panelInk: isDark || finish == ArmoireFinish.walnut ? DsColors.walnutInk : ink,
      panelMuted: (isDark || finish == ArmoireFinish.walnut ? DsColors.walnutInk : ink)
          .withValues(alpha: .66),
      gap: night(Color.lerp(pd, DsColors.black, .45)!, .4),
      woodLight: night(wl, .42),
      wood: night(w, .48),
      woodDeep: night(wd, .55),
      grain: night(g, .35),
      led: DsColors.ledWarm,
      metalLight: isDark ? DsColors.gold200 : DsColors.gold100,
      metal: DsColors.champagneGold,
      metalDeep: isDark ? DsColors.gold700 : DsColors.gold600,
      glass: isDark
          ? DsColors.nightRoom.withValues(alpha: .38)
          : DsColors.neutral900.withValues(alpha: .14),
      velvet: isDark
          ? Color.lerp(DsColors.secondary800, DsColors.primary900, .45)!
          : Color.lerp(DsColors.primary100, DsColors.primary200, .5)!,
      velvetDeep: isDark
          ? Color.lerp(DsColors.secondary900, DsColors.nightRoom, .3)!
          : Color.lerp(DsColors.primary200, DsColors.rosewood, .3)!,
      hanger: night(Color.lerp(DsColors.oakDeep, DsColors.oakGrain, .2)!, .35),
      shade: DsColors.black.withValues(alpha: isDark ? .6 : .32),
      wall: isDark ? night(w, .62) : Color.lerp(w, DsColors.oakLight, finish == ArmoireFinish.walnut ? .62 : .2)!,
      wallDeep: isDark ? night(wd, .68) : Color.lerp(wd, DsColors.oak, finish == ArmoireFinish.walnut ? .55 : .1)!,
    );
  }
}

extension ArmoireContext on BuildContext {
  ArmoirePalette get armoire => ArmoirePalette.of(this);
}

// ---------------------------------------------------------------------------
// Wood
// ---------------------------------------------------------------------------

/// Draws wood grain into [rect]: fine, slightly wandering lines whose
/// spacing and strength vary like a real board's. Deterministic per [seed],
/// so a shelf does not shimmer between frames.
void paintArmoireGrain(
  Canvas canvas,
  Rect rect,
  Color color, {
  bool vertical = true,
  int seed = 7,
  double strength = 1,
}) {
  if (rect.isEmpty) return;
  final random = math.Random(seed);
  final across = vertical ? rect.width : rect.height;
  final along = vertical ? rect.height : rect.width;
  final paint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = .7;
  canvas.save();
  canvas.clipRect(rect);
  var t = random.nextDouble() * 3;
  while (t < across) {
    paint.color = color.withValues(
      alpha: ((.035 + random.nextDouble() * .075) * strength).clamp(0, 1),
    );
    final amplitude = .5 + random.nextDouble() * 1.8;
    final frequency = .015 + random.nextDouble() * .035;
    final phase = random.nextDouble() * math.pi * 2;
    final path = Path();
    for (var s = 0.0; s <= along + 6; s += 6) {
      final o = t + math.sin(s * frequency + phase) * amplitude;
      final point = vertical
          ? Offset(rect.left + o, rect.top + s)
          : Offset(rect.left + s, rect.top + o);
      s == 0 ? path.moveTo(point.dx, point.dy) : path.lineTo(point.dx, point.dy);
    }
    canvas.drawPath(path, paint);
    t += 1.8 + random.nextDouble() * 4;
  }
  canvas.restore();
}

// ---------------------------------------------------------------------------
// The body
// ---------------------------------------------------------------------------

/// The wardrobe's body: flush panels in the chosen finish. Its padding is
/// the thickness of the side panels; whatever is laid inside it shows the
/// finish between, as the boards between compartments.
class ArmoireCarcass extends StatelessWidget {
  const ArmoireCarcass({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(DsSpacing.xs),
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final a = context.armoire;
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: DsRadius.borderXs,
        boxShadow: [
          BoxShadow(
            color: a.shade.withValues(alpha: a.isDark ? .7 : .45),
            blurRadius: DsSpacing.xxl,
            offset: const Offset(0, DsSpacing.md),
          ),
        ],
      ),
      child: CustomPaint(
        painter: _PanelPainter(palette: a, seed: 3),
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}

/// A flat front in the finish: its gradient, its grain if it has one, a
/// catch of light along the top edge and the shadow gap round it.
class _PanelPainter extends CustomPainter {
  const _PanelPainter({required this.palette, this.seed = 1, this.radius = DsRadius.xs});

  final ArmoirePalette palette;
  final int seed;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final a = palette;
    final rect = Offset.zero & size;
    final rrect = RRect.fromRectAndRadius(rect, Radius.circular(radius));
    canvas.drawRRect(rrect, Paint()..shader = a.panelGradient.createShader(rect));
    if (a.panelGrain case final grain?) {
      canvas.save();
      canvas.clipRRect(rrect);
      paintArmoireGrain(canvas, rect, grain, seed: seed, strength: .9);
      canvas.restore();
    }
    canvas.drawLine(
      Offset(radius, .6),
      Offset(size.width - radius, .6),
      Paint()
        ..color = DsColors.white.withValues(alpha: a.isDark ? .08 : .55)
        ..strokeWidth = 1,
    );
    canvas.drawRRect(
      rrect.deflate(.5),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = a.gap.withValues(alpha: .55),
    );
  }

  @override
  bool shouldRepaint(_PanelPainter old) =>
      old.palette.finish != palette.finish ||
      old.palette.isDark != palette.isDark ||
      old.seed != seed;
}

/// A flat front in the finish — a door, a drawer front, a header — with
/// [child] on it.
class ArmoirePanel extends StatelessWidget {
  const ArmoirePanel({super.key, required this.child, this.radius = DsRadius.xs, this.seed = 5});

  final Widget child;
  final double radius;
  final int seed;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _PanelPainter(palette: context.armoire, seed: seed, radius: radius),
      child: child,
    );
  }
}

/// The back wall of a compartment as the ground of a whole page: wood with
/// its grain, lit from the top by the strip she has just switched on.
class ArmoireWall extends StatelessWidget {
  const ArmoireWall({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _WallPainter(palette: context.armoire),
      child: child,
    );
  }
}

class _WallPainter extends CustomPainter {
  const _WallPainter({required this.palette});

  final ArmoirePalette palette;

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
          colors: [Color.lerp(a.wall, a.led, a.isDark ? .12 : .3)!, a.wall, a.wallDeep],
          stops: const [0, .35, 1],
        ).createShader(rect),
    );
    paintArmoireGrain(canvas, rect, a.grain, seed: 41, strength: a.isDark ? 1.2 : .8);
    final pool = Rect.fromCenter(
      center: Offset(size.width / 2, 0),
      width: size.width * 1.6,
      height: math.min(size.height, size.width * 1.8),
    );
    canvas.drawOval(
      pool,
      Paint()
        ..shader = RadialGradient(
          colors: [a.led.withValues(alpha: a.isDark ? .22 : .35), a.led.withValues(alpha: 0)],
        ).createShader(pool),
    );
  }

  @override
  bool shouldRepaint(_WallPainter old) =>
      old.palette.finish != palette.finish || old.palette.isDark != palette.isDark;
}

/// The recessed kick under the wardrobe and its shadow on the floor.
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
    canvas.drawRect(
      Rect.fromLTWH(DsSpacing.sm, 0, w - DsSpacing.sm * 2, h * .5),
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [a.gap, Color.lerp(a.panelDeep, a.gap, .5)!],
        ).createShader(Rect.fromLTWH(0, 0, w, h * .5)),
    );
    canvas.drawOval(
      Rect.fromLTWH(-w * .02, h * .3, w * 1.04, h * .7),
      Paint()
        ..color = a.shade.withValues(alpha: a.isDark ? .55 : .3)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7),
    );
  }

  @override
  bool shouldRepaint(_PlinthPainter old) =>
      old.palette.finish != palette.finish || old.palette.isDark != palette.isDark;
}

// ---------------------------------------------------------------------------
// An open compartment
// ---------------------------------------------------------------------------

/// An open compartment, drawn in depth.
///
/// The ceiling, the two side walls and the floor recede to the back wall,
/// each shaded for where the light falls; an LED strip runs along the front
/// of the ceiling and pools light down the back wall. Lay [child] out
/// against the back wall — [side], [ceiling] and [floor] are how much of the
/// box each face takes — and stand things on the floor line.
///
/// [lit] (0..1) brightens the strip, the way it brightens when she opens it.
class ArmoireCell extends StatelessWidget {
  const ArmoireCell({super.key, this.child, this.lit = 0, this.seed = 11});

  final Widget? child;
  final double lit;
  final int seed;

  static const double side = DsSpacing.xs;
  static const double ceiling = DsSpacing.xs;
  static const double floor = DsSpacing.sm;

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: CustomPaint(
        painter: _CellPainter(palette: context.armoire, lit: lit, seed: seed),
        child: child,
      ),
    );
  }
}

class _CellPainter extends CustomPainter {
  const _CellPainter({required this.palette, required this.lit, required this.seed});

  final ArmoirePalette palette;
  final double lit;
  final int seed;

  @override
  void paint(Canvas canvas, Size size) {
    final a = palette;
    final w = size.width;
    final h = size.height;
    const sx = ArmoireCell.side;
    const st = ArmoireCell.ceiling;
    const sb = ArmoireCell.floor;
    final back = Rect.fromLTRB(sx, st, w - sx, h - sb);
    final glow = (a.isDark ? .55 : .42) + .4 * lit;

    // The back wall, lit from the top, its grain running up it.
    canvas.drawRect(
      back,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color.lerp(a.woodLight, a.led, .25 * glow)!, a.wood, a.woodDeep],
          stops: const [0, .55, 1],
        ).createShader(back),
    );
    paintArmoireGrain(canvas, back, a.grain, seed: seed);
    // The pool of light the strip throws.
    final pool = Rect.fromCenter(
      center: Offset(w / 2, st),
      width: w * 1.15,
      height: (h - st - sb) * 1.5,
    );
    canvas.save();
    canvas.clipRect(back);
    canvas.drawOval(
      pool,
      Paint()
        ..shader = RadialGradient(
          colors: [a.led.withValues(alpha: .55 * glow), a.led.withValues(alpha: 0)],
        ).createShader(pool),
    );
    canvas.restore();

    Path quad(Offset p1, Offset p2, Offset p3, Offset p4) => Path()
      ..moveTo(p1.dx, p1.dy)
      ..lineTo(p2.dx, p2.dy)
      ..lineTo(p3.dx, p3.dy)
      ..lineTo(p4.dx, p4.dy)
      ..close();

    // The floor: the best-lit face, nearest the strip's light.
    final floorPath = quad(Offset(0, h), Offset(sx, h - sb), Offset(w - sx, h - sb), Offset(w, h));
    canvas.drawPath(
      floorPath,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color.lerp(a.woodDeep, a.shade, .25)!,
            Color.lerp(a.woodLight, a.led, .2 * glow)!,
          ],
        ).createShader(Rect.fromLTWH(0, h - sb, w, sb)),
    );
    // The side walls, darker towards the back.
    canvas.drawPath(
      quad(const Offset(0, 0), const Offset(sx, st), Offset(sx, h - sb), Offset(0, h)),
      Paint()
        ..shader = LinearGradient(
          colors: [Color.lerp(a.wood, a.led, .12 * glow)!, Color.lerp(a.woodDeep, a.shade, .3)!],
        ).createShader(Rect.fromLTWH(0, 0, sx, h)),
    );
    canvas.drawPath(
      quad(Offset(w, 0), Offset(w - sx, st), Offset(w - sx, h - sb), Offset(w, h)),
      Paint()
        ..shader = LinearGradient(
          colors: [Color.lerp(a.woodDeep, a.shade, .38)!, Color.lerp(a.wood, a.shade, .12)!],
        ).createShader(Rect.fromLTWH(w - sx, 0, sx, h)),
    );
    // The ceiling's underside: in its own shadow, but for the strip.
    canvas.drawPath(
      quad(const Offset(0, 0), Offset(w, 0), Offset(w - sx, st), const Offset(sx, st)),
      Paint()..color = Color.lerp(a.woodDeep, a.shade, .45)!,
    );
    // The strip, and its glow.
    final strip = Rect.fromLTWH(sx * .6, 1, w - sx * 1.2, 2.2);
    canvas.drawRect(
      strip.inflate(2.5),
      Paint()
        ..color = a.led.withValues(alpha: .7 * glow)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(strip, const Radius.circular(1)),
      Paint()..color = Color.lerp(a.led, DsColors.white, .5)!,
    );
    // Shadow gathering in the back corners.
    canvas.drawRect(
      back,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = a.shade.withValues(alpha: .35)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.5),
    );
  }

  @override
  bool shouldRepaint(_CellPainter old) =>
      old.lit != lit ||
      old.seed != seed ||
      old.palette.finish != palette.finish ||
      old.palette.isDark != palette.isDark;
}

/// A metal hanging rod: an oval tube on two end sockets, across the width.
class ArmoireRod extends StatelessWidget {
  const ArmoireRod({super.key, this.height = DsSpacing.sm});

  final double height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: height,
      child: CustomPaint(painter: _RodPainter(palette: context.armoire)),
    );
  }
}

class _RodPainter extends CustomPainter {
  const _RodPainter({required this.palette});

  final ArmoirePalette palette;

  @override
  void paint(Canvas canvas, Size size) {
    final a = palette;
    final cy = size.height * .5;
    final t = math.max(3.5, size.height * .42);
    final rod = RRect.fromRectAndRadius(
      Rect.fromLTRB(0, cy - t / 2, size.width, cy + t / 2),
      Radius.circular(t),
    );
    canvas.drawRRect(
      rod.shift(Offset(0, t)),
      Paint()
        ..color = a.shade.withValues(alpha: .4)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.5),
    );
    canvas.drawRRect(rod, Paint()..shader = a.metalGradient.createShader(rod.outerRect));
    canvas.drawLine(
      Offset(t, cy - t * .2),
      Offset(size.width - t, cy - t * .2),
      Paint()
        ..color = DsColors.white.withValues(alpha: .7)
        ..strokeWidth = 1,
    );
    for (final x in [0.0, size.width]) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset(x, cy), width: t * 1.4, height: size.height),
          Radius.circular(t * .4),
        ),
        Paint()..shader = a.metalGradient.createShader(Rect.fromLTWH(x - t, 0, t * 2, size.height)),
      );
    }
  }

  @override
  bool shouldRepaint(_RodPainter old) => old.palette.isDark != palette.isDark;
}

/// A wooden hanger seen from the front: the metal hook over the rod and the
/// shaped wooden shoulders below it.
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
    final hookH = h * .5;
    // The hook, curling over the rod.
    final hook = Path()
      ..moveTo(cx, hookH)
      ..lineTo(cx, h * .28)
      ..arcToPoint(Offset(cx - h * .2, h * .1), radius: Radius.circular(h * .15), clockwise: false);
    canvas.drawPath(
      hook,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = math.max(1.2, h * .08)
        ..color = Color.lerp(a.metalDeep, DsColors.neutral500, .5)!,
    );
    // The wooden body: a shaped bar, thicker at the middle.
    final thick = math.max(2.6, h * .2);
    final body = Path()
      ..moveTo(w * .03, h * .98)
      ..quadraticBezierTo(cx - w * .22, h * .6, cx, hookH - thick * .2)
      ..quadraticBezierTo(cx + w * .22, h * .6, w * .97, h * .98)
      ..lineTo(w * .95, h)
      ..quadraticBezierTo(cx + w * .2, h * .7, cx, hookH + thick * .8)
      ..quadraticBezierTo(cx - w * .2, h * .7, w * .05, h)
      ..close();
    canvas.drawPath(
      body.shift(const Offset(0, 1.2)),
      Paint()
        ..color = a.shade.withValues(alpha: .35)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.2),
    );
    canvas.drawPath(
      body,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color.lerp(a.hanger, DsColors.white, .25)!, a.hanger],
        ).createShader(Offset.zero & size),
    );
  }

  @override
  bool shouldRepaint(_HangerPainter old) =>
      old.palette.finish != palette.finish || old.palette.isDark != palette.isDark;
}

/// A small metal hook, screwed to the back wall.
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
          colors: [a.metalLight, a.metal, a.metalDeep],
          stops: const [0, .55, 1],
        ),
        boxShadow: [
          BoxShadow(
            color: a.shade.withValues(alpha: .6),
            blurRadius: 2.5,
            offset: const Offset(1, 2),
          ),
        ],
      ),
    );
  }
}

/// A shelf inside a compartment: the board's top face and its edge banding.
/// [slant] tilts it the way a shoe shelf sits, and puts a metal rail along
/// its front so nothing slides off.
class ArmoireShelf extends StatelessWidget {
  const ArmoireShelf({super.key, this.height = DsSpacing.sm, this.slant = false});

  final double height;
  final bool slant;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: height,
      child: CustomPaint(painter: _ShelfPainter(palette: context.armoire, slant: slant)),
    );
  }
}

class _ShelfPainter extends CustomPainter {
  const _ShelfPainter({required this.palette, required this.slant});

  final ArmoirePalette palette;
  final bool slant;

  @override
  void paint(Canvas canvas, Size size) {
    final a = palette;
    final w = size.width;
    final h = size.height;
    final face = h * (slant ? .6 : .45);
    final inset = slant ? h * .6 : h * .3;
    final top = Path()
      ..moveTo(inset, 0)
      ..lineTo(w - inset, 0)
      ..lineTo(w, face)
      ..lineTo(0, face)
      ..close();
    canvas.drawPath(
      top,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color.lerp(a.woodDeep, a.shade, .15)!, Color.lerp(a.woodLight, a.led, .15)!],
        ).createShader(Rect.fromLTWH(0, 0, w, face)),
    );
    paintArmoireGrain(canvas, Rect.fromLTWH(0, 0, w, face), a.grain, vertical: false, seed: 5);
    final edge = Rect.fromLTWH(0, face, w, h * .32);
    canvas.drawRect(
      edge,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [a.panelLight, a.panelDeep],
        ).createShader(edge),
    );
    canvas.drawLine(
      Offset(0, face),
      Offset(w, face),
      Paint()
        ..color = DsColors.white.withValues(alpha: a.isDark ? .15 : .6)
        ..strokeWidth = 1,
    );
    final below = Rect.fromLTWH(0, edge.bottom, w, h - edge.bottom);
    canvas.drawRect(
      below,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [a.shade.withValues(alpha: .5), a.shade.withValues(alpha: 0)],
        ).createShader(below),
    );
    if (slant) {
      // The rail along the front edge.
      final y = face - 2.5;
      final rail = RRect.fromRectAndRadius(
        Rect.fromLTRB(DsSpacing.xxs, y - 1.6, w - DsSpacing.xxs, y + 1.6),
        const Radius.circular(2),
      );
      canvas.drawRRect(rail, Paint()..shader = a.metalGradient.createShader(rail.outerRect));
    }
  }

  @override
  bool shouldRepaint(_ShelfPainter old) =>
      old.slant != slant ||
      old.palette.finish != palette.finish ||
      old.palette.isDark != palette.isDark;
}

// ---------------------------------------------------------------------------
// Fronts
// ---------------------------------------------------------------------------

/// A slim metal bar pull, horizontal unless [vertical].
class ArmoireHandle extends StatelessWidget {
  const ArmoireHandle({super.key, this.length = DsSizes.iconXl, this.vertical = false});

  final double length;
  final bool vertical;

  @override
  Widget build(BuildContext context) {
    final a = context.armoire;
    const thickness = DsSpacing.xxs + 1;
    return Container(
      width: vertical ? thickness : length,
      height: vertical ? length : thickness,
      decoration: BoxDecoration(
        borderRadius: DsRadius.borderPill,
        gradient: LinearGradient(
          begin: vertical ? Alignment.centerLeft : Alignment.topCenter,
          end: vertical ? Alignment.centerRight : Alignment.bottomCenter,
          colors: [a.metalLight, a.metal, a.metalDeep],
        ),
        boxShadow: [
          BoxShadow(
            color: a.shade.withValues(alpha: .55),
            blurRadius: 2.5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
    );
  }
}

/// A flush drawer front.
///
/// Solid, it is the finish with a pull along its top and [child] — the
/// label — under it. With [window], it is a glass-fronted drawer: a metal
/// frame round smoked glass, and through the glass, the drawer's velvet with
/// what is in it.
///
/// [pulled] (0..1) slides it towards her and lets its side show.
class ArmoireDrawer extends StatelessWidget {
  const ArmoireDrawer({
    super.key,
    required this.child,
    this.window,
    this.windowHeight = DsSizes.thumbSm,
    this.pulled = 0,
    this.handle = DsSizes.thumbSm,
  });

  final Widget child;
  final Widget? window;
  final double windowHeight;
  final double pulled;
  final double handle;

  @override
  Widget build(BuildContext context) {
    final a = context.armoire;
    final front = DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: DsRadius.borderXs,
        boxShadow: [
          BoxShadow(
            color: a.shade.withValues(alpha: .3 + .35 * pulled),
            blurRadius: 2 + DsSpacing.md * pulled,
            offset: Offset(0, 1 + DsSpacing.sm * pulled),
          ),
        ],
      ),
      child: CustomPaint(
        painter: _PanelPainter(palette: a, seed: 9),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(DsSpacing.xs, DsSpacing.xs, DsSpacing.xs, DsSpacing.xs),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(child: ArmoireHandle(length: handle)),
              const SizedBox(height: DsSpacing.xs),
              if (window != null) ...[
                SizedBox(height: windowHeight, child: ArmoireGlass(child: window!)),
                const SizedBox(height: DsSpacing.xs),
              ],
              child,
            ],
          ),
        ),
      ),
    );

    return Transform.translate(
      offset: Offset(0, DsSpacing.xs * pulled),
      child: Transform.scale(scale: 1 + .03 * pulled, child: front),
    );
  }
}

/// Smoked glass in a slim metal frame, with [child] behind it.
class ArmoireGlass extends StatelessWidget {
  const ArmoireGlass({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final a = context.armoire;
    return Container(
      padding: const EdgeInsets.all(DsSpacing.xxxs),
      decoration: BoxDecoration(
        gradient: a.metalGradient,
        borderRadius: DsRadius.borderXs,
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.all(Radius.circular(DsRadius.xs - 1)),
        child: Stack(
          fit: StackFit.expand,
          children: [
            child,
            DecoratedBox(decoration: BoxDecoration(color: a.glass)),
            // A slant of reflected light across the pane.
            CustomPaint(painter: _ReflectionPainter(dark: a.isDark)),
          ],
        ),
      ),
    );
  }
}

class _ReflectionPainter extends CustomPainter {
  const _ReflectionPainter({required this.dark});

  final bool dark;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final band = Path()
      ..moveTo(w * .58, 0)
      ..lineTo(w * .74, 0)
      ..lineTo(w * .5, h)
      ..lineTo(w * .34, h)
      ..close();
    canvas.drawPath(band, Paint()..color = DsColors.white.withValues(alpha: dark ? .06 : .16));
    final thin = Path()
      ..moveTo(w * .78, 0)
      ..lineTo(w * .81, 0)
      ..lineTo(w * .57, h)
      ..lineTo(w * .54, h)
      ..close();
    canvas.drawPath(thin, Paint()..color = DsColors.white.withValues(alpha: dark ? .05 : .14));
  }

  @override
  bool shouldRepaint(_ReflectionPainter old) => old.dark != dark;
}

/// A top-cabinet door, hung on [hingeAtStart] or the end side.
///
/// [open] (0..1) swings it on its hinge in perspective, showing [inside]
/// behind it. With [glass], the door is a framed pane and [inside] shows
/// through it even while it is shut.
class ArmoireDoor extends StatelessWidget {
  const ArmoireDoor({
    super.key,
    required this.child,
    required this.inside,
    this.open = 0,
    this.hingeAtStart = true,
    this.glass = false,
  });

  /// The label on the door.
  final Widget child;
  final Widget inside;
  final double open;
  final bool hingeAtStart;
  final bool glass;

  @override
  Widget build(BuildContext context) {
    final a = context.armoire;
    final rtl = Directionality.of(context) == TextDirection.rtl;
    final hingeLeft = hingeAtStart != rtl;
    final handle = Padding(
      padding: const EdgeInsets.symmetric(horizontal: DsSpacing.xs),
      child: const ArmoireHandle(length: DsSpacing.xxl, vertical: true),
    );

    final face = CustomPaint(
      painter: _PanelPainter(palette: a, seed: hingeLeft ? 13 : 17),
      child: Padding(
        padding: const EdgeInsets.all(DsSpacing.xs),
        child: Row(
          textDirection: TextDirection.ltr,
          children: [
            if (!hingeLeft) handle,
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (glass) ...[
                    Expanded(child: ArmoireGlass(child: inside)),
                    const SizedBox(height: DsSpacing.xxs),
                  ],
                  Directionality(
                    textDirection: rtl ? TextDirection.rtl : TextDirection.ltr,
                    child: child,
                  ),
                ],
              ),
            ),
            if (hingeLeft) handle,
          ],
        ),
      ),
    );

    final angle = open * 1.05 * (hingeLeft ? 1 : -1);
    return Stack(
      fit: StackFit.passthrough,
      children: [
        if (open > 0) Positioned.fill(child: inside),
        Transform(
          alignment: hingeLeft ? Alignment.centerLeft : Alignment.centerRight,
          transform: Matrix4.identity()
            ..setEntry(3, 2, .0016)
            ..rotateY(angle),
          child: DecoratedBox(
            decoration: BoxDecoration(
              boxShadow: [
                BoxShadow(
                  color: a.shade.withValues(alpha: .25 + .3 * open),
                  blurRadius: 2 + DsSpacing.md * open,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: face,
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Linings
// ---------------------------------------------------------------------------

/// Velvet lining: a deep, slightly lustrous ground for small precious things.
class ArmoireVelvet extends StatelessWidget {
  const ArmoireVelvet({super.key, required this.child, this.radius = DsRadius.xs});

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
            center: const Alignment(-.3, -.7),
            radius: 1.5,
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
      borderRadius: DsRadius.borderSm,
      child: CustomPaint(
        foregroundPainter: _InnerShadowPainter(
          color: Color.lerp(a.velvetDeep, DsColors.black, .5)!.withValues(alpha: .55),
          radius: DsRadius.sm,
          depth: 6,
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

class _InnerShadowPainter extends CustomPainter {
  const _InnerShadowPainter({required this.color, required this.radius, required this.depth});

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

// ---------------------------------------------------------------------------
// Labels and controls
// ---------------------------------------------------------------------------

/// The name of a compartment, set on the board under it like engraving:
/// the name, a hairline, and how many pieces.
class ArmoireLabel extends StatelessWidget {
  const ArmoireLabel({
    super.key,
    required this.name,
    this.caption,
    this.large = false,
    this.stacked = false,
  });

  final String name;
  final String? caption;

  /// The caption under the name rather than beside it — for a door, which
  /// is tall and narrow.
  final bool stacked;

  /// The header of an open compartment: the display serif, bigger.
  final bool large;

  @override
  Widget build(BuildContext context) {
    final a = context.armoire;
    final text = context.dsText;
    final nameStyle = (large ? text.screenTitle.displayFamily.bold : text.captionStrong).tint(
      a.panelInk,
    );
    final captionStyle = (large ? text.caption : text.micro).tint(a.panelMuted);

    if (stacked && !large) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: nameStyle),
          if (caption != null)
            Text(caption!, maxLines: 1, overflow: TextOverflow.ellipsis, style: captionStyle),
        ],
      );
    }
    if (large) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: nameStyle),
          if (caption != null) ...[
            const SizedBox(height: DsSpacing.xxs),
            Container(width: DsSpacing.xl, height: 1, color: a.metal),
            const SizedBox(height: DsSpacing.xxs),
            Text(caption!, maxLines: 1, overflow: TextOverflow.ellipsis, style: captionStyle),
          ],
        ],
      );
    }
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Flexible(
          child: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: nameStyle),
        ),
        if (caption != null) ...[
          Container(
            width: 1,
            height: DsSpacing.sm,
            margin: const EdgeInsets.symmetric(horizontal: DsSpacing.xxs + 1),
            color: a.metal.withValues(alpha: .8),
          ),
          Flexible(
            child: Text(caption!, maxLines: 1, overflow: TextOverflow.ellipsis, style: captionStyle),
          ),
        ],
      ],
    );
  }
}

/// The small "+" on a compartment: add a piece straight into it.
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
    // Small to look at and full size to press: the visible button sits
    // centred in a target that meets the minimum touch size.
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
                  color: Color.lerp(a.panelLight, DsColors.white, a.isDark ? .05 : .5),
                  border: Border.all(color: a.metal, width: 1.4),
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
                  color: a.isDark ? a.metalLight : a.metalDeep,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// One finish she can build the wardrobe in, as a sample chip.
class ArmoireFinishSwatch extends StatelessWidget {
  const ArmoireFinishSwatch({
    super.key,
    required this.finish,
    required this.selected,
    required this.tooltip,
    required this.onTap,
  });

  final ArmoireFinish finish;
  final bool selected;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final a = ArmoirePalette.resolve(finish, isDark: false);
    final ring = context.armoire.metal;
    const size = DsSizes.avatarXs;
    return Tooltip(
      message: tooltip,
      child: Semantics(
        button: true,
        selected: selected,
        label: tooltip,
        excludeSemantics: true,
        child: InkResponse(
          onTap: onTap,
          radius: DsSizes.minTouchTarget / 2,
          child: SizedBox(
            width: DsSizes.controlSm,
            height: DsSizes.controlSm,
            child: Center(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: size,
                height: size,
                padding: const EdgeInsets.all(DsSpacing.xxxs),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: selected ? ring : ring.withValues(alpha: .25),
                    width: selected ? 2 : 1,
                  ),
                ),
                child: ClipOval(
                  child: CustomPaint(painter: _PanelPainter(palette: a, seed: 21, radius: 0)),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
