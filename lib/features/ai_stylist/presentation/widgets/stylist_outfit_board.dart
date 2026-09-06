import 'package:flutter/material.dart';
import 'package:reem/core/design_system/design_system.dart';
import 'package:reem/core/media/authorized_media_image.dart';
import 'package:reem/core/media/media_variants.dart';
import 'package:reem/features/ai_stylist/domain/entities/stylist_outfit.dart';

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

    return Container(
      decoration: BoxDecoration(
        color: colors.surfaceElevated,
        borderRadius: BorderRadius.circular(DsRadius.card),
        border: Border.all(color: colors.border),
      ),
      padding: const EdgeInsets.all(DsSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          _Header(outfit: outfit, onOpen: onOpen),
          const SizedBox(height: DsSpacing.sm),
          SizedBox(
            // Room for a square cover, the slot name, two lines of title and
            // a price. The tile below trims the title rather than overflowing
            // when a product name runs long.
            height: 192,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: outfit.items.length,
              separatorBuilder: (_, _) => const SizedBox(width: DsSpacing.xs),
              itemBuilder: (context, index) {
                final piece = outfit.items[index];
                return _PieceTile(
                  piece: piece,
                  onTap: onPieceTap == null ? null : () => onPieceTap!(piece),
                );
              },
            ),
          ),
          if (outfit.palette.isNotEmpty) ...[
            const SizedBox(height: DsSpacing.sm),
            _Palette(outfit: outfit),
          ],
          if (outfit.note != null && outfit.note!.isNotEmpty) ...[
            const SizedBox(height: DsSpacing.xs),
            Text(
              outfit.note!,
              style: context.dsText.labelMedium.tint(colors.onSurfaceVariant).copyWith(height: 1.5),
            ),
          ],
          const SizedBox(height: DsSpacing.sm),
          _Footer(outfit: outfit, onSave: onSave),
        ],
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
        Icon(Icons.checkroom_rounded, size: 18, color: colors.primary),
        const SizedBox(width: DsSpacing.xs),
        Expanded(
          child: Text(
            outfit.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: context.dsText.tileTitle.bold.tint(colors.onSurface),
          ),
        ),
        if (onOpen != null)
          IconButton(
            onPressed: onOpen,
            visualDensity: VisualDensity.compact,
            icon: Icon(Icons.open_in_full_rounded, size: 16, color: colors.primary),
            tooltip: 'افتحي الإطلالة',
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
                product?.title ?? 'لم تعد متوفرة',
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

class _Palette extends StatelessWidget {
  const _Palette({required this.outfit});

  final StylistOutfit outfit;

  @override
  Widget build(BuildContext context) {
    final colors = context.dsColors;

    return Wrap(
      spacing: DsSpacing.xxs,
      runSpacing: DsSpacing.xxs,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Icon(Icons.palette_outlined, size: 14, color: colors.onSurfaceVariant),
        for (final colour in outfit.palette)
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: DsSpacing.xs,
              vertical: DsSpacing.xxxs,
            ),
            decoration: BoxDecoration(
              color: colors.surfaceVariant,
              borderRadius: BorderRadius.circular(DsRadius.pill),
            ),
            child: Text(
              colour.label,
              style: context.dsText.caption.tint(colors.onSurfaceVariant),
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
                  'مجموع الإطلالة',
                  style: context.dsText.caption.tint(colors.onSurfaceVariant),
                ),
                Text(
                  outfit.total!.format(),
                  style: context.dsText.tileTitle.bold.tint(colors.primary),
                ),
              ],
            ),
          )
        else
          const Spacer(),
        if (onSave != null)
          TextButton.icon(
            onPressed: outfit.isSaved ? null : onSave,
            icon: Icon(
              outfit.isSaved
                  ? Icons.bookmark_rounded
                  : Icons.bookmark_border_rounded,
              size: 16,
            ),
            label: Text(outfit.isSaved ? 'محفوظة' : 'احفظي الإطلالة'),
          ),
      ],
    );
  }
}
