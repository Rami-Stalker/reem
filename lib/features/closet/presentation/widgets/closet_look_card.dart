import 'package:flutter/material.dart';
import 'package:ohara/core/design_system/design_system.dart';
import 'package:ohara/core/localization/l10n_extension.dart';
import 'package:ohara/features/closet/domain/entities/closet_look.dart';
import 'package:ohara/features/closet/presentation/widgets/closet_visuals.dart';

/// A look's pieces as collage cells: owned, wanted, and slots still open.
///
/// A missing slot that already has a wanted product is drawn once, as the
/// product with its caution band — not again as an empty frame beside it.
List<ClosetCollagePiece> closetLookCollage(ClosetLook look) {
  final filled = {for (final piece in look.pieces) piece.slot};
  return [
    for (final piece in look.pieces)
      ClosetCollagePiece(
        slot: piece.slot,
        label: piece.slotLabel,
        url: piece.owned?.imageUrl ?? piece.product?.coverUrl,
        state: piece.isWanted
            ? ClosetCollageState.wanted
            : ClosetCollageState.owned,
      ),
    for (final missing in look.missingSlots)
      if (!filled.contains(missing.key))
        ClosetCollagePiece(
          slot: missing.key,
          label: missing.label,
          state: ClosetCollageState.missing,
        ),
  ];
}

/// Where a look stands, as one pill: ready, one piece short, or several.
class ClosetLookStatus extends StatelessWidget {
  const ClosetLookStatus({super.key, required this.look});

  final ClosetLook look;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    if (look.isComplete) {
      return ClosetPill(
        label: look.wearCount > 0
            ? l10n.closetLookReadyWorn(look.wearCount)
            : l10n.closetLookReady,
        icon: Icons.check_circle_rounded,
        tone: DsTone.positive,
      );
    }
    return ClosetPill(
      label: look.isOnePieceShort
          ? l10n.closetLookShortOne(look.missingSlots.first.label)
          : l10n.closetLookShortMany(look.missingSlots.length),
      icon: Icons.add_circle_outline_rounded,
      tone: DsTone.caution,
    );
  }
}

/// A look, with its gap made visible — the full-width form.
///
/// An incomplete look is not hidden or greyed out. It is shown with the slot it
/// is waiting on, because that unfilled slot is the most actionable thing in
/// the whole feature: she has already decided she wants this outfit.
class ClosetLookCard extends StatelessWidget {
  const ClosetLookCard({
    super.key,
    required this.look,
    this.onTap,
    this.onWear,
  });

  final ClosetLook look;
  final VoidCallback? onTap;
  final VoidCallback? onWear;

  @override
  Widget build(BuildContext context) {
    final colors = context.dsColors;
    final text = context.dsText;

    return SurfaceCard(
      onTap: onTap,
      padding: const EdgeInsets.all(DsSpacing.sm),
      semanticLabel: look.title,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: DsSizes.thumbLg,
            height: DsSizes.thumbLg * 1.25,
            child: ClosetCollage(
              pieces: closetLookCollage(look),
              radius: DsRadius.md,
              wantedLabel: context.l10n.closetMissing,
            ),
          ),
          DsGaps.hSm,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        look.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: text.cardTitle,
                      ),
                    ),
                    if (look.isFavourite) ...[
                      DsGaps.hXxs,
                      Icon(
                        Icons.favorite_rounded,
                        size: DsSizes.iconXs,
                        color: colors.favorite,
                      ),
                    ],
                  ],
                ),
                if (look.occasionLabel != null) ...[
                  DsGaps.vXxxs,
                  Text(
                    look.occasionLabel!,
                    style: text.caption.tint(colors.primary),
                  ),
                ],
                DsGaps.vXs,
                Text(
                  context.l10n.closetLookPieceCount(look.pieces.length),
                  style: text.caption,
                ),
                DsGaps.vXs,
                Row(
                  children: [
                    Flexible(child: ClosetLookStatus(look: look)),
                    if (look.isComplete && onWear != null) ...[
                      const Spacer(),
                      TextButton.icon(
                        onPressed: onWear,
                        icon: const Icon(
                          Icons.check_rounded,
                          size: DsSizes.iconXs,
                        ),
                        label: Text(context.l10n.closetWoreIt),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A look in the lookbook grid: the collage first, the title under it.
class ClosetLookTile extends StatelessWidget {
  const ClosetLookTile({
    super.key,
    required this.look,
    this.onTap,
    this.onWear,
  });

  final ClosetLook look;
  final VoidCallback? onTap;
  final VoidCallback? onWear;

  @override
  Widget build(BuildContext context) {
    final colors = context.dsColors;
    final text = context.dsText;

    return Semantics(
      button: onTap != null,
      label: look.title,
      child: InkWell(
        onTap: onTap,
        borderRadius: DsRadius.borderLg,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ClosetCollage(
                    pieces: closetLookCollage(look),
                    wantedLabel: context.l10n.closetMissing,
                  ),
                  if (look.isFavourite)
                    PositionedDirectional(
                      top: DsSpacing.xs,
                      start: DsSpacing.xs,
                      child: Icon(
                        Icons.favorite_rounded,
                        size: DsSizes.iconXs,
                        color: colors.favorite,
                      ),
                    ),
                  if (look.isComplete && onWear != null)
                    PositionedDirectional(
                      bottom: DsSpacing.xs,
                      end: DsSpacing.xs,
                      child: DsIconButton(
                        icon: Icons.check_rounded,
                        tooltip: context.l10n.closetWoreToday,
                        variant: DsIconButtonVariant.glass,
                        size: DsSizes.controlSm,
                        iconSize: DsSizes.iconXs,
                        onPressed: onWear,
                      ),
                    ),
                ],
              ),
            ),
            DsGaps.vXs,
            Text(
              look.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: text.tileTitle,
            ),
            DsGaps.vXxxs,
            ClosetLookStatus(look: look),
          ],
        ),
      ),
    );
  }
}
