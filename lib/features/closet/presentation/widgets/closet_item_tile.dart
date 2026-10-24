import 'package:flutter/material.dart';
import 'package:ohara/core/design_system/design_system.dart';
import 'package:ohara/core/localization/l10n_extension.dart';
import 'package:ohara/core/media/authorized_media_image.dart';
import 'package:ohara/features/closet/domain/entities/closet_item.dart';

/// One garment in the grid.
///
/// Draws a catalog piece and a personal one identically — same frame, same
/// typography, same size. The only mark of provenance is a small badge, and
/// that restraint is deliberate: a wardrobe where the things she bought here
/// look more important than the things she already owned is a shop pretending
/// to be a wardrobe.
class ClosetItemTile extends StatelessWidget {
  const ClosetItemTile({
    super.key,
    required this.item,
    this.onTap,
    this.onWear,
    this.showWear = true,
  });

  final ClosetItem item;
  final VoidCallback? onTap;
  final VoidCallback? onWear;
  final bool showWear;

  @override
  Widget build(BuildContext context) {
    final colors = context.dsColors;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(DsRadius.card),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Stack(
              fit: StackFit.expand,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(DsRadius.card),
                  child: _Photo(item: item),
                ),
                if (item.isFavourite)
                  Positioned(
                    top: DsSpacing.xs,
                    right: DsSpacing.xs,
                    child: Icon(
                      Icons.favorite_rounded,
                      size: 18,
                      color: colors.favorite,
                    ),
                  ),
                if (!item.source.isFromOhara)
                  Positioned(
                    bottom: DsSpacing.xs,
                    left: DsSpacing.xs,
                    child: _Badge(
                      label: context.l10n.closetMyPiece,
                      color: colors.secondaryContainer,
                    ),
                  ),
                if (showWear && onWear != null)
                  Positioned(
                    bottom: DsSpacing.xs,
                    right: DsSpacing.xs,
                    child: _WearButton(item: item, onWear: onWear!),
                  ),
              ],
            ),
          ),
          const SizedBox(height: DsSpacing.xs),
          Text(
            item.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: context.dsText.tileTitle,
          ),
          Text(
            _subtitle(context),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: context.dsText.caption,
          ),
        ],
      ),
    );
  }

  /// The slot, plus whichever fact about rotation is most worth knowing.
  ///
  /// Never-worn wins over worn-long-ago, and both win over a wear count,
  /// because the point of a wardrobe log is the things she is not reaching for.
  String _subtitle(BuildContext context) {
    final l10n = context.l10n;
    if (!item.hasBeenWorn) return l10n.closetTileNeverWorn(item.slotLabel);
    final days = item.daysSinceWorn;
    if (days != null && days >= 90) return l10n.closetTileLongAgo(item.slotLabel);
    return l10n.closetTileWornCount(item.slotLabel, item.wearCount);
  }
}

class _Photo extends StatelessWidget {
  const _Photo({required this.item});

  final ClosetItem item;

  @override
  Widget build(BuildContext context) {
    final colors = context.dsColors;
    final url = item.imageUrl;

    if (url == null || url.isEmpty) {
      return Container(
        color: colors.surfaceVariant,
        alignment: Alignment.center,
        child: Icon(
          Icons.checkroom_rounded,
          color: colors.onSurfaceVariant,
          size: 32,
        ),
      );
    }

    // A personal photograph is a PRIVATE asset behind her session — which is
    // exactly why this cannot be `Image.network`. That loader has its own HTTP
    // client, carries no bearer token, and got a 401 for every wardrobe photo
    // she had ever taken: the tile below fell through to the hanger icon every
    // single time, and looked like a design choice rather than a broken fetch.
    // `AuthorizedMediaImage` attaches the session, caches the result, and
    // decodes at the size the tile actually draws.
    return AuthorizedMediaImage(
      url: url,
      fallback: Container(
        color: colors.surfaceVariant,
        alignment: Alignment.center,
        child: Icon(Icons.checkroom_rounded, color: colors.onSurfaceVariant),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: DsSpacing.xs,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(DsRadius.pill),
      ),
      child: Text(label, style: context.dsText.badge),
    );
  }
}

/// "لبستها اليوم" in one tap.
///
/// The whole wear log depends on this being nearly free. A woman will not open
/// a garment's page to record that she wore it, so the button is on the tile
/// and the server makes a second tap idempotent.
class _WearButton extends StatelessWidget {
  const _WearButton({required this.item, required this.onWear});

  final ClosetItem item;
  final VoidCallback onWear;

  @override
  Widget build(BuildContext context) {
    final colors = context.dsColors;
    final wornToday = item.daysSinceWorn == 0;

    return Material(
      color: wornToday ? colors.primary : colors.surface.withValues(alpha: 0.9),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onWear,
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Icon(
            wornToday ? Icons.check_rounded : Icons.add_rounded,
            size: 16,
            color: wornToday ? colors.onPrimary : colors.onSurface,
          ),
        ),
      ),
    );
  }
}
