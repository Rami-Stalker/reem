import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import 'package:ohara/core/design_system/design_system.dart';
import 'package:ohara/core/media/media_decode.dart';
import 'package:ohara/core/media/media_variants.dart';

/// The messaging register: **letters between a woman and her boutiques**.
///
/// * [ArchAvatar] — a face or a shop mark cut to Ohara's arch, with a living
///   dot when they are here.
/// * [WaxSeal] — an unread count pressed into a scalloped seal.
/// * [SilkBubbleBorder] — a message bubble whose last line curls into a tail
///   on the sender's side, like the end of a ribbon.
/// * [SealDivider] — the day, in a small seal between two fading threads.
/// * [WaveDots] — three dots that rise and fall in turn.

// ---------------------------------------------------------------------------
// Avatar
// ---------------------------------------------------------------------------

/// A face, or a boutique's mark, in the arch.
class ArchAvatar extends StatelessWidget {
  const ArchAvatar({
    super.key,
    required this.name,
    this.imageUrl,
    this.width = 48,
    this.isOnline = false,
    this.lit = false,
    this.onTap,
  });

  final String name;
  final String? imageUrl;
  final double width;
  final bool isOnline;

  /// A rose thread round the arch — for somebody with something unread.
  final bool lit;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.dsColors;
    final height = width * 1.22;
    final ring = lit ? 2.5 : 0.0;

    Widget face = SizedBox(
      width: width,
      height: height,
      child: CustomPaint(
        painter: lit
            ? _ArchRingPainter(gradient: context.storyRingGradient)
            : null,
        child: Padding(
          padding: EdgeInsets.all(ring == 0 ? 0 : ring + 1.5),
          child: ClipPath(
            clipper: const DsArchClipper(),
            child: _Face(name: name, imageUrl: imageUrl, width: width),
          ),
        ),
      ),
    );

    if (isOnline) {
      face = Stack(
        clipBehavior: Clip.none,
        children: [
          face,
          PositionedDirectional(
            bottom: -2,
            end: -2,
            child: Container(
              width: width * 0.28,
              height: width * 0.28,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: colors.online,
                border: Border.all(color: colors.surface, width: 2),
              ),
            ),
          ),
        ],
      );
    }

    final labelled = Semantics(
      label: name,
      image: imageUrl != null && imageUrl!.isNotEmpty,
      button: onTap != null,
      excludeSemantics: true,
      child: face,
    );
    if (onTap == null) return labelled;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: labelled,
    );
  }
}

class _Face extends StatelessWidget {
  const _Face({
    required this.name,
    required this.imageUrl,
    required this.width,
  });

  final String name;
  final String? imageUrl;
  final double width;

  @override
  Widget build(BuildContext context) {
    final url = imageUrl;
    if (url != null && url.isNotEmpty) {
      return CachedNetworkImage(
        imageUrl: MediaVariants.thumb(url),
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        memCacheWidth: MediaDecode.widthFor(context, width),
        placeholder: (_, _) => ColoredBox(color: context.dsColors.shimmerBase),
        errorWidget: (_, _, _) => _initials(context),
      );
    }
    return _initials(context);
  }

  Widget _initials(BuildContext context) {
    final words = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList();
    // One letter for an Arabic name: two Arabic initials join into a word.
    final arabic =
        words.isNotEmpty &&
        RegExp(r'[؀-ۿ]').hasMatch(words.first.characters.first);
    final letters = words
        .take(arabic ? 1 : 2)
        .map((part) => part.characters.first)
        .join();
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [DsColors.primary300, DsColors.primary600, DsColors.mauve600],
        ),
      ),
      child: Align(
        alignment: const Alignment(0, 0.3),
        child: Text(
          letters,
          style: TextStyle(
            fontFamily: DsTypography.fontFamilyDisplay,
            fontFamilyFallback: DsTypography.displayFallback,
            fontSize: width * 0.38,
            fontWeight: DsTypography.bold,
            color: DsColors.onMedia,
            height: 1,
          ),
        ),
      ),
    );
  }
}

class _ArchRingPainter extends CustomPainter {
  const _ArchRingPainter({required this.gradient});

  final Gradient gradient;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawPath(
      dsArchPath(rect.deflate(1.25)),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..shader = gradient.createShader(rect),
    );
  }

  @override
  bool shouldRepaint(_ArchRingPainter old) => old.gradient != gradient;
}

// ---------------------------------------------------------------------------
// Wax seal
// ---------------------------------------------------------------------------

/// A count pressed into a wax seal: a scalloped rose disc with a pressed ring.
class WaxSeal extends StatelessWidget {
  const WaxSeal({super.key, required this.count, this.size = 30});

  final int count;
  final double size;

  @override
  Widget build(BuildContext context) {
    if (count <= 0) return const SizedBox.shrink();
    final label = count > 99 ? '99+' : '$count';
    return SizedBox.square(
      dimension: size,
      child: CustomPaint(
        painter: _SealPainter(
          gradient: context.primaryGradient,
          shadow: context.dsColors.primary.withValues(alpha: 0.35),
        ),
        child: Center(
          child: FittedBox(
            child: Padding(
              padding: const EdgeInsets.all(DsSpacing.xxs),
              child: Text(
                label,
                style: context.dsText.captionStrong.tabular.copyWith(
                  color: DsColors.onMedia,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SealPainter extends CustomPainter {
  const _SealPainter({required this.gradient, required this.shadow});

  final Gradient gradient;
  final Color shadow;

  @override
  void paint(Canvas canvas, Size size) {
    final centre = size.center(Offset.zero);
    final outer = size.shortestSide / 2;
    const lobes = 12;
    final path = Path();
    for (var i = 0; i <= lobes * 8; i++) {
      final angle = i / (lobes * 8) * math.pi * 2;
      // A gentle scallop: the radius swells a little at each lobe.
      final r = outer * (0.9 + 0.1 * math.cos(angle * lobes).abs());
      final point = centre + Offset(math.cos(angle), math.sin(angle)) * r;
      if (i == 0) {
        path.moveTo(point.dx, point.dy);
      } else {
        path.lineTo(point.dx, point.dy);
      }
    }
    path.close();

    canvas.drawPath(
      path.shift(const Offset(0, 2)),
      Paint()
        ..color = shadow
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );
    canvas.drawPath(
      path,
      Paint()..shader = gradient.createShader(Offset.zero & size),
    );
    // The pressed ring.
    canvas.drawCircle(
      centre,
      outer * 0.68,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = DsColors.onMediaFaint,
    );
  }

  @override
  bool shouldRepaint(_SealPainter old) =>
      old.gradient != gradient || old.shadow != shadow;
}

// ---------------------------------------------------------------------------
// Bubble
// ---------------------------------------------------------------------------

/// A message bubble. Rounded all round, except that the last bubble of a run
/// curls into a small tail on the sender's side at its foot — the end of a
/// ribbon — so a run of messages reads as one voice.
class SilkBubbleBorder extends ShapeBorder {
  const SilkBubbleBorder({
    required this.mine,
    this.tail = true,
    this.radius = DsRadius.xxl,
    this.side = BorderSide.none,
  });

  /// Her own message: the tail on the trailing side of the reading direction.
  final bool mine;
  final bool tail;
  final double radius;
  final BorderSide side;

  static const double tailWidth = 7;

  @override
  EdgeInsetsGeometry get dimensions => EdgeInsetsDirectional.only(
    start: !mine && tail ? tailWidth : 0,
    end: mine && tail ? tailWidth : 0,
  );

  Path _path(Rect rect, TextDirection? direction) {
    final rtl = direction == TextDirection.rtl;
    // The physical side the tail is on.
    final tailRight = mine != rtl;
    final r = Radius.circular(radius);
    const nib = Radius.circular(DsRadius.xs);

    if (!tail) {
      return Path()..addRRect(RRect.fromRectAndRadius(rect, r));
    }

    final body = tailRight
        ? Rect.fromLTRB(
            rect.left,
            rect.top,
            rect.right - tailWidth,
            rect.bottom,
          )
        : Rect.fromLTRB(
            rect.left + tailWidth,
            rect.top,
            rect.right,
            rect.bottom,
          );
    final bubble = Path()
      ..addRRect(
        RRect.fromRectAndCorners(
          body,
          topLeft: r,
          topRight: r,
          bottomLeft: tailRight ? r : nib,
          bottomRight: tailRight ? nib : r,
        ),
      );

    final b = body.bottom;
    final Path curl;
    if (tailRight) {
      final x = body.right;
      curl = Path()
        ..moveTo(x, b - 16)
        ..quadraticBezierTo(x, b - 2, rect.right, b)
        ..quadraticBezierTo(x - 6, b + 0.5, x - 14, b - 1)
        ..close();
    } else {
      final x = body.left;
      curl = Path()
        ..moveTo(x, b - 16)
        ..quadraticBezierTo(x, b - 2, rect.left, b)
        ..quadraticBezierTo(x + 6, b + 0.5, x + 14, b - 1)
        ..close();
    }
    return Path.combine(PathOperation.union, bubble, curl);
  }

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) =>
      _path(rect.deflate(side.width), textDirection);

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) =>
      _path(rect, textDirection);

  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {
    if (side.style == BorderStyle.none || side.width == 0) return;
    canvas.drawPath(
      _path(rect.deflate(side.width / 2), textDirection),
      side.toPaint(),
    );
  }

  @override
  ShapeBorder scale(double t) => SilkBubbleBorder(
    mine: mine,
    tail: tail,
    radius: radius * t,
    side: side.scale(t),
  );
}

// ---------------------------------------------------------------------------
// Divider
// ---------------------------------------------------------------------------

/// «اليوم» / «أمس» in a small seal between two threads that fade outwards.
class SealDivider extends StatelessWidget {
  const SealDivider({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = context.dsColors;
    Widget thread(bool towardsStart) => Expanded(
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
        thread(true),
        DsGaps.hXs,
        DsSparkle(size: 8, color: colors.accent),
        DsGaps.hXs,
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: DsSpacing.md,
            vertical: DsSpacing.xxs,
          ),
          decoration: BoxDecoration(
            borderRadius: DsRadius.borderPill,
            color: colors.surface.withValues(alpha: 0.85),
            border: Border.all(color: colors.border.withValues(alpha: 0.7)),
            boxShadow: context.shadowXs,
          ),
          child: Text(label, style: context.dsText.captionStrong),
        ),
        DsGaps.hXs,
        DsSparkle(size: 8, color: colors.accent),
        DsGaps.hXs,
        thread(false),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Wave dots
// ---------------------------------------------------------------------------

/// Three dots that rise and fall in turn, like somebody thinking aloud.
/// Still under "reduce motion".
class WaveDots extends StatefulWidget {
  const WaveDots({super.key, this.color, this.size = 7});

  final Color? color;
  final double size;

  @override
  State<WaveDots> createState() => _WaveDotsState();
}

class _WaveDotsState extends State<WaveDots>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final still = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (still) {
      _controller.stop();
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
    final colour = widget.color ?? context.dsColors.primary;
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < 3; i++)
            Transform.translate(
              offset: Offset(
                0,
                -widget.size *
                    0.6 *
                    math.max(
                      0,
                      math.sin((_controller.value - i * 0.18) * math.pi * 2),
                    ),
              ),
              child: Container(
                margin: EdgeInsets.symmetric(horizontal: widget.size * 0.3),
                width: widget.size,
                height: widget.size,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: colour.withValues(
                    alpha:
                        0.45 +
                        0.55 *
                            math.max(
                              0,
                              math.sin(
                                (_controller.value - i * 0.18) * math.pi * 2,
                              ),
                            ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
