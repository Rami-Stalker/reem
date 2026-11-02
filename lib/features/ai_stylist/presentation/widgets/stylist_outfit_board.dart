import 'package:flutter/material.dart';
import 'package:ohara/core/design_system/design_system.dart';
import 'package:ohara/core/localization/l10n_extension.dart';
import 'package:ohara/core/media/authorized_media_image.dart';
import 'package:ohara/core/media/media_variants.dart';
import 'package:ohara/features/ai_stylist/domain/entities/style_brief.dart';
import 'package:ohara/features/ai_stylist/domain/entities/stylist_outfit.dart';
import 'package:ohara/features/ai_stylist/presentation/widgets/stylist_aura.dart';

/// A complete look, shown as a board rather than a list.
///
/// The pieces are laid out side by side because that is the question she is
/// actually asking — do these go together — and a vertical list answers a
/// different one. The palette and the total sit under them, since both are
/// properties of the look and not of any piece.
class StylistOutfitBoard extends StatelessWidget {
  const StylistOutfitBoard({
    super.key,
    required this.outfit,
    this.onPieceTap,
    this.onSave,
    this.onOpen,
  });

  final StylistOutfit outfit;
  final void Function(OutfitPiece piece)? onPieceTap;
  final VoidCallback? onSave;
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context) {
    final colors = context.dsColors;

    return StylistAppear(
      index: 1,
      offset: 20,
      child: StylistPanel(
        highlighted: true,
        padding: const EdgeInsets.all(DsSpacing.sm),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            _Header(outfit: outfit, onOpen: onOpen),
            DsGaps.vSm,
            SizedBox(
              // Room for a square cover, the slot name, two lines of title and
              // a price. The tile below trims the title rather than overflowing
              // when a product name runs long.
              height: 196,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: outfit.items.length,
                separatorBuilder: (_, _) => DsGaps.hXs,
                itemBuilder: (context, index) {
                  final piece = outfit.items[index];
                  return StylistAppear(
                    index: index + 2,
                    offset: 16,
                    child: _PieceTile(
                      piece: piece,
                      onTap: onPieceTap == null ? null : () => onPieceTap!(piece),
                    ),
                  );
                },
              ),
            ),
            if (outfit.palette.isNotEmpty) ...[
              DsGaps.vSm,
              StylistPalette(palette: outfit.palette),
            ],
            if (outfit.note != null && outfit.note!.isNotEmpty) ...[
              DsGaps.vXs,
              Text(
                outfit.note!,
                style: context.dsText.labelMedium
                    .tint(colors.onSurfaceVariant)
                    .copyWith(height: 1.55),
              ),
            ],
            DsGaps.vSm,
            _Footer(outfit: outfit, onSave: onSave),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.outfit, this.onOpen});

  final StylistOutfit outfit;
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context) {
    final colors = context.dsColors;

    return Row(
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            gradient: context.boutique.signatureGradient,
            borderRadius: BorderRadius.circular(DsRadius.md),
          ),
          child: const Icon(Icons.checkroom_rounded, size: 18, color: DsColors.onMedia),
        ),
        DsGaps.hXs,
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                outfit.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.dsText.tileTitle.bold.tint(colors.onSurface),
              ),
              if (outfit.occasionLabel != null)
                Text(
                  outfit.occasionLabel!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.dsText.caption.tint(colors.primary),
                ),
            ],
          ),
        ),
        if (onOpen != null)
          IconButton.filledTonal(
            onPressed: onOpen,
            visualDensity: VisualDensity.compact,
            icon: Icon(Icons.open_in_full_rounded, size: 16, color: colors.primary),
            tooltip: context.l10n.stylistOpenLook,
          ),
      ],
    );
  }
}

class _PieceTile extends StatelessWidget {
  const _PieceTile({required this.piece, this.onTap});

  final OutfitPiece piece;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.dsColors;
    final product = piece.product;

    return SizedBox(
      width: 116,
      child: InkWell(
        onTap: product == null ? null : onTap,
        borderRadius: BorderRadius.circular(DsRadius.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(DsRadius.lg),
              child: AspectRatio(
                aspectRatio: 1,
                child: product?.coverUrl != null
                    ? AuthorizedMediaImage(
                        url: product!.coverUrl!,
                        blurHash: product.coverBlurHash,
                        variantWidth: MediaVariants.thumbnail,
                      )
                    // A withdrawn piece stays in the look as an empty slot —
                    // a three-piece outfit that silently becomes two is a look
                    // she no longer recognises.
                    : Container(
                        color: colors.surfaceVariant,
                        child: Icon(
                          Icons.hide_image_outlined,
                          color: colors.onSurfaceVariant,
                          size: 20,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: DsSpacing.xxs),
            Text(
              piece.slotLabel,
              style: context.dsText.caption.semibold.tint(colors.primary),
            ),
            // Flexible so a long product name is trimmed instead of pushing
            // the price out of the tile.
            Flexible(
              child: Text(
                product?.title ?? context.l10n.stylistNoLongerAvailable,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: context.dsText.caption.tint(colors.onSurface).copyWith(height: 1.3),
              ),
            ),
            if (piece.price != null)
              Text(
                piece.price!.format(),
                style: context.dsText.caption.bold.tint(colors.onSurfaceVariant),
              ),
          ],
        ),
      ),
    );
  }
}

/// A look's colours as real swatches with their names — the eye reads a dot
/// of olive faster than the word.
class StylistPalette extends StatelessWidget {
  const StylistPalette({super.key, required this.palette});

  final List<StyleTerm> palette;

  @override
  Widget build(BuildContext context) {
    final colors = context.dsColors;

    return Wrap(
      spacing: DsSpacing.xxs,
      runSpacing: DsSpacing.xxs,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Icon(Icons.palette_outlined, size: 15, color: colors.onSurfaceVariant),
        DsGaps.hXxxs,
        for (final colour in palette)
          Container(
            padding: const EdgeInsetsDirectional.fromSTEB(
              DsSpacing.xxs,
              DsSpacing.xxs,
              DsSpacing.xs,
              DsSpacing.xxs,
            ),
            decoration: BoxDecoration(
              color: colors.surfaceVariant.withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(DsRadius.pill),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: DsFabricSwatches.forKey(colour.key) ?? colors.outline,
                    border: Border.all(color: colors.border),
                  ),
                ),
                DsGaps.hXxs,
                Text(
                  colour.label,
                  style: context.dsText.caption.tint(colors.onSurface),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _Footer extends StatelessWidget {
  const _Footer({required this.outfit, this.onSave});

  final StylistOutfit outfit;
  final VoidCallback? onSave;

  @override
  Widget build(BuildContext context) {
    final colors = context.dsColors;

    return Row(
      children: [
        if (outfit.total != null)
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  context.l10n.stylistLookTotal,
                  style: context.dsText.caption.tint(colors.onSurfaceVariant),
                ),
                StylistGradientText(
                  outfit.total!.format(),
                  style: context.dsText.metricSmall.bold,
                ),
              ],
            ),
          )
        else
          const Spacer(),
        if (onSave != null)
          FilledButton.tonalIcon(
            onPressed: outfit.isSaved ? null : onSave,
            style: FilledButton.styleFrom(
              visualDensity: VisualDensity.compact,
              backgroundColor: colors.primaryContainer,
              foregroundColor: colors.onPrimaryContainer,
            ),
            icon: AnimatedSwitcher(
              duration: DsDurations.normal,
              transitionBuilder: (child, animation) =>
                  ScaleTransition(scale: animation, child: child),
              child: Icon(
                outfit.isSaved
                    ? Icons.bookmark_rounded
                    : Icons.bookmark_border_rounded,
                key: ValueKey(outfit.isSaved),
                size: 16,
              ),
            ),
            label: Text(
              outfit.isSaved
                  ? context.l10n.stylistLookSaved
                  : context.l10n.stylistSaveLook,
            ),
          ),
      ],
    );
  }
}
