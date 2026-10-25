import 'package:flutter/material.dart';
import 'package:ohara/core/design_system/design_system.dart';
import 'package:ohara/core/localization/l10n_extension.dart';
import 'package:ohara/features/closet/domain/entities/closet_item.dart';
import 'package:ohara/features/closet/presentation/widgets/closet_visuals.dart';

/// One garment in the grid.
///
/// Draws a catalog piece and a personal one identically — same frame, same
/// typography, same size. The only mark of provenance is a small badge, and
/// that restraint is deliberate: a wardrobe where the things she bought here
/// look more important than the things she already owned is a shop pretending
/// to be a wardrobe.
///
/// The photo carries three quiet signals and one action: a heart when she
/// loves it, a rotation note when the piece has gone unworn, a badge for a
/// piece of her own, and the one-tap wear button.
class ClosetItemTile extends StatelessWidget {
  const ClosetItemTile({
    super.key,
    required this.item,
    this.onTap,
    this.onWear,
    this.showWear = true,
    this.dense = false,
  });

  final ClosetItem item;
  final VoidCallback? onTap;
  final VoidCallback? onWear;
  final bool showWear;

  /// The three-column grid and the rails: smaller type, no provenance badge.
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final colors = context.dsColors;
    final text = context.dsText;
    final wornToday = item.daysSinceWorn == 0;

    return Semantics(
      button: onTap != null,
      label: '${item.title}، ${item.slotLabel}، ${_subtitle(context)}',
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: DsRadius.borderLg,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: DsRadius.borderLg,
                  border: Border.all(
                    color: wornToday
                        ? colors.primary
                        : colors.border.withValues(alpha: 0.5),
                    width: wornToday ? DsSpacing.xxxs : 1,
                  ),
                ),
                child: ClipRRect(
                  borderRadius: DsRadius.borderLg,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      ClosetPhoto(
                        url: item.imageUrl,
                        slot: item.slot,
                        blurHash: item.blurHash,
                        iconSize: dense ? DsSizes.iconMd : DsSizes.iconLg,
                      ),
                      if (item.isFavourite)
                        PositionedDirectional(
                          top: DsSpacing.xs,
                          start: DsSpacing.xs,
                          child: _FrostedDot(
                            child: Icon(
                              Icons.favorite_rounded,
                              size: DsSizes.iconXxs,
                              color: colors.favorite,
                            ),
                          ),
                        ),
                      if (_rotationNote(context) case final note?)
                        PositionedDirectional(
                          top: DsSpacing.xs,
                          end: DsSpacing.xs,
                          child: ClosetPill(label: note, onMedia: true),
                        ),
                      if (!dense && !item.source.isFromOhara)
                        PositionedDirectional(
                          bottom: DsSpacing.xs,
                          start: DsSpacing.xs,
                          child: ClosetPill(
                            label: context.l10n.closetMyPiece,
                            icon: Icons.photo_camera_rounded,
                            onMedia: true,
                          ),
                        ),
                      if (showWear && onWear != null)
                        PositionedDirectional(
                          bottom: DsSpacing.xs,
                          end: DsSpacing.xs,
                          child: _WearButton(
                            wornToday: wornToday,
                            onWear: onWear!,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            DsGaps.vXs,
            Text(
              item.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: dense ? text.captionStrong : text.tileTitle,
            ),
            Text(
              _subtitle(context),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: text.caption,
            ),
          ],
        ),
      ),
    );
  }

  /// The one thing about rotation worth printing on the photograph: that she
  /// has never worn it, or not for a season. A wear count is not printed
  /// there — it is in the subtitle, and a number on every tile is noise.
  String? _rotationNote(BuildContext context) {
    if (!item.hasBeenWorn) return context.l10n.closetTagUnworn;
    if ((item.daysSinceWorn ?? 0) >= 90) return context.l10n.closetTagForgotten;
    return null;
  }

  /// The slot, plus whichever fact about rotation is most worth knowing.
  ///
  /// Never-worn wins over worn-long-ago, and both win over a wear count,
  /// because the point of a wardrobe log is the things she is not reaching for.
  ///
  /// The dense grid drops the slot: at three columns it pushed the rotation
  /// fact — the half worth reading — off the end of the line.
  String _subtitle(BuildContext context) {
    final l10n = context.l10n;
    if (dense) {
      if (!item.hasBeenWorn) return l10n.closetWornNeverShort;
      final days = item.daysSinceWorn;
      if (days != null && days >= 90) return l10n.closetWornLongAgoShort;
      return l10n.closetWornTimes(item.wearCount);
    }
    if (!item.hasBeenWorn) return l10n.closetTileNeverWorn(item.slotLabel);
    final days = item.daysSinceWorn;
    if (days != null && days >= 90) return l10n.closetTileLongAgo(item.slotLabel);
    return l10n.closetTileWornCount(item.slotLabel, item.wearCount);
  }
}

class _FrostedDot extends StatelessWidget {
  const _FrostedDot({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(DsSpacing.xxs),
      decoration: BoxDecoration(
        color: context.dsColors.surface.withValues(alpha: 0.88),
        shape: BoxShape.circle,
      ),
      child: child,
    );
  }
}

/// "لبستها اليوم" in one tap.
///
/// The whole wear log depends on this being nearly free. A woman will not open
/// a garment's page to record that she wore it, so the button is on the tile
/// and the server makes a second tap idempotent. Once she has worn it today
/// the button fills and the frame around the photo turns rose, so the grid
/// shows today's outfit at a glance.
class _WearButton extends StatelessWidget {
  const _WearButton({required this.wornToday, required this.onWear});

  final bool wornToday;
  final VoidCallback onWear;

  @override
  Widget build(BuildContext context) {
    final colors = context.dsColors;
    final label = wornToday
        ? context.l10n.closetWornTodayDone
        : context.l10n.closetWoreToday;

    return Tooltip(
      message: label,
      child: Semantics(
        button: true,
        label: label,
        child: Material(
          color: wornToday
              ? colors.primary
              : colors.surface.withValues(alpha: 0.92),
          shape: const CircleBorder(),
          elevation: 0,
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onWear,
            child: Padding(
              padding: const EdgeInsets.all(DsSpacing.xs),
              child: Icon(
                wornToday ? Icons.check_rounded : Icons.add_rounded,
                size: DsSizes.iconXs,
                color: wornToday ? colors.onPrimary : colors.onSurface,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
