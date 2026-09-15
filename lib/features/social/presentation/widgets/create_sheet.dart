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
                      onTap: () => go(
                        '${RoutePaths.compose}?format=${format.wire}',
                      ),
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
    final c = context.dsColors;
    final l10n = context.l10n;
    final (icon, label, hint) = switch (format) {
      CreateFormat.post => (
        Icons.add_photo_alternate_outlined,
        l10n.createPost,
        l10n.createPostHint,
      ),
      CreateFormat.reel => (
        Icons.movie_creation_outlined,
        l10n.createReel,
        l10n.createReelHint,
      ),
      CreateFormat.story => (
        Icons.amp_stories_outlined,
        l10n.createStory,
        l10n.createStoryHint,
      ),
    };

    return Semantics(
      button: true,
      label: label,
      child: Material(
        color: c.primaryContainer.withValues(alpha: 0.55),
        borderRadius: DsRadius.borderLg,
        child: InkWell(
          onTap: onTap,
          borderRadius: DsRadius.borderLg,
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: DsSpacing.xs,
              vertical: compact ? DsSpacing.sm : DsSpacing.md,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: compact ? 40 : 48,
                  height: compact ? 40 : 48,
                  decoration: BoxDecoration(
                    gradient: context.primaryGradient,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    icon,
                    color: c.onPrimary,
                    size: compact ? DsSizes.iconSm : DsSizes.iconMd,
                  ),
                ),
                DsGaps.vXs,
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.dsText.tileTitle.bold.tint(c.onSurface),
                ),
                if (!compact) ...[
                  DsGaps.vXxxs,
                  Text(
                    hint,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: context.dsText.caption.tint(c.onSurfaceVariant),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
