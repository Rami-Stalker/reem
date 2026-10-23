import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:reem/core/design_system/design_system.dart';
import 'package:reem/core/localization/l10n_extension.dart';
import 'package:reem/core/router/route_paths.dart';

/// The three shapes she can publish.
enum CreateFormat {
  post('post'),
  reel('reel'),
  story('story');

  const CreateFormat(this.wire);

  /// The value `/compose?format=` carries.
  final String wire;
}

/// Opens the composer already set to [format].
void openComposer(BuildContext context, CreateFormat format) {
  unawaited(context.push('${RoutePaths.compose}?format=${format.wire}'));
}

/// «شو حابة تنشري؟» — a post, a reel or a story.
///
/// A shopper could publish all three from the day the content platform
/// shipped, and could not find the door: the composer was a quick action in
/// the role manifest, and nothing on a customer's screen ever rendered the
/// quick actions. This sheet is that door, opened from the home bar and from
/// her own page, with the community and the reels a tap further on — they had
/// the same problem.
Future<void> showCreateSheet(BuildContext context) {
  return DsBottomSheet.show<void>(
    context,
    builder: (sheetContext) {
      final l10n = sheetContext.l10n;
      final router = GoRouter.of(context);

      void go(String path) {
        Navigator.of(sheetContext).pop();
        unawaited(router.push(path));
      }

      return DsSheetScaffold(
        title: l10n.createSheetTitle,
        scrollable: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                for (final format in CreateFormat.values) ...[
                  if (format != CreateFormat.post) DsGaps.hSm,
                  Expanded(
                    child: CreateFormatTile(
                      format: format,
                      onTap: () =>
                          go('${RoutePaths.compose}?format=${format.wire}'),
                    ),
                  ),
                ],
              ],
            ),
            DsGaps.vLg,
            Row(
              children: [
                Expanded(
                  child: DsButton(
                    label: l10n.createBrowseCommunity,
                    icon: Icons.auto_awesome_motion_rounded,
                    variant: DsButtonVariant.tonal,
                    size: DsButtonSize.sm,
                    onPressed: () => go(RoutePaths.socialFeed),
                  ),
                ),
                DsGaps.hSm,
                Expanded(
                  child: DsButton(
                    label: l10n.createBrowseReels,
                    icon: Icons.movie_creation_outlined,
                    variant: DsButtonVariant.tonal,
                    size: DsButtonSize.sm,
                    onPressed: () => go(RoutePaths.reels),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    },
  );
}

/// One of the three shapes, as a tile: glyph, name, and what it is.
class CreateFormatTile extends StatelessWidget {
  const CreateFormatTile({
    super.key,
    required this.format,
    required this.onTap,
    this.compact = false,
  });

  final CreateFormat format;
  final VoidCallback onTap;

  /// Drops the hint line, for a row inside a card.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    // Each shape in its own light — the same three the composer's mode dial
    // and viewfinder are lit in, so the choice carries through.
    final (icon, label, hint, light, ink) = switch (format) {
      CreateFormat.post => (
        Icons.photo_camera_rounded,
        l10n.createPost,
        l10n.createPostHint,
        context.primaryGradient,
        DsColors.onMedia,
      ),
      CreateFormat.reel => (
        Icons.movie_creation_rounded,
        l10n.createReel,
        l10n.createReelHint,
        DsGradients.rewards as Gradient,
        DsColors.onMedia,
      ),
      CreateFormat.story => (
        Icons.auto_stories_rounded,
        l10n.createStory,
        l10n.createStoryHint,
        DsGradients.gold as Gradient,
        DsColors.onGold,
      ),
    };

    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        // Grows with its words rather than a fixed ratio: a larger text size,
        // or a narrow phone, would otherwise push the hint out of the arch.
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: compact ? 96 : 150),
          child: CustomPaint(
            painter: _ArchTilePainter(
              gradient: light,
              glow: context.dsColors.shadow,
            ),
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                DsSpacing.xs,
                compact ? DsSpacing.lg : DsSpacing.xxl,
                DsSpacing.xs,
                DsSpacing.sm,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: compact ? 36 : 44,
                    height: compact ? 36 : 44,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: DsColors.mediaPlate,
                    ),
                    child: Icon(
                      icon,
                      color: ink,
                      size: compact ? DsSizes.iconSm : DsSizes.iconMd,
                    ),
                  ),
                  DsGaps.vXs,
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.dsText.tileTitle.bold.tint(ink),
                  ),
                  if (!compact) ...[
                    DsGaps.vXxxs,
                    Text(
                      hint,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: context.dsText.caption.tint(
                        ink.withValues(alpha: 0.82),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The tile's arch, filled with its light, with a pearl line inside and a
/// soft shadow under.
class _ArchTilePainter extends CustomPainter {
  const _ArchTilePainter({required this.gradient, required this.glow});

  final Gradient gradient;
  final Color glow;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = (Offset.zero & size).deflate(1);
    final path = dsArchPath(rect);
    canvas.drawPath(
      path.shift(const Offset(0, 6)),
      Paint()
        ..color = glow
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12),
    );
    canvas.drawPath(path, Paint()..shader = gradient.createShader(rect));
    canvas.drawPath(
      dsArchPath(rect.deflate(5)),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = DsColors.onMediaFaint,
    );
  }

  @override
  bool shouldRepaint(_ArchTilePainter old) =>
      old.gradient != gradient || old.glow != glow;
}
