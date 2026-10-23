import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:reem/core/design_system/design_system.dart';

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
/// * [CourtDoor] — the doors around the court, cut to Reem's arch. A door with
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
  const CourtSky({super.key, required this.child, this.padding});

  final Widget child;
  final EdgeInsetsGeometry? padding;

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
          painter: _SkyPainter(rtl: rtl),
          child: Padding(
            padding: padding ?? DsSpacing.paddingXl,
            child: child,
          ),
        ),
      ),
    );
  }
}

class _SkyPainter extends CustomPainter {
  const _SkyPainter({required this.rtl});

  final bool rtl;

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
        ..shader = RadialGradient(
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
        ..shader = RadialGradient(
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
      for (double x = offset; x < size.width + _latticeStep; x +=
          _latticeStep) {
        _drawStar(canvas, Offset(x, y), 9, star);
      }
    }

    // The arch window: tall, on the far side, holding a moon.
    final archHeight = size.height * 1.1;
    final archWidth = math.min(size.width * 0.22, archHeight * 0.55);
    final archLeft = rtl
        ? size.width * 0.06
        : size.width * 0.94 - archWidth;
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
      Path()
        ..addOval(
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
  bool shouldRepaint(_SkyPainter oldDelegate) => oldDelegate.rtl != rtl;
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
      canvas.drawCircle(
        Offset(length, 0),
        3,
        Paint()..color = color,
      );
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

/// A door off the courtyard, cut to Reem's arch.
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
          ..shader = RadialGradient(
            colors: [
              DsColors.gold300.withValues(alpha: 0.42),
              DsColors.gold300.withValues(alpha: 0.08),
              DsColors.gold300.withValues(alpha: 0),
            ],
            stops: const [0, 0.5, 1],
          ).createShader(Rect.fromCircle(center: lamp, radius: size.width * 0.9)),
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
      canvas.drawCircle(
        bead,
        9,
        Paint()..color = silk.withValues(alpha: 0.16),
      );
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
