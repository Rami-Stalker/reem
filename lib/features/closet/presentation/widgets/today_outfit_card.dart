import 'package:flutter/material.dart';
import 'package:reem/core/design_system/design_system.dart';
import 'package:reem/core/media/authorized_media_image.dart';
import 'package:reem/features/closet/domain/entities/closet_item.dart';
import 'package:reem/features/closet/domain/entities/closet_overview.dart';

/// One answer to "شو بقدر ألبس اليوم؟".
///
/// A composed outfit and a saved one render the same way. The distinction is a
/// single word in the footer, because from where she is standing there is no
/// difference worth a different card: both are her own clothes, arranged.
class TodayOutfitCard extends StatelessWidget {
  const TodayOutfitCard({
    super.key,
    required this.outfit,
    this.onWear,
    this.onOpenLook,
    this.onSaveAsLook,
  });

  final TodayOutfit outfit;
  final VoidCallback? onWear;
  final VoidCallback? onOpenLook;

  /// Offered only for a composition — a saved look is already saved.
  final VoidCallback? onSaveAsLook;

  @override
  Widget build(BuildContext context) {
    final colors = context.dsColors;

    return SurfaceCard(
      onTap: outfit.isSaved ? onOpenLook : null,
      padding: const EdgeInsets.all(DsSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  outfit.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.dsText.cardTitle,
                ),
              ),
              if (outfit.occasionLabel != null)
                Text(
                  outfit.occasionLabel!,
                  style: context.dsText.caption.tint(colors.primary),
                ),
            ],
          ),
          const SizedBox(height: DsSpacing.sm),
          SizedBox(
            height: 96,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: outfit.pieces.length + outfit.missingSlots.length,
              separatorBuilder: (_, _) => const SizedBox(width: DsSpacing.xs),
              itemBuilder: (context, index) {
                if (index < outfit.pieces.length) {
                  return _PieceThumb(item: outfit.pieces[index]);
                }
                // The gap, drawn in place. An outfit one piece short says so
                // where the piece would be, rather than in a caption she has to
                // connect back to the row.
                final missing =
                    outfit.missingSlots[index - outfit.pieces.length];
                return _MissingThumb(label: missing.label);
              },
            ),
          ),
          const SizedBox(height: DsSpacing.sm),
          Wrap(
            spacing: DsSpacing.xs,
            runSpacing: DsSpacing.xs,
            children: [
              for (final reason in outfit.reasons.take(3))
                DsChip(label: reason.label),
            ],
          ),
          const SizedBox(height: DsSpacing.sm),
          Row(
            children: [
              if (outfit.isWearable && onWear != null)
                Expanded(
                  child: DsButton(
                    label: 'لبستها اليوم',
                    size: DsButtonSize.sm,
                    onPressed: onWear,
                  ),
                ),
              if (outfit.isWearable && onWear != null && onSaveAsLook != null)
                const SizedBox(width: DsSpacing.xs),
              if (onSaveAsLook != null)
                Expanded(
                  child: DsButton(
                    label: 'احفظيها كإطلالة',
                    size: DsButtonSize.sm,
                    variant: DsButtonVariant.secondary,
                    onPressed: onSaveAsLook,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PieceThumb extends StatelessWidget {
  const _PieceThumb({required this.item});

  final ClosetItem item;

  @override
  Widget build(BuildContext context) {
    final colors = context.dsColors;
    final url = item.imageUrl;

    return SizedBox(
      width: 72,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(DsRadius.sm),
              child: url == null || url.isEmpty
                  ? Container(
                      color: colors.surfaceVariant,
                      alignment: Alignment.center,
                      child: Icon(
                        Icons.checkroom_rounded,
                        size: 20,
                        color: colors.onSurfaceVariant,
                      ),
                    )
                  : AuthorizedMediaImage(
                      url: url,
                      width: 72,
                      fallback: Container(
                        color: colors.surfaceVariant,
                        alignment: Alignment.center,
                        child: Icon(
                          Icons.checkroom_rounded,
                          size: 20,
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            item.slotLabel,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: context.dsText.micro,
          ),
        ],
      ),
    );
  }
}

class _MissingThumb extends StatelessWidget {
  const _MissingThumb({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = context.dsColors;

    return SizedBox(
      width: 72,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: DottedOutline(
              child: Center(
                child: Icon(
                  Icons.add_rounded,
                  color: colors.onSurfaceVariant,
                  size: 20,
                ),
              ),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: context.dsText.micro.tint(colors.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

/// A dashed placeholder frame.
///
/// Local to the closet because it means one specific thing here — a slot she
/// could fill — rather than "loading" or "empty". Promoting it to the design
/// system would invite it to be used for both.
class DottedOutline extends StatelessWidget {
  const DottedOutline({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = context.dsColors;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(DsRadius.sm),
        border: Border.all(color: colors.outline, style: BorderStyle.solid),
        color: colors.surfaceVariant.withValues(alpha: 0.4),
      ),
      child: child,
    );
  }
}
