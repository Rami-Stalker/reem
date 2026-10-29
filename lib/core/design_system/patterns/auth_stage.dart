import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:ohara/core/design_system/design_system.dart';
import 'package:ohara/core/router/open_route.dart';

/// The sign-in register: **the boutique at dusk**.
///
/// Every screen on the way in — the number, the code, the signup form, the
/// "you need an account for this" explainer — is drawn on the same stage, so
/// the journey reads as one moment rather than five unrelated forms:
///
/// * [AuthAurora] — a slow, living ground of rose, orchid and champagne light,
///   crossed by two silk ribbons and a handful of twinkling sparkles.
/// * [AuthEmblem] — the brand mark set inside a pointed arch, the shape of a
///   Levantine window, framed by a turning rose-to-champagne thread.
/// * [AuthPanel] — the frosted card the form sits on.
/// * [AuthCodeField] — six separate cells for a one-time code.
///
/// Motion is ambient and never required: with "reduce motion" on, every loop
/// here holds still on a composed frame.

// ---------------------------------------------------------------------------
// Stage
// ---------------------------------------------------------------------------

/// The page scaffold for the sign-in journey.
///
/// [children] are laid out in a column that fills at least the viewport, so a
/// screen can centre itself with `Spacer`s and still scroll when the keyboard
/// is up.
class AuthStage extends StatelessWidget {
  const AuthStage({
    super.key,
    required this.children,
    this.showBack = false,
    this.onBack,
    this.step,
    this.stepCount = 3,
  });

  final List<Widget> children;
  final bool showBack;

  /// Defaults to popping, or home when there is nothing to pop to.
  final VoidCallback? onBack;

  /// Zero-based position in the number → code → profile journey. Null hides
  /// the journey thread.
  final int? step;
  final int stepCount;

  /// Wide enough for a comfortable form, narrow enough that a tablet does not
  /// stretch a phone field across the whole screen.
  static const double maxContentWidth = 460;

  @override
  Widget build(BuildContext context) {
    final colors = context.dsColors;
    final hasTopBar = showBack || step != null;

    return Scaffold(
      backgroundColor: colors.background,
      body: Stack(
        fit: StackFit.expand,
        children: [
          const AuthAurora(),
          SafeArea(
            child: CustomScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              slivers: [
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(
                        maxWidth: maxContentWidth,
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: DsSpacing.lg,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (hasTopBar)
                              Padding(
                                padding: const EdgeInsets.only(
                                  top: DsSpacing.xs,
                                ),
                                child: _TopBar(
                                  showBack: showBack,
                                  onBack: onBack,
                                  step: step,
                                  stepCount: stepCount,
                                ),
                              )
                            else
                              DsGaps.vMd,
                            ...children,
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.showBack,
    required this.onBack,
    required this.step,
    required this.stepCount,
  });

  final bool showBack;
  final VoidCallback? onBack;
  final int? step;
  final int stepCount;

  static const double _slot = 44;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: _slot,
      child: Row(
        children: [
          SizedBox(
            width: _slot,
            child: showBack ? AuthBackButton(onPressed: onBack) : null,
          ),
          Expanded(
            child: Center(
              child: step == null
                  ? null
                  : AuthJourney(step: step!, count: stepCount),
            ),
          ),
          const SizedBox(width: _slot),
        ],
      ),
    );
  }
}

/// A frosted circular back button that floats on the aurora.
class AuthBackButton extends StatelessWidget {
  const AuthBackButton({super.key, this.onPressed});

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = context.dsColors;
    return DecoratedBox(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: colors.surface.withValues(alpha: 0.72),
        border: Border.all(color: colors.border.withValues(alpha: 0.7)),
        boxShadow: context.shadowXs,
      ),
      child: IconButton(
        icon: Icon(DsIcons.back, size: DsSizes.iconXs, color: colors.onSurface),
        tooltip: MaterialLocalizations.of(context).backButtonTooltip,
        onPressed: onPressed ?? () => popOrHome(context),
      ),
    );
  }
}

/// The journey thread: one pill per step, the current one long and lit.
class AuthJourney extends StatelessWidget {
  const AuthJourney({super.key, required this.step, this.count = 3});

  final int step;
  final int count;

  @override
  Widget build(BuildContext context) {
    final colors = context.dsColors;
    return ExcludeSemantics(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < count; i++)
            AnimatedContainer(
              duration: DsMotion.slow,
              curve: DsMotion.softSpring,
              margin: const EdgeInsets.symmetric(horizontal: DsSpacing.xxxs),
              width: i == step ? 28 : 8,
              height: 8,
              decoration: BoxDecoration(
                borderRadius: DsRadius.borderPill,
                gradient: i == step ? context.primaryGradient : null,
                color: i == step
                    ? null
                    : i < step
                    ? colors.primary.withValues(alpha: 0.5)
                    : colors.onSurfaceVariant.withValues(alpha: 0.22),
                boxShadow: i == step
                    ? context.glowShadow(colors.primary, blur: 10, alpha: 0.35)
                    : null,
              ),
            ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Aurora
// ---------------------------------------------------------------------------

/// The living ground behind the sign-in journey.
///
/// Four soft blooms of light drift on slow, looping paths; two silk ribbons
/// undulate across the page; sparkles twinkle in the upper half where the
/// emblem sits. Everything is painted in one layer from one controller, so the
/// cost is a single repaint per frame with no blur filters.
/// Which light the aurora is made of: the boutique's rose, or the warmer
/// champagne a seller's page stands in.
enum AuroraTone { rose, champagne }

class AuthAurora extends StatefulWidget {
  const AuthAurora({super.key, this.tone = AuroraTone.rose});

  final AuroraTone tone;

  @override
  State<AuthAurora> createState() => _AuthAuroraState();
}

class _AuthAuroraState extends State<AuthAurora>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 28),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final still = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (still) {
      _controller
        ..stop()
        ..value = 0.3;
    } else if (!_controller.isAnimating) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return RepaintBoundary(
      child: CustomPaint(
        size: Size.infinite,
        painter: _AuroraPainter(
          animation: _controller,
          palette: switch ((widget.tone, isDark)) {
            (AuroraTone.rose, false) => _AuroraPalette.light,
            (AuroraTone.rose, true) => _AuroraPalette.dark,
            (AuroraTone.champagne, false) => _AuroraPalette.champagneLight,
            (AuroraTone.champagne, true) => _AuroraPalette.champagneDark,
          },
        ),
      ),
    );
  }
}

@immutable
class _AuroraPalette {
  const _AuroraPalette({
    required this.ground,
    required this.rose,
    required this.orchid,
    required this.champagne,
    required this.ribbonRose,
    required this.ribbonGold,
    required this.sparkle,
  });

  final List<Color> ground;
  final Color rose;
  final Color orchid;
  final Color champagne;
  final Color ribbonRose;
  final Color ribbonGold;
  final Color sparkle;

  static final light = _AuroraPalette(
    ground: const [
      DsColors.background,
      DsColors.backgroundPink,
      DsColors.secondary50,
    ],
    rose: DsColors.primary300.withValues(alpha: 0.55),
    orchid: DsColors.secondary300.withValues(alpha: 0.40),
    champagne: DsColors.softGold.withValues(alpha: 0.45),
    ribbonRose: DsColors.primary500.withValues(alpha: 0.18),
    ribbonGold: DsColors.champagneGold.withValues(alpha: 0.25),
    sparkle: DsColors.champagneGold,
  );

  static final champagneLight = _AuroraPalette(
    ground: const [
      DsColors.background,
      DsColors.backgroundSecondary,
      DsColors.backgroundPink,
    ],
    rose: DsColors.primary300.withValues(alpha: 0.35),
    orchid: DsColors.peachCream.withValues(alpha: 0.45),
    champagne: DsColors.softGold.withValues(alpha: 0.60),
    ribbonRose: DsColors.primary500.withValues(alpha: 0.14),
    ribbonGold: DsColors.champagneGold.withValues(alpha: 0.35),
    sparkle: DsColors.gold500,
  );

  static final champagneDark = _AuroraPalette(
    ground: const [
      Color(0xFF1C1614), // warm champagne-tinted night
      DsColors.backgroundDark,
      DsColors.surfaceDimDark,
    ],
    rose: DsColors.primary300.withValues(alpha: 0.19),
    orchid: DsColors.softGold.withValues(alpha: 0.22),
    champagne: DsColors.softGold.withValues(alpha: 0.25),
    ribbonRose: DsColors.primary300.withValues(alpha: 0.12),
    ribbonGold: DsColors.softGold.withValues(alpha: 0.18),
    sparkle: DsColors.softGold,
  );

  static final dark = _AuroraPalette(
    ground: const [
      DsColors.surfaceDark,
      DsColors.backgroundDark,
      DsColors.surfaceDimDark,
    ],
    rose: DsColors.primary300.withValues(alpha: 0.25),
    orchid: DsColors.secondary300.withValues(alpha: 0.22),
    champagne: DsColors.softGold.withValues(alpha: 0.14),
    ribbonRose: DsColors.primary300.withValues(alpha: 0.14),
    ribbonGold: DsColors.softGold.withValues(alpha: 0.12),
    sparkle: DsColors.softGold,
  );
}

/// One drifting bloom: a resting centre (as a fraction of the page), how far
/// it wanders, how fast, and how large it is relative to the short side.
class _Bloom {
  const _Bloom(
    this.cx,
    this.cy,
    this.ax,
    this.ay,
    this.fx,
    this.fy,
    this.phase,
    this.radius,
  );

  final double cx, cy, ax, ay, phase, radius;

  /// Whole numbers, so every path closes exactly when the controller loops.
  final int fx, fy;
}

/// A sparkle at a fixed spot, twinkling at its own rate.
class _Twinkle {
  const _Twinkle(this.x, this.y, this.size, this.rate, this.phase);

  final double x, y, size, phase;
  final int rate;
}

class _AuroraPainter extends CustomPainter {
  _AuroraPainter({required this.animation, required this.palette})
    : super(repaint: animation);

  final Animation<double> animation;
  final _AuroraPalette palette;

  static const _blooms = [
    _Bloom(0.92, 0.06, 0.10, 0.06, 1, 1, 0.0, 0.95), // rose, top corner
    _Bloom(0.04, 0.42, 0.08, 0.10, 1, 2, 1.7, 0.85), // orchid, side
    _Bloom(0.80, 0.98, 0.12, 0.05, 2, 1, 3.1, 0.90), // champagne, foot
    _Bloom(0.18, 0.04, 0.10, 0.05, 1, 1, 4.4, 0.55), // small rose, top
  ];

  static const _twinkles = [
    _Twinkle(0.12, 0.10, 9, 2, 0.0),
    _Twinkle(0.86, 0.17, 12, 3, 1.3),
    _Twinkle(0.24, 0.27, 6, 4, 2.6),
    _Twinkle(0.74, 0.31, 7, 2, 3.4),
    _Twinkle(0.93, 0.44, 8, 3, 0.8),
    _Twinkle(0.06, 0.56, 10, 2, 2.0),
    _Twinkle(0.55, 0.06, 7, 5, 4.2),
    _Twinkle(0.40, 0.18, 5, 3, 5.1),
    _Twinkle(0.65, 0.88, 8, 2, 1.1),
    _Twinkle(0.14, 0.86, 6, 4, 3.8),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final t = animation.value;
    final rect = Offset.zero & size;
    const tau = math.pi * 2;

    // The blooms are larger than the box; outside it they would tint whatever
    // is drawn next — on a profile, the page under the hero.
    canvas.clipRect(rect);

    // Ground.
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: palette.ground,
        ).createShader(rect),
    );

    // Blooms.
    final short = size.shortestSide;
    final bloomColours = [
      palette.rose,
      palette.orchid,
      palette.champagne,
      palette.rose,
    ];
    for (var i = 0; i < _blooms.length; i++) {
      final b = _blooms[i];
      final centre = Offset(
        size.width * (b.cx + b.ax * math.sin(tau * t * b.fx + b.phase)),
        size.height * (b.cy + b.ay * math.cos(tau * t * b.fy + b.phase)),
      );
      final radius = short * b.radius;
      final colour = bloomColours[i];
      canvas.drawCircle(
        centre,
        radius,
        Paint()
          ..shader = RadialGradient(
            colors: [colour, colour.withValues(alpha: 0)],
          ).createShader(Rect.fromCircle(center: centre, radius: radius)),
      );
    }

    // Silk ribbons.
    _ribbon(
      canvas,
      size,
      baseY: 0.30,
      amplitude: 0.05,
      phase: tau * t,
      width: 30,
      colour: palette.ribbonGold,
    );
    _ribbon(
      canvas,
      size,
      baseY: 0.78,
      amplitude: 0.045,
      phase: tau * t + math.pi * 0.7,
      width: 20,
      colour: palette.ribbonRose,
    );

    // Sparkles.
    for (final s in _twinkles) {
      final wave = (math.sin(tau * t * s.rate + s.phase) + 1) / 2;
      final alpha = 0.12 + 0.88 * math.pow(wave, 3).toDouble();
      _sparkle(
        canvas,
        Offset(size.width * s.x, size.height * s.y),
        s.size * (0.75 + 0.25 * wave),
        palette.sparkle.withValues(alpha: palette.sparkle.a * alpha * 0.8),
      );
    }
  }

  void _ribbon(
    Canvas canvas,
    Size size, {
    required double baseY,
    required double amplitude,
    required double phase,
    required double width,
    required Color colour,
  }) {
    final w = size.width;
    final h = size.height;
    double y(double x, double shift) =>
        h * (baseY + amplitude * math.sin(phase + shift + x * 3.2));

    final path = Path()..moveTo(-w * 0.1, y(0, 0));
    path.cubicTo(
      w * 0.25,
      y(0.25, 1.1) - h * 0.08,
      w * 0.55,
      y(0.55, 2.0) + h * 0.09,
      w * 0.8,
      y(0.8, 2.6),
    );
    path.quadraticBezierTo(
      w * 0.98,
      y(0.95, 3.0) - h * 0.04,
      w * 1.15,
      y(1.1, 3.4),
    );

    final bounds = Rect.fromLTWH(0, 0, w, h);
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = width
        ..strokeCap = StrokeCap.round
        ..shader = LinearGradient(
          colors: [
            colour.withValues(alpha: 0),
            colour,
            colour,
            colour.withValues(alpha: 0),
          ],
          stops: const [0, 0.25, 0.75, 1],
        ).createShader(bounds),
    );
  }

  @override
  bool shouldRepaint(_AuroraPainter old) =>
      old.palette != palette || old.animation != animation;
}

/// The four-point couture star, drawn at [centre].
void _sparkle(Canvas canvas, Offset centre, double size, Color colour) {
  final r = size / 2;
  final k = r * 0.14;
  final cx = centre.dx;
  final cy = centre.dy;
  final path = Path()
    ..moveTo(cx, cy - r)
    ..quadraticBezierTo(cx + k, cy - k, cx + r, cy)
    ..quadraticBezierTo(cx + k, cy + k, cx, cy + r)
    ..quadraticBezierTo(cx - k, cy + k, cx - r, cy)
    ..quadraticBezierTo(cx - k, cy - k, cx, cy - r)
    ..close();
  canvas.drawPath(path, Paint()..color = colour);
}

// ---------------------------------------------------------------------------
// Emblem
// ---------------------------------------------------------------------------

/// The brand mark in an arch.
///
/// A pointed arch — the window shape of old Damascus houses — filled with the
/// rose signature blend and framed twice: a turning rose → orchid → champagne
/// thread outside, a fine pearl hairline inside. Two sparkles orbit it and a
/// third sits on the keystone. It floats a few pixels up and down, slowly.
///
/// Give it a [monogram] for the front door, or an [icon] for a step.
class AuthEmblem extends StatefulWidget {
  const AuthEmblem({super.key, this.icon, this.monogram, this.size = 104})
    : assert(icon != null || monogram != null);

  final IconData? icon;
  final String? monogram;

  /// The arch's width; its height is proportional.
  final double size;

  @override
  State<AuthEmblem> createState() => _AuthEmblemState();
}

class _AuthEmblemState extends State<AuthEmblem>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 9),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final still = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (still) {
      _controller
        ..stop()
        ..value = 0.12;
    } else if (!_controller.isAnimating) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.dsColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final archWidth = widget.size;
    final archHeight = widget.size * 1.24;
    final canvasWidth = archWidth * 1.8;
    final canvasHeight = archHeight * 1.32;
    final archRect = Rect.fromCenter(
      center: Offset(canvasWidth / 2, canvasHeight / 2),
      width: archWidth,
      height: archHeight,
    );

    final content = widget.monogram != null
        ? Text(
            widget.monogram!,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: DsTypography.fontFamilyDisplay,
              fontFamilyFallback: DsTypography.displayFallback,
              fontSize: archWidth * 0.5,
              fontStyle: FontStyle.italic,
              fontWeight: DsTypography.bold,
              height: 1,
              color: DsColors.onMedia,
              shadows: [
              Shadow(
                color: DsColors.primary900.withValues(alpha: 0.25),
                blurRadius: 12,
              ),
            ],
            ),
          )
        : Icon(
            widget.icon,
            size: archWidth * 0.38,
            color: DsColors.onMedia,
            shadows: [
              Shadow(
                color: DsColors.primary900.withValues(alpha: 0.25),
                blurRadius: 12,
              ),
            ],
          );

    // Centred here so a stretching column cannot pull the canvas wide and
    // leave the arch painted off to one side.
    return ExcludeSemantics(
      child: Center(
        child: SizedBox(
          width: canvasWidth,
          height: canvasHeight,
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              final lift = math.sin(_controller.value * math.pi * 2) * 4;
              return Transform.translate(offset: Offset(0, lift), child: child);
            },
            child: Stack(
              children: [
                Positioned.fill(
                  child: CustomPaint(
                    painter: _EmblemPainter(
                      animation: _controller,
                      arch: archRect,
                      glow: colors.primary.withValues(
                        alpha: isDark ? 0.45 : 0.38,
                      ),
                      sparkle: isDark ? DsColors.gold300 : DsColors.gold400,
                    ),
                  ),
                ),
                Positioned.fromRect(
                  rect: archRect,
                  child: Align(
                    alignment: const Alignment(0, 0.24),
                    child: content,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _EmblemPainter extends CustomPainter {
  _EmblemPainter({
    required this.animation,
    required this.arch,
    required this.glow,
    required this.sparkle,
  }) : super(repaint: animation);

  final Animation<double> animation;
  final Rect arch;
  final Color glow;
  final Color sparkle;

  static const _thread = [
    DsColors.primary500,
    DsColors.secondary400,
    DsColors.gold300,
    DsColors.primary300,
    DsColors.primary500,
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final t = animation.value;
    const tau = math.pi * 2;

    // Halo.
    canvas.drawPath(
      dsArchPath(arch.inflate(4)),
      Paint()
        ..color = glow
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 26),
    );

    // Turning thread.
    final outer = dsArchPath(arch);
    canvas.drawPath(
      outer,
      Paint()
        ..shader = SweepGradient(
          colors: _thread,
          transform: GradientRotation(tau * t),
        ).createShader(arch),
    );

    // The window itself.
    final inner = dsArchPath(arch.deflate(3.5));
    canvas.drawPath(
      inner,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [DsColors.primary400, DsColors.primary600, DsColors.secondary600],
          stops: [0, 0.55, 1],
        ).createShader(arch),
    );

    // Light falling through the window: a pearl sheen from the top.
    canvas.save();
    canvas.clipPath(inner);
    canvas.drawRect(
      arch,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.center,
          colors: [Color(0x59FFFFFF), Color(0x00FFFFFF)],
        ).createShader(arch),
    );
    // A slow glint that crosses the glass once per loop.
    final glintX = arch.left - arch.width + (arch.width * 3) * ((t * 1.0) % 1);
    canvas.drawRect(
      arch,
      Paint()
        ..shader =
            LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: const [
                Color(0x00FFFFFF),
                Color(0x38FFFFFF),
                Color(0x00FFFFFF),
              ],
              stops: const [0.35, 0.5, 0.65],
            ).createShader(
              Rect.fromLTWH(glintX, arch.top, arch.width, arch.height),
            ),
    );
    canvas.restore();

    // Inner pearl hairline.
    canvas.drawPath(
      dsArchPath(arch.deflate(9)),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = const Color(0x66FFFFFF),
    );

    // Keystone sparkle.
    final pulse = (math.sin(tau * t * 2) + 1) / 2;
    _sparkle(
      canvas,
      Offset(arch.center.dx, arch.top - 10),
      12 + 4 * pulse,
      sparkle.withValues(alpha: 0.55 + 0.45 * pulse),
    );

    // Two orbiting sparkles on an ellipse around the arch.
    final rx = arch.width * 0.82;
    final ry = arch.height * 0.56;
    for (var i = 0; i < 2; i++) {
      final angle = tau * t + i * math.pi;
      final pos = Offset(
        arch.center.dx + rx * math.cos(angle),
        arch.center.dy + ry * math.sin(angle) * 0.9,
      );
      // Dimmer when it passes "behind" the arch.
      final depth = (math.sin(angle) + 1) / 2;
      _sparkle(
        canvas,
        pos,
        7 + 5 * depth,
        sparkle.withValues(alpha: 0.25 + 0.6 * depth),
      );
    }
  }

  @override
  bool shouldRepaint(_EmblemPainter old) =>
      old.arch != arch || old.glow != glow || old.sparkle != sparkle;
}

// ---------------------------------------------------------------------------
// Heading
// ---------------------------------------------------------------------------

/// Eyebrow, display title in the rose blend, and a quiet supporting line.
class AuthHeading extends StatelessWidget {
  const AuthHeading({
    super.key,
    required this.title,
    this.eyebrow,
    this.subtitle,
  });

  final String title;
  final String? eyebrow;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final colors = context.dsColors;
    final text = context.dsText;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (eyebrow != null) ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              DsSparkle(size: 9, color: colors.accent),
              DsGaps.hXs,
              Flexible(
                child: Text(
                  eyebrow!,
                  textAlign: TextAlign.center,
                  style: text.overline.copyWith(
                    color: colors.primary,
                    letterSpacing: 1.6,
                  ),
                ),
              ),
              DsGaps.hXs,
              DsSparkle(size: 9, color: colors.accent),
            ],
          ),
          DsGaps.vSm,
        ],
        ShaderMask(
          blendMode: BlendMode.srcIn,
          shaderCallback: (bounds) => LinearGradient(
            colors: [colors.primary, colors.secondary, colors.primary],
            stops: const [0, 0.6, 1],
          ).createShader(bounds),
          child: Text(
            title,
            textAlign: TextAlign.center,
            style: text.pageTitle.bold.copyWith(
              color: DsColors.onMedia,
              height: 1.25,
            ),
          ),
        ),
        if (subtitle != null) ...[
          DsGaps.vSm,
          Text(
            subtitle!,
            textAlign: TextAlign.center,
            style: text.body.copyWith(
              color: colors.onSurfaceVariant,
              height: 1.6,
            ),
          ),
        ],
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Panel
// ---------------------------------------------------------------------------

/// The frosted card a form sits on: a translucent pearl surface, a
/// light-catching gradient rim and a deep, soft rose shadow.
///
/// Deliberately no `BackdropFilter`: the aurora behind it is already all soft
/// light, so a blur would cost a full-screen pass every frame for no change
/// anyone could see.
class AuthPanel extends StatelessWidget {
  const AuthPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(DsSpacing.xl),
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  static const BorderRadius radius = DsRadius.borderXxxl;

  @override
  Widget build(BuildContext context) {
    final colors = context.dsColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final ground = isDark ? colors.surfaceElevated : colors.surface;

    return CustomPaint(
      foregroundPainter: _RimPainter(
        radius: DsRadius.xxxl,
        colors: isDark
            ? [
                DsColors.white.withValues(alpha: 0.16),
                colors.primary.withValues(alpha: 0.28),
                DsColors.gold300.withValues(alpha: 0.22),
              ]
            : [
                DsColors.white.withValues(alpha: 0.95),
                DsColors.primary300.withValues(alpha: 0.45),
                DsColors.gold300.withValues(alpha: 0.6),
              ],
      ),
      child: Container(
        padding: padding,
        decoration: BoxDecoration(
          borderRadius: radius,
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              ground.withValues(alpha: isDark ? 0.82 : 0.9),
              ground.withValues(alpha: isDark ? 0.7 : 0.74),
            ],
          ),
          boxShadow: [
            BoxShadow(
              color: colors.shadow,
              blurRadius: 40,
              offset: const Offset(0, 18),
            ),
          ],
        ),
        child: child,
      ),
    );
  }
}

class _RimPainter extends CustomPainter {
  const _RimPainter({required this.radius, required this.colors});

  final double radius;
  final List<Color> colors;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = (Offset.zero & size).deflate(0.6);
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, Radius.circular(radius)),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: colors,
        ).createShader(rect),
    );
  }

  @override
  bool shouldRepaint(_RimPainter old) =>
      old.radius != radius || old.colors != colors;
}

// ---------------------------------------------------------------------------
// Small pieces
// ---------------------------------------------------------------------------

/// "or", between two hairlines that fade out towards the edges.
class AuthDivider extends StatelessWidget {
  const AuthDivider({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = context.dsColors;
    Widget line(bool towardsStart) => Expanded(
      child: Container(
        height: 1,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: towardsStart
                ? AlignmentDirectional.centerStart
                : AlignmentDirectional.centerEnd,
            end: towardsStart
                ? AlignmentDirectional.centerEnd
                : AlignmentDirectional.centerStart,
            colors: [
              colors.primary.withValues(alpha: 0),
              colors.primary.withValues(alpha: 0.35),
            ],
          ),
        ),
      ),
    );

    return Row(
      children: [
        line(true),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: DsSpacing.md),
          child: Text(
            label,
            style: context.dsText.caption.copyWith(
              color: colors.onSurfaceVariant,
              letterSpacing: 1.2,
            ),
          ),
        ),
        line(false),
      ],
    );
  }
}

/// A secondary way in, drawn as a frosted row rather than a bare text button:
/// an icon in a blush medallion, a label, an optional caption and a chevron.
class AuthOptionTile extends StatelessWidget {
  const AuthOptionTile({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.caption,
  });

  final IconData icon;
  final String label;
  final String? caption;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.dsColors;
    final enabled = onTap != null;
    return AnimatedOpacity(
      duration: DsMotion.fast,
      opacity: enabled ? 1 : 0.5,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: DsRadius.borderXl,
          child: Ink(
            padding: const EdgeInsets.symmetric(
              horizontal: DsSpacing.md,
              vertical: DsSpacing.sm,
            ),
            decoration: BoxDecoration(
              borderRadius: DsRadius.borderXl,
              color: colors.surface.withValues(alpha: 0.55),
              border: Border.all(color: colors.border.withValues(alpha: 0.7)),
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        colors.primaryContainer,
                        colors.secondaryContainer,
                      ],
                    ),
                  ),
                  child: Icon(
                    icon,
                    size: DsSizes.iconSm,
                    color: colors.primary,
                  ),
                ),
                DsGaps.hSm,
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(label, style: context.dsText.bodyStrong),
                      if (caption != null)
                        Text(caption!, style: context.dsText.caption),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  color: colors.onSurfaceVariant,
                  size: DsSizes.iconSm,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A small heading inside a panel: a rose tick and a label.
class AuthSectionLabel extends StatelessWidget {
  const AuthSectionLabel(this.label, {super.key, this.icon});

  final String label;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final colors = context.dsColors;
    return Row(
      children: [
        if (icon != null)
          Icon(icon, size: DsSizes.iconXs, color: colors.primary)
        else
          Container(
            width: 4,
            height: 16,
            decoration: BoxDecoration(
              borderRadius: DsRadius.borderPill,
              gradient: context.primaryGradient,
            ),
          ),
        DsGaps.hXs,
        Expanded(
          child: Text(
            label,
            style: context.dsText.labelStrong.copyWith(color: colors.onSurface),
          ),
        ),
      ],
    );
  }
}

/// A one-line reassurance at the foot of the page.
class AuthTrustNote extends StatelessWidget {
  const AuthTrustNote({super.key, required this.text, this.icon});

  final String text;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final colors = context.dsColors;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          icon ?? Icons.verified_user_rounded,
          size: DsSizes.iconXs,
          color: colors.success,
        ),
        DsGaps.hXs,
        Flexible(
          child: Text(
            text,
            textAlign: TextAlign.center,
            style: context.dsText.caption,
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Code field
// ---------------------------------------------------------------------------

/// A one-time code as a row of cells.
///
/// One real, invisible `TextField` sits over the cells and does all the work —
/// focus, the number pad, paste, and the `oneTimeCode` autofill that lets the
/// phone offer the code straight from the notification. The cells only draw
/// what it holds. The row is always left-to-right, because a code is read in
/// the order it was sent even inside an Arabic layout.
class AuthCodeField extends StatefulWidget {
  const AuthCodeField({
    super.key,
    required this.controller,
    this.length = 6,
    this.onCompleted,
    this.autofocus = true,
    this.enabled = true,
    this.hasError = false,
    this.semanticsLabel,
  });

  final TextEditingController controller;
  final int length;

  /// Called once the last digit is in.
  final ValueChanged<String>? onCompleted;
  final bool autofocus;
  final bool enabled;
  final bool hasError;
  final String? semanticsLabel;

  @override
  State<AuthCodeField> createState() => _AuthCodeFieldState();
}

class _AuthCodeFieldState extends State<AuthCodeField> {
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_changed);
    _focus.addListener(_changed);
  }

  @override
  void didUpdateWidget(covariant AuthCodeField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_changed);
      widget.controller.addListener(_changed);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_changed);
    _focus.dispose();
    super.dispose();
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final code = widget.controller.text;
    final focused = _focus.hasFocus;
    final active = math.min(code.length, widget.length - 1);

    return Directionality(
      textDirection: TextDirection.ltr,
      child: Stack(
        children: [
          ExcludeSemantics(
            child: Row(
              children: [
                for (var i = 0; i < widget.length; i++)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: DsSpacing.xxs,
                      ),
                      child: _CodeCell(
                        digit: i < code.length ? code[i] : null,
                        active: focused && widget.enabled && i == active,
                        hasError: widget.hasError,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Positioned.fill(
            child: Opacity(
              opacity: 0,
              child: TextField(
                controller: widget.controller,
                focusNode: _focus,
                autofocus: widget.autofocus,
                enabled: widget.enabled,
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.done,
                autofillHints: const [AutofillHints.oneTimeCode],
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(widget.length),
                ],
                showCursor: false,
                style: const TextStyle(color: Colors.transparent),
                decoration: InputDecoration.collapsed(
                  hintText: widget.semanticsLabel,
                ),
                onChanged: (value) {
                  if (value.length == widget.length) {
                    widget.onCompleted?.call(value);
                  }
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CodeCell extends StatelessWidget {
  const _CodeCell({
    required this.digit,
    required this.active,
    required this.hasError,
  });

  final String? digit;
  final bool active;
  final bool hasError;

  @override
  Widget build(BuildContext context) {
    final colors = context.dsColors;
    final filled = digit != null;
    final edge = hasError
        ? colors.error
        : active
        ? colors.primary
        : filled
        ? colors.primary.withValues(alpha: 0.45)
        : colors.border;

    return AspectRatio(
      aspectRatio: 0.8,
      child: AnimatedContainer(
        duration: DsMotion.normal,
        curve: DsMotion.gentle,
        decoration: BoxDecoration(
          borderRadius: DsRadius.borderLg,
          color: filled
              ? colors.primaryContainer.withValues(alpha: 0.55)
              : colors.surface.withValues(alpha: 0.85),
          border: Border.all(color: edge, width: active ? 2 : 1.2),
          boxShadow: active
              ? context.glowShadow(
                  hasError ? colors.error : colors.primary,
                  blur: 16,
                  alpha: 0.3,
                )
              : null,
        ),
        alignment: Alignment.center,
        child: AnimatedSwitcher(
          duration: DsMotion.normal,
          switchInCurve: DsMotion.softSpring,
          transitionBuilder: (child, animation) => ScaleTransition(
            scale: Tween(begin: 0.4, end: 1.0).animate(animation),
            child: FadeTransition(opacity: animation, child: child),
          ),
          child: filled
              ? Text(
                  digit!,
                  key: ValueKey(digit),
                  style: context.dsText.screenTitle.uiFamily.bold.copyWith(
                    color: hasError ? colors.error : colors.onSurface,
                    height: 1,
                  ),
                )
              : active
              ? const _Caret(key: ValueKey('caret'))
              : const SizedBox.shrink(key: ValueKey('empty')),
        ),
      ),
    );
  }
}

class _Caret extends StatefulWidget {
  const _Caret({super.key});

  @override
  State<_Caret> createState() => _CaretState();
}

class _CaretState extends State<_Caret> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1000),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final still = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (still) {
      _controller
        ..stop()
        ..value = 1;
    } else if (!_controller.isAnimating) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
      child: Container(
        width: 2,
        height: 22,
        decoration: BoxDecoration(
          borderRadius: DsRadius.borderPill,
          gradient: context.primaryGradient,
        ),
      ),
    );
  }
}
