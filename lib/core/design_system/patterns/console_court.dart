import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:ohara/core/design_system/design_system.dart';

/// The operator's home register: **the courtyard of a Damascus house**.
///
/// An administrator does not open the console to admire a wall of counters.
/// She opens it to learn what is waiting for her and to go there. So the home
/// is laid out like the house she would walk into:
///
/// * [CourtSky] — the night over the courtyard: a greeting, the state of the
///   house in one sentence, and the one field that takes her anywhere.
/// * [PulseRose] — the fountain at the centre: the month's four vital signs as
///   the petals of one rose, each growing with its trend, so the *shape* of
///   the month reads before any number does.
/// * [CourtDoor] — the doors around the court, cut to Ohara's arch. A door with
///   someone waiting behind it is lit; a quiet one is not. She can see where
///   the work is before reading a word.
/// * [CourtThreadBead] — the day's thread: what happened, strung as beads on
///   one silk line.
///
/// Everything resolves from [AdminConsolePalette], so the court follows dark
/// mode like the rest of the console.

// ---------------------------------------------------------------------------
// The sky
// ---------------------------------------------------------------------------

/// The night over the courtyard.
///
/// A deep plum ground with a rose bloom at the crown, a faint lattice of
/// eight-pointed stars — the geometry of a Damascene ceiling — and a tall arch
/// window of light on the far side. Copy on it is set in [DsColors.onMedia]:
/// the sky does not change with the theme, the way a photograph does not.
class CourtSky extends StatelessWidget {
  const CourtSky({
    super.key,
    required this.child,
    this.padding,
    this.window = true,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;

  /// Whether the arch window and its moon are drawn. A page header turns it
  /// off: its controls stand where the window would, and its own emblem is
  /// already an arch.
  final bool window;

  @override
  Widget build(BuildContext context) {
    final palette = context.console;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final rtl = Directionality.of(context) == TextDirection.rtl;

    return ClipRRect(
      borderRadius: DsRadius.borderXxl,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: AlignmentDirectional.topStart.resolve(
              Directionality.of(context),
            ),
            end: AlignmentDirectional.bottomEnd.resolve(
              Directionality.of(context),
            ),
            colors: [
              palette.nav,
              isDark ? DsColors.mauve900 : DsColors.mauve800,
              isDark ? DsColors.primary950 : DsColors.primary900,
            ],
            stops: const [0, 0.62, 1],
          ),
        ),
        child: CustomPaint(
          painter: _SkyPainter(rtl: rtl, window: window),
          child: Padding(padding: padding ?? DsSpacing.paddingXl, child: child),
        ),
      ),
    );
  }
}

class _SkyPainter extends CustomPainter {
  const _SkyPainter({required this.rtl, required this.window});

  final bool rtl;
  final bool window;

  static const double _latticeStep = 56;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;

    // The rose bloom at the crown, on the reading side.
    final bloomCenter = Offset(
      rtl ? size.width * 0.82 : size.width * 0.18,
      -size.height * 0.1,
    );
    canvas.drawRect(
      rect,
      Paint()
        ..shader =
            RadialGradient(
              colors: [
                DsColors.primary600.withValues(alpha: 0.34),
                DsColors.primary600.withValues(alpha: 0),
              ],
            ).createShader(
              Rect.fromCircle(center: bloomCenter, radius: size.width * 0.55),
            ),
    );

    // Champagne light low on the far side, under the window.
    final warmCenter = Offset(
      rtl ? size.width * 0.12 : size.width * 0.88,
      size.height * 1.05,
    );
    canvas.drawRect(
      rect,
      Paint()
        ..shader =
            RadialGradient(
              colors: [
                DsColors.gold300.withValues(alpha: 0.22),
                DsColors.gold300.withValues(alpha: 0),
              ],
            ).createShader(
              Rect.fromCircle(center: warmCenter, radius: size.width * 0.45),
            ),
    );

    // The ceiling lattice: an eight-pointed star at every crossing.
    final star = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = DsColors.onMedia.withValues(alpha: 0.055);
    for (double y = _latticeStep / 2; y < size.height; y += _latticeStep) {
      final row = (y / _latticeStep).floor();
      final offset = row.isEven ? 0.0 : _latticeStep / 2;
      for (
        double x = offset;
        x < size.width + _latticeStep;
        x += _latticeStep
      ) {
        _drawStar(canvas, Offset(x, y), 9, star);
      }
    }

    if (!window) return;

    // The arch window: tall, on the far side, holding a moon.
    final archHeight = size.height * 1.1;
    final archWidth = math.min(size.width * 0.22, archHeight * 0.55);
    final archLeft = rtl ? size.width * 0.06 : size.width * 0.94 - archWidth;
    final arch = dsArchPath(
      Rect.fromLTWH(archLeft, size.height * 0.12, archWidth, archHeight),
    );
    canvas.drawPath(
      arch,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            DsColors.gold200.withValues(alpha: 0.12),
            DsColors.gold200.withValues(alpha: 0.0),
          ],
        ).createShader(arch.getBounds()),
    );
    canvas.drawPath(
      arch,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            DsColors.gold300.withValues(alpha: 0.5),
            DsColors.gold300.withValues(alpha: 0.0),
          ],
        ).createShader(arch.getBounds()),
    );
    final moon = Offset(
      archLeft + archWidth / 2,
      size.height * 0.12 + archWidth * 0.62,
    );
    final moonRadius = archWidth * 0.17;
    canvas.drawCircle(
      moon,
      moonRadius * 2.6,
      Paint()
        ..shader = RadialGradient(
          colors: [
            DsColors.gold100.withValues(alpha: 0.28),
            DsColors.gold100.withValues(alpha: 0),
          ],
        ).createShader(Rect.fromCircle(center: moon, radius: moonRadius * 2.6)),
    );
    // A crescent: the moon, with a disc of sky taken out of it.
    final crescent = Path.combine(
      PathOperation.difference,
      Path()..addOval(Rect.fromCircle(center: moon, radius: moonRadius)),
      Path()..addOval(
        Rect.fromCircle(
          center: moon.translate(
            (rtl ? -1 : 1) * moonRadius * 0.45,
            -moonRadius * 0.2,
          ),
          radius: moonRadius * 0.88,
        ),
      ),
    );
    canvas.drawPath(
      crescent,
      Paint()..color = DsColors.gold100.withValues(alpha: 0.85),
    );
  }

  @override
  bool shouldRepaint(_SkyPainter oldDelegate) =>
      oldDelegate.rtl != rtl || oldDelegate.window != window;
}

/// Two squares, one turned an eighth — the star of a Damascene ceiling.
void _drawStar(Canvas canvas, Offset center, double radius, Paint paint) {
  for (final turn in const [0.0, math.pi / 4]) {
    final path = Path();
    for (var i = 0; i < 4; i++) {
      final angle = turn + i * math.pi / 2;
      final point = center + Offset(math.cos(angle), math.sin(angle)) * radius;
      if (i == 0) {
        path.moveTo(point.dx, point.dy);
      } else {
        path.lineTo(point.dx, point.dy);
      }
    }
    path.close();
    canvas.drawPath(path, paint);
  }
}

/// A key cap, as printed on a keyboard: «Ctrl K» on the jump field.
class CourtKeyCap extends StatelessWidget {
  const CourtKeyCap({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: DsSpacing.xs,
        vertical: DsSpacing.xxxs,
      ),
      decoration: BoxDecoration(
        color: DsColors.onMedia.withValues(alpha: 0.08),
        borderRadius: DsRadius.borderXs,
        border: Border.all(color: DsColors.onMediaFaint),
      ),
      child: Text(
        label,
        style: context.dsText.caption.semibold.tint(DsColors.onMediaMuted),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// The rose
// ---------------------------------------------------------------------------

/// One petal of the [PulseRose].
@immutable
class PulsePetal {
  const PulsePetal({required this.strength, required this.color});

  /// The trend this petal stands for, already scaled against its siblings:
  /// `1` is the strongest move of the month, `0` is flat, and a negative
  /// value is a fall of that relative size.
  final double strength;

  final Color color;
}

/// The month's vital signs, drawn as one rose.
///
/// Each petal is a metric; its length is that metric's trend against the
/// strongest of them, so a month where everything grew is a full, even rose
/// and a month where one thing fell has a short petal in the critical colour,
/// pointing at it. The rings and ticks behind it are an astrolabe's — they
/// give the petals something to be measured against.
///
/// The figures themselves are always printed beside it; the rose is how the
/// month *looks*, never the only place a number lives.
class PulseRose extends StatelessWidget {
  const PulseRose({
    super.key,
    required this.petals,
    this.size = 200,
    this.semanticLabel,
  });

  final List<PulsePetal> petals;
  final double size;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final palette = context.console;
    final rose = TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: DsReducedMotion.duration(DsMotion.slowest),
      curve: DsMotion.softSpring,
      builder: (context, progress, _) => CustomPaint(
        size: Size.square(size),
        painter: _RosePainter(
          petals: petals,
          progress: progress,
          ring: palette.line,
          fall: palette.critical,
          heart: palette.surface,
          heartInk: palette.primary,
        ),
      ),
    );
    return Semantics(
      image: true,
      label: semanticLabel,
      child: ExcludeSemantics(child: rose),
    );
  }
}

class _RosePainter extends CustomPainter {
  const _RosePainter({
    required this.petals,
    required this.progress,
    required this.ring,
    required this.fall,
    required this.heart,
    required this.heartInk,
  });

  final List<PulsePetal> petals;
  final double progress;
  final Color ring;
  final Color fall;
  final Color heart;
  final Color heartInk;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final outer = size.shortestSide / 2;
    final reach = outer * 0.9;
    final rest = reach * 0.3;

    // The astrolabe: three rings and a ring of ticks.
    final ringPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = ring;
    for (final fraction in const [0.36, 0.63, 0.9]) {
      canvas.drawCircle(center, outer * fraction, ringPaint);
    }
    final tick = Paint()
      ..strokeWidth = 1
      ..color = ring;
    for (var i = 0; i < 48; i++) {
      final angle = i * math.pi * 2 / 48;
      final long = i % 4 == 0;
      final from = outer * (long ? 0.93 : 0.955);
      final direction = Offset(math.cos(angle), math.sin(angle));
      canvas.drawLine(
        center + direction * from,
        center + direction * outer,
        tick,
      );
    }

    if (petals.isEmpty) return;

    // The petals, from the crown, clockwise.
    for (var i = 0; i < petals.length; i++) {
      final petal = petals[i];
      final falling = petal.strength < 0;
      final strength = petal.strength.abs().clamp(0.0, 1.0);
      final length = (rest + (reach - rest) * strength) * progress;
      if (length <= 0) continue;
      final color = falling ? fall : petal.color;
      final angle = -math.pi / 2 + i * math.pi * 2 / petals.length;

      canvas.save();
      canvas.translate(center.dx, center.dy);
      canvas.rotate(angle);
      final width = math.max(length * 0.34, outer * 0.1);
      final path = Path()
        ..moveTo(0, 0)
        ..quadraticBezierTo(length * 0.42, -width, length, 0)
        ..quadraticBezierTo(length * 0.42, width, 0, 0)
        ..close();
      final bounds = Rect.fromLTWH(0, -width, length, width * 2);
      canvas.drawPath(
        path,
        Paint()
          ..shader = LinearGradient(
            colors: [
              color.withValues(alpha: 0.12),
              color.withValues(alpha: falling ? 0.45 : 0.78),
            ],
          ).createShader(bounds),
      );
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.4
          ..color = color.withValues(alpha: 0.9),
      );
      // A dew-drop at the tip, where the eye lands.
      canvas.drawCircle(Offset(length, 0), 3, Paint()..color = color);
      canvas.restore();
    }

    // The heart: a small disc holding the Damascene star.
    canvas.drawCircle(center, outer * 0.14, Paint()..color = heart);
    canvas.drawCircle(
      center,
      outer * 0.14,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = ring,
    );
    _drawStar(
      canvas,
      center,
      outer * 0.075,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4
        ..color = heartInk,
    );
  }

  @override
  bool shouldRepaint(_RosePainter old) =>
      old.progress != progress ||
      old.petals != petals ||
      old.ring != ring ||
      old.fall != fall ||
      old.heart != heart ||
      old.heartInk != heartInk;
}

// ---------------------------------------------------------------------------
// The doors
// ---------------------------------------------------------------------------

/// A door off the courtyard, cut to Ohara's arch.
///
/// [lit] is the whole point: a door with someone waiting behind it glows from
/// inside, in champagne light on plum, and the count is set large in the
/// display serif. A door with nobody waiting is quiet — still there, still
/// open, but not asking for her.
///
/// The door grows with its content rather than holding a fixed height, so a
/// long label or a large text scale lengthens the door instead of spilling out
/// of it.
class CourtDoor extends StatelessWidget {
  const CourtDoor({
    super.key,
    required this.icon,
    required this.label,
    required this.status,
    required this.onTap,
    this.count,
    this.lit = false,
  });

  final IconData icon;
  final String label;

  /// The line under the label: «٩ بانتظاركِ», «لا أحد ينتظر», or what the
  /// room is for when it keeps no queue.
  final String status;

  /// The figure set large on a lit door. Null on a door that keeps no queue.
  final String? count;
  final bool lit;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.console;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final ink = lit ? DsColors.onMedia : palette.ink;
    final muted = lit ? DsColors.onMediaMuted : palette.muted;

    return DsScaleAnimations.tapScale(
      onTap: onTap,
      semanticLabel: '$label، $status',
      excludeChildSemantics: true,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth.isFinite
              ? constraints.maxWidth
              : DsSizes.railCardWidth;
          return ConstrainedBox(
            constraints: BoxConstraints(minHeight: width * 1.22),
            child: CustomPaint(
              painter: _DoorPainter(
                lit: lit,
                surface: palette.surface,
                line: palette.line,
                nightTop: isDark ? DsColors.mauve800 : DsColors.mauve700,
                nightBottom: palette.nav,
                shadow: palette.shadow.isEmpty
                    ? DsColors.transparent
                    : palette.shadow.first.color,
              ),
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  DsSpacing.sm,
                  width * 0.28,
                  DsSpacing.xs,
                  DsSpacing.md,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: DsSizes.controlMd,
                      height: DsSizes.controlMd,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: lit
                            ? DsColors.gold200.withValues(alpha: 0.16)
                            : palette.primarySoft,
                        border: lit
                            ? Border.all(
                                color: DsColors.gold200.withValues(alpha: 0.4),
                              )
                            : null,
                      ),
                      child: Icon(
                        icon,
                        size: DsSizes.iconSm,
                        color: lit ? DsColors.gold100 : palette.primary,
                      ),
                    ),
                    DsGaps.vSm,
                    Text(
                      label,
                      maxLines: 2,
                      textAlign: TextAlign.center,
                      overflow: TextOverflow.ellipsis,
                      style: context.dsText.labelLarge.semibold.tint(ink),
                    ),
                    DsGaps.vXs,
                    if (count != null && lit)
                      Text(
                        count!,
                        style: context.dsText.metric.displayFamily
                            .tint(DsColors.gold200)
                            .copyWith(height: 1.1),
                      ),
                    Text(
                      status,
                      maxLines: 2,
                      textAlign: TextAlign.center,
                      overflow: TextOverflow.ellipsis,
                      style: context.dsText.caption.tint(muted),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _DoorPainter extends CustomPainter {
  const _DoorPainter({
    required this.lit,
    required this.surface,
    required this.line,
    required this.nightTop,
    required this.nightBottom,
    required this.shadow,
  });

  final bool lit;
  final Color surface;
  final Color line;
  final Color nightTop;
  final Color nightBottom;
  final Color shadow;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final arch = dsArchPath(rect);

    // A soft footprint, so the door stands on the page.
    canvas.drawPath(
      arch.shift(const Offset(0, 6)),
      Paint()
        ..color = shadow
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
    );

    if (lit) {
      canvas.drawPath(
        arch,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [nightTop, nightBottom],
          ).createShader(rect),
      );
      // The lamp inside: warm light behind the threshold.
      canvas.save();
      canvas.clipPath(arch);
      final lamp = Offset(size.width / 2, size.width * 0.42);
      canvas.drawCircle(
        lamp,
        size.width * 0.9,
        Paint()
          ..shader =
              RadialGradient(
                colors: [
                  DsColors.gold300.withValues(alpha: 0.42),
                  DsColors.gold300.withValues(alpha: 0.08),
                  DsColors.gold300.withValues(alpha: 0),
                ],
                stops: const [0, 0.5, 1],
              ).createShader(
                Rect.fromCircle(center: lamp, radius: size.width * 0.9),
              ),
      );
      canvas.restore();
      canvas.drawPath(
        arch,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.4
          ..color = DsColors.gold300.withValues(alpha: 0.7),
      );
    } else {
      canvas.drawPath(arch, Paint()..color = surface);
      canvas.drawPath(
        arch,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = line,
      );
    }

    // The inner frame: a second arch, set in, like a carved reveal.
    final reveal = dsArchPath(rect.deflate(size.width * 0.07));
    canvas.drawPath(
      reveal,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = lit
            ? DsColors.gold200.withValues(alpha: 0.22)
            : line.withValues(alpha: 0.6),
    );
  }

  @override
  bool shouldRepaint(_DoorPainter old) =>
      old.lit != lit ||
      old.surface != surface ||
      old.line != line ||
      old.nightTop != nightTop ||
      old.nightBottom != nightBottom ||
      old.shadow != shadow;
}

// ---------------------------------------------------------------------------
// The thread
// ---------------------------------------------------------------------------

/// One bead on the day's thread, and the stretch of silk through it.
///
/// Painted down the full height of its row, so a list of these reads as one
/// unbroken line with a bead at every event. [first] and [last] trim the line
/// at either end.
class CourtThreadBead extends StatelessWidget {
  const CourtThreadBead({
    super.key,
    required this.first,
    required this.last,
    this.highlight = false,
  });

  final bool first;
  final bool last;

  /// The newest bead is lit.
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final palette = context.console;
    return SizedBox(
      width: DsSizes.iconMd,
      child: CustomPaint(
        painter: _ThreadPainter(
          first: first,
          last: last,
          highlight: highlight,
          silk: palette.primary,
          gold: DsColors.gold400,
          ground: palette.surface,
          line: palette.line,
        ),
      ),
    );
  }
}

class _ThreadPainter extends CustomPainter {
  const _ThreadPainter({
    required this.first,
    required this.last,
    required this.highlight,
    required this.silk,
    required this.gold,
    required this.ground,
    required this.line,
  });

  final bool first;
  final bool last;
  final bool highlight;
  final Color silk;
  final Color gold;
  final Color ground;
  final Color line;

  /// Where the bead sits: level with the first line of the row's text.
  static const double _beadY = DsSpacing.md + DsSpacing.xxs;

  @override
  void paint(Canvas canvas, Size size) {
    final x = size.width / 2;
    final thread = Paint()
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [silk.withValues(alpha: 0.55), gold.withValues(alpha: 0.45)],
      ).createShader(Offset.zero & size);
    canvas.drawLine(
      Offset(x, first ? _beadY : 0),
      Offset(x, last ? _beadY : size.height),
      thread,
    );

    final bead = Offset(x, _beadY);
    if (highlight) {
      canvas.drawCircle(bead, 9, Paint()..color = silk.withValues(alpha: 0.16));
    }
    canvas.drawCircle(bead, 5.5, Paint()..color = ground);
    canvas.drawCircle(
      bead,
      5.5,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6
        ..color = highlight ? silk : line,
    );
    canvas.drawCircle(
      bead,
      2.2,
      Paint()..color = highlight ? silk : gold.withValues(alpha: 0.8),
    );
  }

  @override
  bool shouldRepaint(_ThreadPainter old) =>
      old.first != first ||
      old.last != last ||
      old.highlight != highlight ||
      old.silk != silk ||
      old.gold != gold ||
      old.ground != ground ||
      old.line != line;
}

// ---------------------------------------------------------------------------
// The rest of the house: chrome every console page shares
// ---------------------------------------------------------------------------

/// The night ground without the window: the plum gradient and the ceiling
/// lattice. The rail and the phone's top bar stand on it, so the whole console
/// sits under one sky.
class CourtNight extends StatelessWidget {
  const CourtNight({super.key, this.child, this.vertical = true});

  final Widget? child;

  /// Which way the night deepens: down a rail, or across a bar.
  final bool vertical;

  @override
  Widget build(BuildContext context) {
    final palette = context.console;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: vertical
              ? Alignment.topCenter
              : AlignmentDirectional.centerStart.resolve(
                  Directionality.of(context),
                ),
          end: vertical
              ? Alignment.bottomCenter
              : AlignmentDirectional.centerEnd.resolve(
                  Directionality.of(context),
                ),
          colors: [palette.nav, isDark ? DsColors.mauve900 : DsColors.mauve800],
        ),
      ),
      child: CustomPaint(painter: const _LatticePainter(), child: child),
    );
  }
}

class _LatticePainter extends CustomPainter {
  const _LatticePainter();

  static const double _step = 56;

  @override
  void paint(Canvas canvas, Size size) {
    final star = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = DsColors.onMedia.withValues(alpha: 0.045);
    for (double y = _step / 2; y < size.height + _step; y += _step) {
      final offset = (y / _step).floor().isEven ? 0.0 : _step / 2;
      for (double x = offset; x < size.width + _step; x += _step) {
        _drawStar(canvas, Offset(x, y), 9, star);
      }
    }
  }

  @override
  bool shouldRepaint(_LatticePainter oldDelegate) => false;
}

/// A small arch holding an icon — the console's emblem for a room.
///
/// [lit] draws it the way a lit door is drawn: plum night with champagne
/// light. Unlit, it is a soft tint of [color] (the console's action accent by
/// default), for rows and panels on the page.
class CourtArchMedallion extends StatelessWidget {
  const CourtArchMedallion({
    super.key,
    required this.icon,
    this.size = DsSizes.controlMd,
    this.color,
    this.lit = false,
  });

  final IconData icon;
  final double size;
  final Color? color;
  final bool lit;

  @override
  Widget build(BuildContext context) {
    final palette = context.console;
    final tint = color ?? palette.primary;
    return SizedBox(
      width: size,
      height: size * 1.18,
      child: CustomPaint(
        painter: _MedallionPainter(lit: lit, tint: tint, night: palette.nav),
        child: Padding(
          padding: EdgeInsets.only(top: size * 0.22),
          child: Center(
            child: Icon(
              icon,
              size: size * 0.46,
              color: lit ? DsColors.gold100 : tint,
            ),
          ),
        ),
      ),
    );
  }
}

class _MedallionPainter extends CustomPainter {
  const _MedallionPainter({
    required this.lit,
    required this.tint,
    required this.night,
  });

  final bool lit;
  final Color tint;
  final Color night;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final arch = dsArchPath(rect);
    if (lit) {
      canvas.drawPath(
        arch,
        Paint()
          ..shader = RadialGradient(
            center: const Alignment(0, -0.1),
            radius: 0.9,
            colors: [Color.lerp(night, DsColors.gold300, 0.35)!, night],
          ).createShader(rect),
      );
      canvas.drawPath(
        arch,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2
          ..color = DsColors.gold300.withValues(alpha: 0.75),
      );
    } else {
      canvas.drawPath(arch, Paint()..color = tint.withValues(alpha: 0.1));
      canvas.drawPath(
        arch,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = tint.withValues(alpha: 0.28),
      );
    }
  }

  @override
  bool shouldRepaint(_MedallionPainter old) =>
      old.lit != lit || old.tint != tint || old.night != night;
}

/// One figure set on the sky: a count in champagne serif, and what it counts.
@immutable
class CourtHighlight {
  const CourtHighlight({required this.value, required this.label});

  final String value;
  final String label;
}

/// The top of every console page: a band of the courtyard's sky.
///
/// The room's arch emblem, its name in the display serif, a line on what the
/// room is for, and — when the room keeps a queue — its figures lit in
/// champagne, so «١١ مفتوحة» is the first thing read, not a pill under the
/// title. [actions] sit on the sky; icon buttons among them are recoloured
/// for it, so a page's refresh button does not vanish into the night.
class CourtSkyHeader extends StatelessWidget {
  const CourtSkyHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.icon,
    this.actions = const [],
    this.highlights = const [],
  });

  final String title;
  final String? subtitle;
  final IconData? icon;
  final List<Widget> actions;
  final List<CourtHighlight> highlights;

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 600;
    final titleBlock = Row(
      children: [
        if (icon != null) ...[
          CourtArchMedallion(
            icon: icon!,
            lit: true,
            size: compact ? DsSizes.controlMd : DsSizes.controlXl,
          ),
          SizedBox(width: compact ? DsSpacing.sm : DsSpacing.md),
        ],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style:
                    (compact
                            ? context.dsText.screenTitle
                            : context.dsText.pageTitle)
                        .displayFamily
                        .bold
                        .tint(DsColors.onMedia),
              ),
              if (subtitle != null) ...[
                DsGaps.vXxs,
                Text(
                  subtitle!,
                  style: context.dsText.body.tint(DsColors.onMediaMuted),
                ),
              ],
            ],
          ),
        ),
      ],
    );

    final iconsOnly = actions.every((action) => action is IconButton);
    final skyActions = actions.isEmpty
        ? null
        : IconButtonTheme(
            data: IconButtonThemeData(
              style: IconButton.styleFrom(
                foregroundColor: DsColors.onMedia,
                backgroundColor: DsColors.mediaPlate,
                side: const BorderSide(color: DsColors.onMediaFaint),
              ),
            ),
            child: Wrap(
              spacing: DsSpacing.xs,
              runSpacing: DsSpacing.xs,
              alignment: compact ? WrapAlignment.start : WrapAlignment.end,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: actions,
            ),
          );

    return CourtSky(
      window: false,
      padding: compact ? DsSpacing.paddingLg : DsSpacing.paddingXl,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // On a phone, icon buttons stay beside the name — a row of its own
          // for one refresh button is a third of the header spent on air.
          // Anything with a label wraps under the name instead.
          if (compact && skyActions != null && !iconsOnly) ...[
            titleBlock,
            DsGaps.vMd,
            skyActions,
          ] else if (skyActions == null)
            titleBlock
          else
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: titleBlock),
                DsGaps.hMd,
                // Sized to its buttons and pushed to the far edge, with a
                // ceiling so a page with many actions wraps them instead of
                // squeezing its own name.
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: skyActions,
                ),
              ],
            ),
          if (highlights.isNotEmpty) ...[
            DsGaps.vLg,
            Wrap(
              spacing: DsSpacing.xl,
              runSpacing: DsSpacing.sm,
              children: [
                for (final h in highlights)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        h.value,
                        style: context.dsText.metric.displayFamily.tint(
                          DsColors.gold200,
                        ),
                      ),
                      DsGaps.hXs,
                      Text(
                        h.label,
                        style: context.dsText.labelMedium.tint(
                          DsColors.onMediaMuted,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// The console's room: a surface with the court's generous corners.
///
/// With a [title] it carries its own heading — the name, an optional line
/// under it, and a [trailing] slot for a link or a control.
class CourtPanel extends StatelessWidget {
  const CourtPanel({
    super.key,
    required this.child,
    this.title,
    this.caption,
    this.trailing,
    this.padding = DsSpacing.paddingXl,
    this.accent,
  });

  final Widget child;
  final String? title;
  final String? caption;
  final Widget? trailing;
  final EdgeInsetsGeometry padding;

  /// A colour the panel's edge is lit with — a failing check, an urgent
  /// queue. Null for an ordinary room.
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final palette = context.console;
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: DsRadius.borderXxl,
        border: Border.all(
          color: accent?.withValues(alpha: 0.4) ?? palette.line,
        ),
        // A softer footprint than the console's default shadow, which under a
        // panel this large read as a pink plinth.
        boxShadow: accent == null
            ? [
                for (final shadow in palette.shadow)
                  BoxShadow(
                    color: shadow.color.withValues(
                      alpha: shadow.color.a * 0.55,
                    ),
                    blurRadius: shadow.blurRadius * 1.6,
                    offset: shadow.offset * 0.6,
                  ),
              ]
            : context.glowShadow(accent!, blur: 24, alpha: 0.12),
      ),
      child: title == null
          ? child
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                CourtPanelHeading(
                  title: title!,
                  caption: caption,
                  trailing: trailing,
                ),
                DsGaps.vLg,
                child,
              ],
            ),
    );
  }
}

/// A panel's heading: the name in bold with a small champagne star before it,
/// a line under it, and an optional trailing control.
class CourtPanelHeading extends StatelessWidget {
  const CourtPanelHeading({
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
    final palette = context.console;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: DsSpacing.xxs),
          child: CustomPaint(
            size: const Size.square(DsSpacing.md),
            painter: _StarMarkPainter(color: DsColors.gold400),
          ),
        ),
        DsGaps.hXs,
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: context.dsText.cardTitle.bold.tint(palette.ink),
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
        if (trailing != null) ...[DsGaps.hSm, trailing!],
      ],
    );
  }
}

class _StarMarkPainter extends CustomPainter {
  const _StarMarkPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    _drawStar(
      canvas,
      size.center(Offset.zero),
      size.shortestSide * 0.42,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4
        ..color = color,
    );
  }

  @override
  bool shouldRepaint(_StarMarkPainter old) => old.color != color;
}

/// One figure in a panel: what it measures, the number in the display serif,
/// and an optional line under it. Keyed by [accent] on its leading edge, the
/// way the rose's readings are.
class CourtFigure extends StatelessWidget {
  const CourtFigure({
    super.key,
    required this.label,
    required this.value,
    this.accent,
    this.footnote,
    this.footnoteColor,
    this.icon,
  });

  final String label;
  final String value;
  final Color? accent;
  final String? footnote;
  final Color? footnoteColor;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final palette = context.console;
    final edge = accent ?? palette.primary;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: DsSpacing.md,
        vertical: DsSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: palette.surfaceAlt.withValues(alpha: 0.6),
        borderRadius: DsRadius.borderLg,
        border: BorderDirectional(
          start: BorderSide(color: edge, width: DsSpacing.xxs),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              if (icon != null) ...[
                Icon(icon, size: DsSizes.iconXs, color: edge),
                DsGaps.hXxs,
              ],
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.dsText.metricLabel.tint(palette.muted),
                ),
              ),
            ],
          ),
          DsGaps.vXxs,
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: AlignmentDirectional.centerStart,
            child: Text(
              value,
              style: context.dsText.metric.displayFamily.tint(palette.ink),
            ),
          ),
          if (footnote != null) ...[
            DsGaps.vXxs,
            Text(
              footnote!,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: context.dsText.captionStrong.tint(
                footnoteColor ?? palette.muted,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// A row of figures that wraps to the width it is given, each tile at least
/// [minTileWidth] wide.
class CourtFigureRow extends StatelessWidget {
  const CourtFigureRow({
    super.key,
    required this.children,
    this.minTileWidth = 180,
    this.maxColumns = 4,
  });

  final List<Widget> children;
  final double minTileWidth;
  final int maxColumns;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const gap = DsSpacing.md;
        final columns = (constraints.maxWidth / minTileWidth).floor().clamp(
          1,
          math.min(maxColumns, math.max(children.length, 1)),
        );
        final width = (constraints.maxWidth - gap * (columns - 1)) / columns;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final child in children) SizedBox(width: width, child: child),
          ],
        );
      },
    );
  }
}

/// One option on a [CourtFilterBeads] row.
@immutable
class CourtFilterOption<T> {
  const CourtFilterOption({required this.value, required this.label});

  final T? value;
  final String label;
}

/// Queue filters as a string of beads: the chosen one lit in plum and
/// champagne, the rest quiet. One line that scrolls sideways on a phone,
/// rather than a wrap of chips that pushes the list off the screen.
class CourtFilterBeads<T> extends StatelessWidget {
  const CourtFilterBeads({
    super.key,
    required this.options,
    required this.selected,
    required this.onSelected,
  });

  final List<CourtFilterOption<T>> options;
  final T? selected;
  final ValueChanged<T?> onSelected;

  @override
  Widget build(BuildContext context) {
    final palette = context.console;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final option in options)
            Padding(
              padding: const EdgeInsetsDirectional.only(end: DsSpacing.xs),
              child: _Bead(
                label: option.label,
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

class _Bead extends StatelessWidget {
  const _Bead({
    required this.label,
    required this.selected,
    required this.palette,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final AdminConsolePalette palette;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: label,
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
              gradient: selected
                  ? LinearGradient(colors: [palette.nav, DsColors.mauve700])
                  : null,
              color: selected ? null : palette.surface,
              border: Border.all(
                color: selected
                    ? DsColors.gold300.withValues(alpha: 0.6)
                    : palette.line,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (selected) ...[
                  Container(
                    width: DsSpacing.xs,
                    height: DsSpacing.xs,
                    decoration: const BoxDecoration(
                      color: DsColors.gold200,
                      shape: BoxShape.circle,
                    ),
                  ),
                  DsGaps.hXs,
                ],
                Text(
                  label,
                  style: context.dsText.labelLarge
                      .copyWith(
                        fontWeight: selected
                            ? DsTypography.semiBold
                            : DsTypography.medium,
                      )
                      .tint(selected ? DsColors.onMedia : palette.ink),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A status, in the colour of what it means.
class CourtStatusPill extends StatelessWidget {
  const CourtStatusPill({super.key, required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: DsSpacing.pillPadding,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: DsRadius.borderPill,
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: DsSpacing.xxs + DsSpacing.xxxs,
            height: DsSpacing.xxs + DsSpacing.xxxs,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          DsGaps.hXxs,
          Text(label, style: context.dsText.badge.tint(color)),
        ],
      ),
    );
  }
}

/// A quiet room: nothing to show, said plainly, under a small empty arch.
class CourtQuietNote extends StatelessWidget {
  const CourtQuietNote({
    super.key,
    required this.message,
    this.icon = Icons.spa_outlined,
    this.color,
    this.action,
  });

  final String message;
  final IconData icon;
  final Color? color;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final palette = context.console;
    return CourtPanel(
      accent: color,
      child: Row(
        children: [
          CourtArchMedallion(icon: icon, color: color ?? palette.positive),
          DsGaps.hMd,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(message, style: context.dsText.body.tint(palette.muted)),
                if (action != null) ...[DsGaps.vMd, action!],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The side margin of a console page: the full gutter on a tablet or desktop,
/// a phone's narrower one below 600dp, so a page does not lose a sixth of a
/// phone's width to air.
double courtGutter(BuildContext context) =>
    MediaQuery.sizeOf(context).width < 600 ? DsSpacing.md : DsSpacing.xl;
