import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:ohara/core/design_system/design_system.dart';

/// Ohara's face: a living orb rather than a static icon.
///
/// A slow halo turns around a rose-to-champagne core. While she is composing a
/// reply the halo quickens and the core breathes, so the wait reads as work
/// being done. Reduced-motion settings stop the movement, never the identity.
class OharaOrb extends StatefulWidget {
  const OharaOrb({super.key, this.size = 36, this.thinking = false});

  final double size;
  final bool thinking;

  @override
  State<OharaOrb> createState() => _OharaOrbState();
}

class _OharaOrbState extends State<OharaOrb> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: _period,
  );

  Duration get _period => widget.thinking
      ? const Duration(milliseconds: 1600)
      : const Duration(seconds: 7);

  @override
  void initState() {
    super.initState();
    if (!DsReducedMotion.isEnabled) _controller.repeat();
  }

  @override
  void didUpdateWidget(covariant OharaOrb oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.thinking != widget.thinking) {
      _controller.duration = _period;
      if (!DsReducedMotion.isEnabled) _controller.repeat();
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
    final boutique = context.boutique;
    final size = widget.size;
    final ring = math.max(2.0, size * 0.07);

    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          final t = _controller.value;
          final breath = widget.thinking ? 0.94 + 0.06 * math.sin(t * math.pi * 2) : 1.0;
          return Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: colors.primary.withValues(alpha: widget.thinking ? 0.45 : 0.28),
                  blurRadius: size * (widget.thinking ? 0.6 : 0.4),
                  spreadRadius: size * 0.02,
                ),
              ],
              gradient: SweepGradient(
                transform: GradientRotation(t * math.pi * 2),
                colors: [
                  colors.primary,
                  boutique.gold,
                  colors.primary.withValues(alpha: 0.35),
                  boutique.gold,
                  colors.primary,
                ],
              ),
            ),
            padding: EdgeInsets.all(ring),
            child: Transform.scale(scale: breath, child: child),
          );
        },
        child: DecoratedBox(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: boutique.signatureGradient,
            border: Border.all(
              color: colors.surface.withValues(alpha: 0.85),
              width: math.max(1.0, size * 0.03),
            ),
          ),
          child: Center(
            child: Icon(
              Icons.auto_awesome_rounded,
              color: DsColors.onMedia,
              size: size * 0.46,
            ),
          ),
        ),
      ),
    );
  }
}

/// The ground under every stylist screen: the boutique silk with two soft
/// light blooms, so the assistant feels like a lit room rather than a form.
class StylistBackdrop extends StatelessWidget {
  const StylistBackdrop({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = context.dsColors;
    final boutique = context.boutique;
    final width = MediaQuery.sizeOf(context).width;

    return Stack(
      children: [
        const Positioned.fill(child: CustomerBackdrop()),
        PositionedDirectional(
          top: -width * 0.35,
          end: -width * 0.3,
          child: _Bloom(size: width * 0.9, color: colors.primary.withValues(alpha: 0.16)),
        ),
        PositionedDirectional(
          bottom: -width * 0.25,
          start: -width * 0.35,
          child: _Bloom(size: width * 0.85, color: boutique.gold.withValues(alpha: 0.14)),
        ),
        Positioned.fill(child: child),
      ],
    );
  }
}

class _Bloom extends StatelessWidget {
  const _Bloom({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(colors: [color, color.withValues(alpha: 0)]),
        ),
      ),
    );
  }
}

/// A title painted with the brand signature, rose into champagne.
class StylistGradientText extends StatelessWidget {
  const StylistGradientText(this.text, {super.key, required this.style, this.textAlign});

  final String text;
  final TextStyle style;
  final TextAlign? textAlign;

  @override
  Widget build(BuildContext context) {
    final gradient = context.boutique.signatureGradient;
    return ShaderMask(
      blendMode: BlendMode.srcIn,
      shaderCallback: (bounds) => gradient.createShader(Offset.zero & bounds.size),
      child: Text(text, textAlign: textAlign, style: style.tint(DsColors.onMedia)),
    );
  }
}

/// A one-shot rise and fade for a new element — a fresh bubble, a card in a
/// rail. Delayed by [index] steps so a group arrives in sequence.
class StylistAppear extends StatelessWidget {
  const StylistAppear({super.key, required this.child, this.index = 0, this.offset = 14});

  final Widget child;
  final int index;
  final double offset;

  @override
  Widget build(BuildContext context) {
    final step = math.min(index, 6);
    final total = DsReducedMotion.duration(
      DsDurations.moderate + Duration(milliseconds: 70 * step),
    );
    final start = total == Duration.zero
        ? 0.0
        : (70 * step) / total.inMilliseconds.clamp(1, 1 << 30);

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: total,
      curve: Interval(start.clamp(0.0, 0.9), 1, curve: DsCurves.emphasized),
      builder: (context, value, child) => Opacity(
        opacity: value,
        child: Transform.translate(offset: Offset(0, offset * (1 - value)), child: child),
      ),
      child: child,
    );
  }
}

/// Frosted panel used across the stylist: translucent surface, hairline
/// border, soft shadow. Lighter than [GlassContainer] (no backdrop blur), so a
/// long transcript of them still scrolls smoothly.
class StylistPanel extends StatelessWidget {
  const StylistPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(DsSpacing.md),
    this.radius = DsRadius.card,
    this.highlighted = false,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;

  /// Draws the border in the brand gradient, for the one panel on a screen
  /// that should catch the eye.
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final colors = context.dsColors;
    final shape = BorderRadius.all(Radius.circular(radius));

    // One tree shape whether or not the border is lit: switching between a
    // padded and an unpadded child would rebuild whatever is inside — a text
    // field would lose its place the moment it gained focus.
    return AnimatedContainer(
      duration: DsDurations.normal,
      padding: EdgeInsets.all(highlighted ? DsSpacing.xxxs : DsSpacing.none),
      decoration: BoxDecoration(
        borderRadius: shape,
        gradient: highlighted ? context.boutique.signatureGradient : null,
        boxShadow: [
          BoxShadow(
            color: context.ds.isDark
                ? DsColors.black.withValues(alpha: 0.18)
                : colors.primary.withValues(alpha: 0.06),
            blurRadius: DsSpacing.xxl,
            spreadRadius: -DsSpacing.xxs,
            offset: const Offset(0, DsSpacing.xs),
          ),
        ],
      ),
      child: Container(
        padding: padding,
        decoration: BoxDecoration(
          // Opaque on purpose: a translucent panel lets its own shadow show
          // through as a pale band along the lower edge.
          color: colors.surfaceElevated,
          borderRadius: highlighted
              ? BorderRadius.all(Radius.circular(radius - DsSpacing.xxxs))
              : shape,
          border: Border.all(
            color: highlighted
                ? colors.surfaceElevated
                : colors.border.withValues(alpha: 0.7),
          ),
        ),
        child: child,
      ),
    );
  }
}
