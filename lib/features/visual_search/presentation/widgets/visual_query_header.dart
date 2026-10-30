import 'package:flutter/material.dart';
import 'package:ohara/core/design_system/design_system.dart';
import 'package:ohara/core/localization/l10n_extension.dart';
import 'package:ohara/core/media/authorized_media_image.dart';
import 'package:ohara/features/visual_search/domain/entities/visual_search_session.dart';
import 'package:ohara/features/visual_search/domain/entities/visual_understanding.dart';

/// Her photograph, with what the server read off it.
///
/// Two decisions here carry the honesty of the whole screen.
///
/// **The image can be absent, and that is not an error.** Once the retention
/// clock has run the photograph is deleted while the search lives on, so
/// [VisualSearchSession.queryImageUrl] goes null and the header falls back to
/// the chips. A broken-image icon would suggest something went wrong; what
/// actually happened is the platform keeping a promise.
///
/// **A measured attribute and an inferred one do not look the same.** Colours
/// were read off the pixels; a category was inferred from which listings
/// matched. The second kind is drawn quieter and prefixed, because a chip that
/// says "فساتين" as confidently as one that says "أسود" is claiming a
/// certainty the pipeline does not have.
class VisualQueryHeader extends StatelessWidget {
  const VisualQueryHeader({
    super.key,
    required this.session,
    this.onRetake,
    this.onForget,
  });

  final VisualSearchSession session;
  final VoidCallback? onRetake;
  final VoidCallback? onForget;

  @override
  Widget build(BuildContext context) {
    final colors = context.dsColors;
    final understanding = session.understanding;

    return Container(
      padding: const EdgeInsets.all(DsSpacing.md),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: const BorderRadius.vertical(
          bottom: Radius.circular(DsRadius.xxl),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Thumbnail(session: session),
              const SizedBox(width: DsSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.l10n.visualWhatISaw,
                      style: context.dsText.tileTitle,
                    ),
                    const SizedBox(height: DsSpacing.xs),
                    if (understanding.isEmpty)
                      Text(
                        context.l10n.visualCouldntDescribe,
                        style: context.dsText.cardSubtitle.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                      )
                    else
                      _ChipWrap(understanding: understanding),
                    if (session.refinements.isNotEmpty) ...[
                      const SizedBox(height: DsSpacing.xs),
                      _Refinements(session: session),
                    ],
                  ],
                ),
              ),
            ],
          ),
          if (onRetake != null || onForget != null) ...[
            const SizedBox(height: DsSpacing.sm),
            Row(
              children: [
                if (onRetake != null)
                  TextButton.icon(
                    onPressed: onRetake,
                    icon: const Icon(Icons.image_search_rounded, size: 18),
                    label: Text(context.l10n.visualAnotherPhoto),
                  ),
                const Spacer(),
                if (onForget != null)
                  TextButton.icon(
                    onPressed: onForget,
                    icon: Icon(
                      Icons.delete_outline_rounded,
                      size: 18,
                      color: colors.onSurfaceVariant,
                    ),
                    label: Text(
                      context.l10n.visualDeletePhotoAndSearch,
                      style: context.dsText.body.tint(colors.onSurfaceVariant),
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _Thumbnail extends StatelessWidget {
  const _Thumbnail({required this.session});

  final VisualSearchSession session;

  @override
  Widget build(BuildContext context) {
    final colors = context.dsColors;
    final url = session.queryImageUrl;

    return ClipRRect(
      borderRadius: BorderRadius.circular(DsRadius.image),
      child: SizedBox(
        width: 96,
        height: 128,
        child: url == null
            ? _Expired(colors: colors)
            : Stack(
                fit: StackFit.expand,
                children: [
                  // Private media: fetched with her session, and readable by
                  // nobody else — not support, not an administrator.
                  AuthorizedMediaImage(url: url, variantWidth: 480),
                  if (session.isOutfit)
                    CustomPaint(
                      painter: _RegionPainter(
                        regions: session.regions,
                        colour: colors.onPrimary,
                      ),
                    ),
                ],
              ),
      ),
    );
  }
}

/// What the thumbnail shows once the photograph has been deleted.
class _Expired extends StatelessWidget {
  const _Expired({required this.colors});

  final DsColorScheme colors;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: colors.surfaceVariant,
      padding: const EdgeInsets.all(DsSpacing.xs),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.lock_clock_rounded,
            color: colors.onSurfaceVariant,
            size: 22,
          ),
          const SizedBox(height: DsSpacing.xxs),
          Text(
            context.l10n.visualPhotoDeleted,
            textAlign: TextAlign.center,
            style: context.dsText.caption.copyWith(
              color: colors.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

/// The boxes the server found, drawn over her photograph.
class _RegionPainter extends CustomPainter {
  const _RegionPainter({required this.regions, required this.colour});

  final List<VisualRegion> regions;
  final Color colour;

  @override
  void paint(Canvas canvas, Size size) {
    for (final region in regions) {
      if (region.box.isWholeFrame) continue;

      final rect = Rect.fromLTWH(
        region.box.x * size.width,
        region.box.y * size.height,
        region.box.w * size.width,
        region.box.h * size.height,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(4)),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5
          // A guessed band is drawn fainter than a detection. The alpha is the
          // confidence, so the drawing says the same thing the data does.
          ..color = colour.withValues(
            alpha: 0.35 + 0.55 * region.confidence.clamp(0, 1),
          ),
      );
    }
  }

  @override
  bool shouldRepaint(_RegionPainter oldDelegate) =>
      oldDelegate.regions != regions || oldDelegate.colour != colour;
}

class _ChipWrap extends StatelessWidget {
  const _ChipWrap({required this.understanding});

  final VisualUnderstanding understanding;

  @override
  Widget build(BuildContext context) {
    final colors = context.dsColors;

    return Wrap(
      spacing: DsSpacing.xs,
      runSpacing: DsSpacing.xs,
      children: [
        for (final chip in understanding.chips)
          DsChip(label: chip.label, selected: true),
        // Inferred, and drawn as inferred: the category came from which
        // listings matched, not from anything visible in the photograph.
        for (final category in understanding.categories.take(2))
          Tooltip(
            message: context.l10n.visualInferredFromMatches,
            child: DsChip(
              label: context.l10n.visualClosestCategory(category.label),
              icon: Icons.help_outline_rounded,
            ),
          ),
        if (understanding.confidence < 0.4)
          Text(
            context.l10n.visualLowConfidence,
            style: Theme.of(
              context,
            ).textTheme.labelSmall?.copyWith(color: colors.warningInk),
          ),
      ],
    );
  }
}

class _Refinements extends StatelessWidget {
  const _Refinements({required this.session});

  final VisualSearchSession session;

  @override
  Widget build(BuildContext context) {
    final colors = context.dsColors;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final refinement in session.refinements.take(3))
          Padding(
            padding: const EdgeInsets.only(top: DsSpacing.xxxs),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.subdirectory_arrow_left_rounded,
                  size: 14,
                  color: colors.onSurfaceVariant,
                ),
                const SizedBox(width: DsSpacing.xxs),
                Expanded(
                  child: Text(
                    refinement.text,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.dsText.caption.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
