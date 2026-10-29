import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:ohara/core/design_system/design_system.dart';
import 'package:ohara/features/home/presentation/widgets/home_greeting.dart';

/// The colours of the home's sky at one moment of a Damascus day.
///
/// The hero is painted from three soft orbs drifting over a wash, and the
/// palette follows the hour: champagne and blush in the morning, rose in the
/// afternoon, a warm dusk after five, and a deep plum after ten. Dark mode
/// keeps the night palette all day, because a bright sky under a dark app
/// reads as a mistake rather than as a mood.
@immutable
class AuraPalette {
  const AuraPalette({
    required this.wash,
    required this.orbs,
    required this.ink,
    required this.inkMuted,
    required this.glass,
    required this.glassBorder,
    required this.isDeep,
  });

  /// The base gradient, top to bottom.
  final List<Color> wash;

  /// Three orb colours, drawn in this order.
  final List<Color> orbs;

  /// Text and icons on the sky.
  final Color ink;
  final Color inkMuted;

  /// Chips and the ask field sitting on the sky.
  final Color glass;
  final Color glassBorder;

  /// True when the sky is dark enough to need light ink.
  final bool isDeep;

  static AuraPalette of(HomeGreetingSlot slot, {required bool isDark}) {
    if (isDark || slot == HomeGreetingSlot.night) return _night;
    return switch (slot) {
      HomeGreetingSlot.morning => _morning,
      HomeGreetingSlot.midday => _midday,
      HomeGreetingSlot.evening => _evening,
      HomeGreetingSlot.night => _night,
    };
  }

  static final AuraPalette _morning = AuraPalette(
    wash: const [
      DsColors.gold100,
      DsColors.primary100,
      DsColors.backgroundSecondary,
    ],
    orbs: const [DsColors.gold300, DsColors.primary300, DsColors.secondary200],
    ink: DsColors.neutral900,
    inkMuted: DsColors.neutral600,
    glass: DsColors.white.withValues(alpha: 0.62),
    glassBorder: DsColors.white.withValues(alpha: 0.9),
    isDeep: false,
  );

  static final AuraPalette _midday = AuraPalette(
    wash: const [
      DsColors.primary200,
      DsColors.secondary100,
      DsColors.backgroundSecondary,
    ],
    orbs: const [DsColors.primary400, DsColors.secondary400, DsColors.gold200],
    ink: DsColors.neutral900,
    inkMuted: DsColors.neutral600,
    glass: DsColors.white.withValues(alpha: 0.6),
    glassBorder: DsColors.white.withValues(alpha: 0.9),
    isDeep: false,
  );

  static final AuraPalette _evening = AuraPalette(
    wash: const [
      DsColors.primary300,
      DsColors.secondary200,
      DsColors.backgroundSecondary,
    ],
    orbs: const [DsColors.rosewood, DsColors.primary500, DsColors.secondary400],
    ink: DsColors.neutral950,
    inkMuted: DsColors.neutral700,
    glass: DsColors.white.withValues(alpha: 0.55),
    glassBorder: DsColors.white.withValues(alpha: 0.85),
    isDeep: false,
  );

  static final AuraPalette _night = AuraPalette(
    wash: const [DsColors.secondary900, DsColors.primary900, DsColors.mediaGround],
    orbs: const [DsColors.primary700, DsColors.secondary500, DsColors.secondary600],
    ink: DsColors.onMedia,
    inkMuted: DsColors.onMediaMuted,
    glass: DsColors.white.withValues(alpha: 0.1),
    glassBorder: DsColors.white.withValues(alpha: 0.22),
    isDeep: true,
  );
}

/// The drifting orbs behind the home hero.
///
/// One slow controller drives all three, each on its own phase and path, so
/// the sky never visibly loops. Painted rather than blurred: a radial
/// gradient that fades to transparent is the blur, at no cost per frame.
class AuraCanvas extends StatefulWidget {
  const AuraCanvas({super.key, required this.palette});

  final AuraPalette palette;

  @override
  State<AuraCanvas> createState() => _AuraCanvasState();
}

class _AuraCanvasState extends State<AuraCanvas>
    with SingleTickerProviderStateMixin {
  late final AnimationController _drift = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 18),
  );

  @override
  void initState() {
    super.initState();
    // A shopper who asked for less motion gets a still sky.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (MediaQuery.disableAnimationsOf(context)) return;
      _drift.repeat();
    });
  }

  @override
  void dispose() {
    _drift.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: CustomPaint(
        painter: _AuraPainter(palette: widget.palette, drift: _drift),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class _AuraPainter extends CustomPainter {
  _AuraPainter({required this.palette, required this.drift})
    : super(repaint: drift);

  final AuraPalette palette;
  final Animation<double> drift;

  /// Each orb: where it rests (as a fraction of the canvas), how far it
  /// wanders, its radius as a fraction of the width, and its phase.
  static const _orbits = [
    (Offset(0.82, 0.18), Offset(0.10, 0.06), 0.70, 0.0),
    (Offset(0.12, 0.42), Offset(0.08, 0.10), 0.62, 0.33),
    (Offset(0.60, 0.78), Offset(0.12, 0.05), 0.58, 0.66),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: palette.wash,
        ).createShader(rect),
    );

    final t = drift.value * 2 * math.pi;
    for (var i = 0; i < _orbits.length; i++) {
      final (rest, reach, radiusFactor, phase) = _orbits[i];
      final angle = t + phase * 2 * math.pi;
      final center = Offset(
        (rest.dx + reach.dx * math.sin(angle)) * size.width,
        (rest.dy + reach.dy * math.cos(angle * 0.8)) * size.height,
      );
      final radius = size.width * radiusFactor;
      final color = palette.orbs[i % palette.orbs.length];
      canvas.drawCircle(
        center,
        radius,
        Paint()
          ..shader = RadialGradient(
            colors: [
              color.withValues(alpha: palette.isDeep ? 0.55 : 0.75),
              color.withValues(alpha: 0),
            ],
          ).createShader(Rect.fromCircle(center: center, radius: radius)),
      );
    }
  }

  @override
  bool shouldRepaint(_AuraPainter old) => old.palette != palette;
}
