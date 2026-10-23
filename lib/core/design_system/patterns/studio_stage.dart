import 'package:flutter/material.dart';

import 'package:reem/core/design_system/design_system.dart';

/// The publishing register: **a small studio**.
///
/// Making a post, a reel or a story should feel like picking up a camera, not
/// filling in a form:
///
/// * [StudioModeSwitch] — the formats as a camera's mode dial: the chosen one
///   centred, lit and named, the others quiet either side.
/// * [ViewfinderFrame] — the media sits inside a viewfinder, with corner
///   brackets and a recording dot, shaped to the format it will be published
///   in.
/// * [StudioSegment] — a two-way choice with a lit slider behind the chosen
///   side.

/// One mode on the dial.
@immutable
class StudioMode {
  const StudioMode({
    required this.icon,
    required this.label,
    required this.gradient,
  });

  final IconData icon;
  final String label;

  /// The light this mode is lit in, and the viewfinder with it.
  final Gradient gradient;
}

/// Formats as a camera's mode dial.
class StudioModeSwitch extends StatelessWidget {
  const StudioModeSwitch({
    super.key,
    required this.modes,
    required this.selected,
    required this.onSelect,
  });

  final List<StudioMode> modes;
  final int selected;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final colors = context.dsColors;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          minWidth: MediaQuery.sizeOf(context).width - DsSpacing.gutter * 2,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var i = 0; i < modes.length; i++)
              Semantics(
                button: true,
                selected: i == selected,
                label: modes[i].label,
                excludeSemantics: true,
                child: GestureDetector(
                  onTap: () => onSelect(i),
                  behavior: HitTestBehavior.opaque,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: DsSpacing.xs,
                    ),
                    child: AnimatedContainer(
                      duration: DsMotion.moderate,
                      curve: DsMotion.gentle,
                      padding: EdgeInsets.symmetric(
                        horizontal: i == selected ? DsSpacing.lg : DsSpacing.md,
                        vertical: DsSpacing.sm,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: DsRadius.borderPill,
                        gradient: i == selected ? modes[i].gradient : null,
                        color: i == selected
                            ? null
                            : colors.surface.withValues(alpha: 0.7),
                        border: i == selected
                            ? null
                            : Border.all(
                                color: colors.border.withValues(alpha: 0.7),
                              ),
                        boxShadow: i == selected
                            ? context.glowShadow(
                                colors.primary,
                                blur: 18,
                                alpha: 0.3,
                              )
                            : null,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            modes[i].icon,
                            size: i == selected
                                ? DsSizes.iconMd
                                : DsSizes.iconSm,
                            color: i == selected
                                ? DsColors.onMedia
                                : colors.onSurfaceVariant,
                          ),
                          DsGaps.hXs,
                          Text(
                            modes[i].label,
                            style:
                                (i == selected
                                        ? context.dsText.labelLarge.bold
                                        : context.dsText.labelMedium)
                                    .copyWith(
                                      color: i == selected
                                          ? DsColors.onMedia
                                          : colors.onSurfaceVariant,
                                    ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// The media, inside a viewfinder.
///
/// Corner brackets in the mode's light, a recording dot with the format's
/// name, and the frame's shape named — a portrait post and a tall reel are
/// different pictures, and she should know which she is composing.
class ViewfinderFrame extends StatelessWidget {
  const ViewfinderFrame({
    super.key,
    required this.child,
    required this.label,
    required this.gradient,
    this.shape,
  });

  final Widget child;

  /// The format's name, beside the recording dot.
  final String label;

  /// The frame's shape, said at the other corner: «4:5», «9:16».
  final String? shape;
  final Gradient gradient;

  @override
  Widget build(BuildContext context) {
    final colors = context.dsColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return CustomPaint(
      foregroundPainter: _BracketsPainter(gradient: gradient),
      child: Container(
        padding: const EdgeInsets.fromLTRB(
          DsSpacing.lg,
          DsSpacing.md,
          DsSpacing.lg,
          DsSpacing.lg,
        ),
        decoration: BoxDecoration(
          borderRadius: DsRadius.borderXxl,
          color: (isDark ? colors.surfaceElevated : colors.surface).withValues(
            alpha: 0.88,
          ),
          boxShadow: context.shadowSoft,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const _RecDot(),
                DsGaps.hXs,
                Text(label, style: context.dsText.captionStrong),
                const Spacer(),
                if (shape != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: DsSpacing.xs,
                      vertical: DsSpacing.xxxs,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: DsRadius.borderSm,
                      border: Border.all(color: colors.outline),
                    ),
                    child: Text(
                      shape!,
                      textDirection: TextDirection.ltr,
                      style: context.dsText.caption.tabular,
                    ),
                  ),
              ],
            ),
            DsGaps.vMd,
            child,
          ],
        ),
      ),
    );
  }
}

/// A recording light that breathes; still under "reduce motion".
class _RecDot extends StatefulWidget {
  const _RecDot();

  @override
  State<_RecDot> createState() => _RecDotState();
}

class _RecDotState extends State<_RecDot> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
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
    final colors = context.dsColors;
    return FadeTransition(
      opacity: Tween(begin: 0.35, end: 1.0).animate(_controller),
      child: Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: colors.favorite,
          boxShadow: context.glowShadow(colors.favorite, blur: 6, alpha: 0.6),
        ),
      ),
    );
  }
}

class _BracketsPainter extends CustomPainter {
  const _BracketsPainter({required this.gradient});

  final Gradient gradient;

  @override
  void paint(Canvas canvas, Size size) {
    const arm = 26.0;
    const inset = 6.0;
    const r = 14.0;
    final rect = Offset.zero & size;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..shader = gradient.createShader(rect);

    final l = inset;
    final t = inset;
    final rt = size.width - inset;
    final b = size.height - inset;

    // Each corner: an arm, a rounded turn, an arm.
    canvas
      ..drawPath(
        Path()
          ..moveTo(l, t + arm)
          ..lineTo(l, t + r)
          ..quadraticBezierTo(l, t, l + r, t)
          ..lineTo(l + arm, t),
        paint,
      )
      ..drawPath(
        Path()
          ..moveTo(rt - arm, t)
          ..lineTo(rt - r, t)
          ..quadraticBezierTo(rt, t, rt, t + r)
          ..lineTo(rt, t + arm),
        paint,
      )
      ..drawPath(
        Path()
          ..moveTo(rt, b - arm)
          ..lineTo(rt, b - r)
          ..quadraticBezierTo(rt, b, rt - r, b)
          ..lineTo(rt - arm, b),
        paint,
      )
      ..drawPath(
        Path()
          ..moveTo(l + arm, b)
          ..lineTo(l + r, b)
          ..quadraticBezierTo(l, b, l, b - r)
          ..lineTo(l, b - arm),
        paint,
      );
  }

  @override
  bool shouldRepaint(_BracketsPainter old) => old.gradient != gradient;
}

/// One side of a [StudioSegment].
@immutable
class StudioSegmentOption {
  const StudioSegmentOption({
    required this.icon,
    required this.label,
    this.hint,
  });

  final IconData icon;
  final String label;
  final String? hint;
}

/// A choice between two, with a lit slider that glides to the chosen side.
class StudioSegment extends StatelessWidget {
  const StudioSegment({
    super.key,
    required this.options,
    required this.selected,
    required this.onSelect,
  }) : assert(options.length == 2);

  final List<StudioSegmentOption> options;
  final int selected;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final colors = context.dsColors;
    final rtl = Directionality.of(context) == TextDirection.rtl;
    // The slider's x runs left to right; the first option sits at the start.
    final x = (selected == 0) != rtl ? -1.0 : 1.0;

    return Container(
      padding: const EdgeInsets.all(DsSpacing.xxs),
      decoration: BoxDecoration(
        borderRadius: DsRadius.borderXl,
        color: colors.surfaceVariant,
        border: Border.all(color: colors.border.withValues(alpha: 0.7)),
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: AnimatedAlign(
              duration: DsMotion.moderate,
              curve: DsMotion.gentle,
              alignment: Alignment(x, 0),
              child: FractionallySizedBox(
                widthFactor: 0.5,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: DsRadius.borderLg,
                    gradient: context.primaryGradient,
                    boxShadow: context.glowShadow(
                      colors.primary,
                      blur: 12,
                      alpha: 0.25,
                    ),
                  ),
                ),
              ),
            ),
          ),
          Row(
            children: [
              for (var i = 0; i < 2; i++)
                Expanded(
                  child: Semantics(
                    button: true,
                    selected: i == selected,
                    label: options[i].label,
                    excludeSemantics: true,
                    child: GestureDetector(
                      onTap: () => onSelect(i),
                      behavior: HitTestBehavior.opaque,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: DsSpacing.sm,
                          horizontal: DsSpacing.xs,
                        ),
                        child: Column(
                          children: [
                            Icon(
                              options[i].icon,
                              size: DsSizes.iconSm,
                              color: i == selected
                                  ? DsColors.onMedia
                                  : colors.onSurfaceVariant,
                            ),
                            DsGaps.vXxs,
                            Text(
                              options[i].label,
                              textAlign: TextAlign.center,
                              style: context.dsText.labelStrong.copyWith(
                                color: i == selected
                                    ? DsColors.onMedia
                                    : colors.onSurface,
                              ),
                            ),
                            if (options[i].hint != null)
                              Text(
                                options[i].hint!,
                                textAlign: TextAlign.center,
                                maxLines: 2,
                                style: context.dsText.caption.copyWith(
                                  color: i == selected
                                      ? DsColors.onMediaMuted
                                      : colors.onSurfaceVariant,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
