import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:reem/core/design_system/design_system.dart';
import 'package:reem/core/router/route_paths.dart';
import 'package:reem/features/closet/domain/entities/closet_gap.dart';
import 'package:reem/features/closet/domain/entities/closet_look.dart';
import 'package:reem/features/closet/domain/repositories/closet_repository.dart';
import 'package:reem/features/closet/presentation/providers/closet_providers.dart';

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
      appBar: ReemAppBar(
        title: 'الإطلالة',
        actions: [
          lookAsync.maybeWhen(
            data: (look) => IconButton(
              icon: Icon(
                look.isFavourite
                    ? Icons.favorite_rounded
                    : Icons.favorite_outline_rounded,
                color: look.isFavourite ? colors.favorite : null,
              ),
              onPressed: () => ref.read(closetActionsProvider).updateLook(
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
          message: 'ما قدرنا نفتح الإطلالة.',
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
    final colors = context.dsColors;
    final gapsAsync = ref.watch(closetGapsProvider);

    return ListView(
      padding: const EdgeInsets.all(DsSpacing.md),
      children: [
        Text(look.title, style: context.dsText.pageTitle),
        if (look.occasionLabel != null)
          Text(look.occasionLabel!, style: context.dsText.bodyMuted),
        if (look.note != null && look.note!.isNotEmpty) ...[
          const SizedBox(height: DsSpacing.xs),
          Text(look.note!, style: context.dsText.body),
        ],
        const SizedBox(height: DsSpacing.md),

        for (final piece in look.pieces) ...[
          _PieceRow(
            piece: piece,
            gap: gapsAsync.maybeWhen(
              data: (gaps) => _gapFor(gaps, piece),
              orElse: () => null,
            ),
            onRemove: () => _removeSlot(ref, piece),
          ),
          const SizedBox(height: DsSpacing.xs),
        ],

        const SizedBox(height: DsSpacing.lg),
        if (look.isComplete)
          DsButton(
            label: 'لبستها اليوم',
            onPressed: () =>
                ref.read(closetActionsProvider).logLookWear(look.id),
          )
        else
          Container(
            padding: const EdgeInsets.all(DsSpacing.md),
            decoration: BoxDecoration(
              color: colors.warningContainer,
              borderRadius: BorderRadius.circular(DsRadius.card),
            ),
            child: Text(
              look.isOnePieceShort
                  ? 'قطعة وحدة (${look.missingSlots.first.label}) وبتصير جاهزة.'
                  : 'ناقصها ${look.missingSlots.length} قطع لتصير جاهزة.',
              style: context.dsText.body,
            ),
          ),

        const SizedBox(height: DsSpacing.md),
        if (look.wearCount > 0)
          Text(
            'لبستيها ${look.wearCount} مرة.',
            style: context.dsText.caption,
          ),

        const SizedBox(height: DsSpacing.lg),
        TextButton(
          onPressed: () => _delete(context, ref),
          child: Text('احذفي الإطلالة', style: TextStyle(color: colors.error)),
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

  Future<void> _removeSlot(WidgetRef ref, LookPiece piece) async {
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

    await ref.read(closetActionsProvider).setLookItems(look.id, remaining);
  }

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    await ref.read(closetActionsProvider).removeLook(look.id);
    if (!context.mounted) return;
    context.pop();
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
    final url = piece.owned?.imageUrl ?? piece.product?.coverUrl;
    final title = piece.owned?.title ?? piece.product?.title ?? piece.slotLabel;

    return SurfaceCard(
      padding: const EdgeInsets.all(DsSpacing.sm),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(DsRadius.sm),
            child: SizedBox(
              width: 56,
              height: 68,
              child: url == null || url.isEmpty
                  ? Container(
                      color: colors.surfaceVariant,
                      alignment: Alignment.center,
                      child: Icon(
                        Icons.checkroom_rounded,
                        color: colors.onSurfaceVariant,
                      ),
                    )
                  : Image.network(
                      url,
                      fit: BoxFit.cover,
                      errorBuilder: (context, _, _) =>
                          Container(color: colors.surfaceVariant),
                    ),
            ),
          ),
          const SizedBox(width: DsSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(piece.slotLabel, style: context.dsText.caption),
                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: context.dsText.tileTitle,
                ),
                if (piece.isWanted) ...[
                  const SizedBox(height: 2),
                  Text(
                    'لسا مو عندك',
                    style: context.dsText.caption.tint(colors.warning),
                  ),
                ],
                if (gap != null) ...[
                  const SizedBox(height: DsSpacing.xs),
                  DsButton(
                    label: 'لاقي القطعة',
                    size: DsButtonSize.sm,
                    variant: DsButtonVariant.secondary,
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
              icon: const Icon(Icons.close_rounded, size: 18),
              onPressed: onRemove,
            ),
        ],
      ),
    );
  }
}
