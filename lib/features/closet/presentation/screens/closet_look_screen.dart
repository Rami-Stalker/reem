import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ohara/core/design_system/design_system.dart';
import 'package:ohara/core/localization/l10n_extension.dart';
import 'package:ohara/core/result/result.dart';
import 'package:ohara/core/router/route_paths.dart';
import 'package:ohara/features/closet/domain/entities/closet_gap.dart';
import 'package:ohara/features/closet/domain/entities/closet_look.dart';
import 'package:ohara/features/closet/domain/repositories/closet_repository.dart';
import 'package:ohara/features/closet/presentation/providers/closet_providers.dart';
import 'package:ohara/features/closet/presentation/widgets/closet_look_card.dart';
import 'package:ohara/features/closet/presentation/widgets/closet_visuals.dart';

/// One look.
///
/// The empty slots are the point of the screen. Each one offers to find the
/// piece that would fill it — which routes into the gap the engine has already
/// raised for exactly this look, so the suggestion arrives constrained by the
/// look's own palette and her own size rather than as a category browse.
class ClosetLookScreen extends ConsumerWidget {
  const ClosetLookScreen({super.key, required this.lookId});

  final String lookId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.dsColors;
    final lookAsync = ref.watch(closetLookProvider(lookId));

    return Scaffold(
      backgroundColor: colors.background,
      appBar: OharaAppBar(
        title: context.l10n.closetLookTitle,
        actions: [
          lookAsync.maybeWhen(
            data: (look) => IconButton(
              tooltip: look.isFavourite
                  ? context.l10n.closetRemoveFavourite
                  : context.l10n.closetAddFavourite,
              icon: Icon(
                look.isFavourite
                    ? Icons.favorite_rounded
                    : Icons.favorite_outline_rounded,
                color: look.isFavourite ? colors.favorite : null,
              ),
              onPressed: () => ref
                  .read(closetActionsProvider)
                  .updateLook(
                    lookId,
                    LookPatch(isFavourite: !look.isFavourite),
                  ),
            ),
            orElse: () => const SizedBox.shrink(),
          ),
        ],
      ),
      body: lookAsync.when(
        loading: () => const Center(child: DsLoadingIndicator()),
        error: (_, _) => DsErrorState(
          message: context.l10n.closetLookLoadFailed,
          onRetry: () => ref.invalidate(closetLookProvider(lookId)),
        ),
        data: (look) => _Body(look: look),
      ),
    );
  }
}

class _Body extends ConsumerWidget {
  const _Body({required this.look});

  final ClosetLook look;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final text = context.dsText;
    final colors = context.dsColors;
    final palette = context.boutique;
    final gapsAsync = ref.watch(closetGapsProvider);

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        DsSpacing.lg,
        DsSpacing.sm,
        DsSpacing.lg,
        DsSpacing.xxl,
      ),
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: DsRadius.borderCard,
            boxShadow: palette.shadow,
          ),
          child: AspectRatio(
            aspectRatio: 1,
            child: Stack(
              fit: StackFit.expand,
              children: [
                ClosetCollage(
                  pieces: closetLookCollage(look),
                  radius: DsRadius.card,
                  wantedLabel: l10n.closetMissing,
                ),
                PositionedDirectional(
                  top: DsSpacing.sm,
                  start: DsSpacing.sm,
                  child: ClosetLookStatus(look: look),
                ),
              ],
            ),
          ),
        ),
        DsGaps.vLg,
        Text(look.title, style: text.pageTitle),
        DsGaps.vXs,
        Wrap(
          spacing: DsSpacing.xs,
          runSpacing: DsSpacing.xs,
          children: [
            if (look.occasionLabel != null)
              ClosetPill(
                label: look.occasionLabel!,
                icon: Icons.celebration_rounded,
                tone: DsTone.accent,
              ),
            for (final season in look.seasons)
              ClosetPill(label: season.label, icon: Icons.wb_sunny_outlined),
            if (look.sourceOutfitId != null)
              ClosetPill(
                label: l10n.closetFromStylist,
                icon: Icons.auto_awesome_rounded,
                tone: DsTone.info,
              ),
          ],
        ),
        if (look.note != null && look.note!.isNotEmpty) ...[
          DsGaps.vSm,
          Text(look.note!, style: text.body),
        ],
        if (look.palette.isNotEmpty) ...[
          DsGaps.vMd,
          Row(
            children: [
              Icon(Icons.palette_outlined, size: DsSizes.iconXs, color: palette.muted),
              DsGaps.hXs,
              Text(l10n.closetLookPalette, style: text.label.tint(palette.muted)),
              DsGaps.hXs,
              Expanded(
                child: Wrap(
                  spacing: DsSpacing.xxs,
                  runSpacing: DsSpacing.xxs,
                  children: [
                    for (final colour in look.palette) ClosetPill(label: colour.label),
                  ],
                ),
              ),
            ],
          ),
        ],
        DsGaps.vLg,
        _WearPanel(look: look),
        DsGaps.vXl,
        Text(l10n.closetLookPieces(look.pieces.length), style: text.sectionTitle),
        DsGaps.vSm,
        for (final piece in look.pieces) ...[
          _PieceRow(
            piece: piece,
            gap: gapsAsync.maybeWhen(
              data: (gaps) => _gapFor(gaps, piece),
              orElse: () => null,
            ),
            onRemove: () => _removeSlot(context, ref, piece),
          ),
          DsGaps.vXs,
        ],
        DsGaps.vXl,
        Center(
          child: TextButton.icon(
            onPressed: () => _delete(context, ref),
            icon: Icon(Icons.delete_outline_rounded, color: colors.error),
            label: Text(
              l10n.closetDeleteLook,
              style: text.button.tint(colors.error),
            ),
          ),
        ),
      ],
    );
  }

  /// The gap the engine raised for this look and this slot.
  ///
  /// Matched rather than requested: gaps are already loaded for the closet, and
  /// a LOOK_SLOT gap carries both ids, so the button can route straight to
  /// suggestions that know the look's palette.
  ClosetGap? _gapFor(List<ClosetGap> gaps, LookPiece piece) {
    for (final gap in gaps) {
      if (gap.lookId == look.id && gap.slot == piece.slot) return gap;
    }
    return null;
  }

  Future<void> _removeSlot(
    BuildContext context,
    WidgetRef ref,
    LookPiece piece,
  ) async {
    final remaining = look.pieces
        .where((other) => other.slot != piece.slot)
        .map(
          (other) => LookSlotDraft(
            slot: other.slot,
            closetItemId: other.owned?.id,
            productId: other.owned == null ? other.product?.id : null,
            offerId: other.offerId,
            variantId: other.variantId,
          ),
        )
        .toList(growable: false);

    final result = await ref
        .read(closetActionsProvider)
        .setLookItems(look.id, remaining);
    if (!context.mounted || result is Success) return;
    DsSnackbar.show(
      context,
      message: context.l10n.closetUpdateFailed,
      type: DsSnackbarType.error,
    );
  }

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final confirmed = await DsDialog.confirm(
      context,
      title: context.l10n.closetDeleteLookConfirmTitle,
      message: context.l10n.closetDeleteLookConfirmBody,
      confirmLabel: context.l10n.closetDeleteLook,
      icon: Icons.delete_outline_rounded,
      destructive: true,
    );
    if (!confirmed || !context.mounted) return;

    await ref.read(closetActionsProvider).removeLook(look.id);
    if (!context.mounted) return;
    context.canPop() ? context.pop() : context.go(RoutePaths.closetLooks);
  }
}

/// Wear it, or what stands between her and wearing it.
class _WearPanel extends ConsumerWidget {
  const _WearPanel({required this.look});

  final ClosetLook look;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final text = context.dsText;
    final colors = context.dsColors;

    if (!look.isComplete) {
      return Container(
        padding: const EdgeInsets.all(DsSpacing.md),
        decoration: BoxDecoration(
          color: colors.warningContainer,
          borderRadius: DsRadius.borderLg,
        ),
        child: Row(
          children: [
            Icon(Icons.add_circle_outline_rounded, color: colors.warning),
            DsGaps.hSm,
            Expanded(
              child: Text(
                look.isOnePieceShort
                    ? l10n.closetLookOneShort(look.missingSlots.first.label)
                    : l10n.closetLookManyShort(look.missingSlots.length),
                style: text.body,
              ),
            ),
          ],
        ),
      );
    }

    return CustomerPanel(
      padding: const EdgeInsets.all(DsSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.repeat_rounded, size: DsSizes.iconSm, color: colors.success),
              DsGaps.hXs,
              Expanded(
                child: Text(
                  look.wearCount > 0
                      ? l10n.closetLookWornCount(look.wearCount)
                      : l10n.closetLookNotWornYet,
                  style: text.labelStrong,
                ),
              ),
            ],
          ),
          DsGaps.vSm,
          CustomerPrimaryButton(
            label: l10n.closetWoreToday,
            icon: Icons.check_rounded,
            onPressed: () async {
              final result = await ref
                  .read(closetActionsProvider)
                  .logLookWear(look.id);
              if (!context.mounted) return;
              DsSnackbar.show(
                context,
                message: result is Success
                    ? l10n.closetTodayLogged
                    : l10n.closetWearFailed,
                type: result is Success
                    ? DsSnackbarType.success
                    : DsSnackbarType.error,
              );
            },
          ),
        ],
      ),
    );
  }
}

class _PieceRow extends StatelessWidget {
  const _PieceRow({required this.piece, this.gap, this.onRemove});

  final LookPiece piece;
  final ClosetGap? gap;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final colors = context.dsColors;
    final text = context.dsText;
    final url = piece.owned?.imageUrl ?? piece.product?.coverUrl;
    final title = piece.owned?.title ?? piece.product?.title ?? piece.slotLabel;

    void open() {
      if (piece.owned case final owned?) {
        context.push(RoutePaths.closetItemOf(owned.id));
      } else if (piece.product case final product?) {
        context.push(RoutePaths.productDetailsOf(product.id));
      }
    }

    return SurfaceCard(
      onTap: open,
      padding: const EdgeInsets.all(DsSpacing.sm),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: DsRadius.borderMd,
            child: SizedBox(
              width: DsSizes.thumbSm,
              height: DsSizes.thumbMd,
              child: ClosetPhoto(
                url: url,
                slot: piece.slot,
                width: DsSizes.thumbSm,
                iconSize: DsSizes.iconMd,
              ),
            ),
          ),
          DsGaps.hSm,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      ClosetSlotStyle.icon(piece.slot),
                      size: DsSizes.iconXxs,
                      color: colors.onSurfaceVariant,
                    ),
                    DsGaps.hXxs,
                    Text(piece.slotLabel, style: text.caption),
                  ],
                ),
                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: text.tileTitle,
                ),
                if (piece.isWanted) ...[
                  DsGaps.vXxs,
                  ClosetPill(
                    label: context.l10n.closetNotOwnedYet,
                    icon: Icons.shopping_bag_outlined,
                    tone: DsTone.caution,
                  ),
                ],
                if (gap != null) ...[
                  DsGaps.vXs,
                  DsButton(
                    label: context.l10n.closetFindThePiece,
                    icon: Icons.search_rounded,
                    size: DsButtonSize.sm,
                    variant: DsButtonVariant.tonal,
                    isExpanded: false,
                    onPressed: () =>
                        context.push(RoutePaths.closetGapOf(gap!.id)),
                  ),
                ],
              ],
            ),
          ),
          if (onRemove != null)
            IconButton(
              tooltip: context.l10n.closetRemoveFromLook,
              icon: const Icon(Icons.close_rounded, size: DsSizes.iconSm),
              onPressed: onRemove,
            ),
        ],
      ),
    );
  }
}
