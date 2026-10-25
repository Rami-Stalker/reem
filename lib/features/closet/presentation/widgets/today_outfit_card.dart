import 'package:flutter/material.dart';
import 'package:ohara/core/design_system/design_system.dart';
import 'package:ohara/core/localization/l10n_extension.dart';
import 'package:ohara/features/closet/domain/entities/closet_overview.dart';
import 'package:ohara/features/closet/presentation/widgets/closet_visuals.dart';

/// One answer to "شو بقدر ألبس اليوم؟".
///
/// A composed outfit and a saved one render the same way. The distinction is a
/// single pill, because from where she is standing there is no difference
/// worth a different card: both are her own clothes, arranged.
///
/// The outfit is drawn as one picture — a flat-lay collage — with the pieces
/// named underneath, so she sees the look before she reads it. A slot the
/// outfit is short of is drawn in place as an open frame.
class TodayOutfitCard extends StatelessWidget {
  const TodayOutfitCard({
    super.key,
    required this.outfit,
    this.onWear,
    this.onOpenLook,
    this.onSaveAsLook,
    this.worn = false,
    this.featured = false,
    this.eyebrow,
  });

  final TodayOutfit outfit;
  final VoidCallback? onWear;
  final VoidCallback? onOpenLook;

  /// Offered only for a composition — a saved look is already saved.
  final VoidCallback? onSaveAsLook;

  /// She has logged this outfit today. The wear button turns into a quiet
  /// confirmation rather than disappearing, so the card does not jump.
  final bool worn;

  /// The first answer: a taller collage and the larger title.
  final bool featured;

  /// A line above the title — «اقتراح اليوم» on the closet's front page.
  final String? eyebrow;

  @override
  Widget build(BuildContext context) {
    final colors = context.dsColors;
    final text = context.dsText;
    final palette = context.boutique;

    final collage = [
      for (final piece in outfit.pieces)
        ClosetCollagePiece(
          slot: piece.slot,
          label: piece.slotLabel,
          url: piece.imageUrl,
        ),
      for (final missing in outfit.missingSlots)
        ClosetCollagePiece(
          slot: missing.key,
          label: missing.label,
          state: ClosetCollageState.missing,
        ),
    ];

    return SurfaceCard(
      onTap: outfit.isSaved ? onOpenLook : null,
      padding: const EdgeInsets.all(DsSpacing.sm),
      semanticLabel: outfit.title,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          AspectRatio(
            aspectRatio: featured ? 4 / 3 : 16 / 10,
            child: Stack(
              fit: StackFit.expand,
              children: [
                ClosetCollage(pieces: collage, radius: DsRadius.lg),
                PositionedDirectional(
                  top: DsSpacing.xs,
                  start: DsSpacing.xs,
                  child: ClosetPill(
                    label: outfit.isSaved
                        ? context.l10n.closetOriginSaved
                        : context.l10n.closetOriginComposed,
                    icon: outfit.isSaved
                        ? Icons.bookmark_rounded
                        : Icons.auto_awesome_rounded,
                    onMedia: true,
                  ),
                ),
                if (!outfit.isWearable)
                  PositionedDirectional(
                    top: DsSpacing.xs,
                    end: DsSpacing.xs,
                    child: ClosetPill(
                      label: context.l10n.closetShortBy(
                        outfit.missingSlots.length,
                      ),
                      tone: DsTone.caution,
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              DsSpacing.xxs,
              DsSpacing.sm,
              DsSpacing.xxs,
              0,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (eyebrow != null) ...[
                  Text(eyebrow!, style: text.overline.tint(palette.primary)),
                  DsGaps.vXxxs,
                ],
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        outfit.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: featured ? text.sectionTitle : text.cardTitle,
                      ),
                    ),
                    if (outfit.occasionLabel != null) ...[
                      DsGaps.hXs,
                      ClosetPill(
                        label: outfit.occasionLabel!,
                        icon: Icons.celebration_rounded,
                        tone: DsTone.accent,
                      ),
                    ],
                  ],
                ),
                DsGaps.vXxs,
                // The pieces by name, in the collage's order, so the picture
                // and the sentence can be read against each other.
                Text(
                  outfit.pieces.map((piece) => piece.title).join(' · '),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: text.caption,
                ),
                if (outfit.reasons.isNotEmpty) ...[
                  DsGaps.vSm,
                  Wrap(
                    spacing: DsSpacing.xs,
                    runSpacing: DsSpacing.xs,
                    children: [
                      for (final reason in outfit.reasons.take(3))
                        ClosetPill(
                          label: reason.label,
                          icon: Icons.check_rounded,
                          tone: DsTone.positive,
                        ),
                    ],
                  ),
                ],
                DsGaps.vSm,
                _Actions(
                  worn: worn,
                  wearable: outfit.isWearable,
                  onWear: onWear,
                  onSaveAsLook: onSaveAsLook,
                  colors: colors,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Actions extends StatelessWidget {
  const _Actions({
    required this.worn,
    required this.wearable,
    required this.onWear,
    required this.onSaveAsLook,
    required this.colors,
  });

  final bool worn;
  final bool wearable;
  final VoidCallback? onWear;
  final VoidCallback? onSaveAsLook;
  final DsColorScheme colors;

  @override
  Widget build(BuildContext context) {
    final wear = wearable && onWear != null;
    if (!wear && onSaveAsLook == null) return const SizedBox.shrink();

    return Row(
      children: [
        if (wear)
          Expanded(
            child: worn
                ? DsButton(
                    label: context.l10n.closetWornTodayDone,
                    icon: Icons.check_circle_rounded,
                    size: DsButtonSize.sm,
                    variant: DsButtonVariant.tonal,
                    onPressed: null,
                  )
                : DsButton(
                    label: context.l10n.closetWoreToday,
                    icon: Icons.check_rounded,
                    size: DsButtonSize.sm,
                    onPressed: onWear,
                  ),
          ),
        if (wear && onSaveAsLook != null) DsGaps.hXs,
        if (onSaveAsLook != null)
          Expanded(
            child: DsButton(
              label: context.l10n.closetSaveAsLook,
              icon: Icons.bookmark_add_outlined,
              size: DsButtonSize.sm,
              variant: DsButtonVariant.secondary,
              onPressed: onSaveAsLook,
            ),
          ),
      ],
    );
  }
}
