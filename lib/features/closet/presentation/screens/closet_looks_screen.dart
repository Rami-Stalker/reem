import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:reem/core/design_system/design_system.dart';
import 'package:reem/core/localization/l10n_extension.dart';
import 'package:reem/core/media/authorized_media_image.dart';
import 'package:reem/core/router/route_paths.dart';
import 'package:reem/features/closet/domain/entities/closet_look.dart';
import 'package:reem/features/closet/presentation/providers/closet_providers.dart';

/// إطلالاتي — the looks she has composed.
class ClosetLooksScreen extends ConsumerWidget {
  const ClosetLooksScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.dsColors;
    final looksAsync = ref.watch(closetLooksProvider(null));

    return Scaffold(
      backgroundColor: colors.background,
      appBar: ReemAppBar(title: context.l10n.closetMyLooks),
      body: looksAsync.when(
        loading: () => const Center(child: DsLoadingIndicator()),
        error: (_, _) => DsErrorState(
          message: context.l10n.closetLooksLoadFailed,
          onRetry: () => ref.invalidate(closetLooksProvider),
        ),
        data: (looks) => looks.isEmpty
            ? DsEmptyState(
                icon: Icons.auto_awesome_rounded,
                title: context.l10n.closetNoLooksTitle,
                message: context.l10n.closetNoLooksBody,
                actionLabel: context.l10n.closetSeeWhatToWear,
                onAction: () => context.push(RoutePaths.closetToday),
              )
            : ListView.separated(
                padding: const EdgeInsets.all(DsSpacing.md),
                itemCount: looks.length,
                separatorBuilder: (_, _) =>
                    const SizedBox(height: DsSpacing.sm),
                itemBuilder: (context, index) => ClosetLookCard(
                  look: looks[index],
                  onTap: () =>
                      context.push(RoutePaths.closetLookOf(looks[index].id)),
                  onWear: () => ref
                      .read(closetActionsProvider)
                      .logLookWear(looks[index].id),
                ),
              ),
      ),
    );
  }
}

/// A look, with its gap made visible.
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

    return SurfaceCard(
      onTap: onTap,
      padding: const EdgeInsets.all(DsSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  look.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.dsText.cardTitle,
                ),
              ),
              if (look.isFavourite)
                Icon(Icons.favorite_rounded, size: 16, color: colors.favorite),
              if (look.occasionLabel != null) ...[
                const SizedBox(width: DsSpacing.xs),
                Text(
                  look.occasionLabel!,
                  style: context.dsText.caption.tint(colors.primary),
                ),
              ],
            ],
          ),
          const SizedBox(height: DsSpacing.sm),
          SizedBox(
            height: 72,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: look.pieces.length,
              separatorBuilder: (_, _) => const SizedBox(width: DsSpacing.xs),
              itemBuilder: (context, index) =>
                  _PieceThumb(piece: look.pieces[index]),
            ),
          ),
          const SizedBox(height: DsSpacing.sm),
          if (look.isComplete)
            Row(
              children: [
                Icon(
                  Icons.check_circle_rounded,
                  size: 16,
                  color: colors.success,
                ),
                DsGaps.hXxs,
                Expanded(
                  child: Text(
                    look.wearCount > 0
                        ? context.l10n.closetLookReadyWorn(look.wearCount)
                        : context.l10n.closetLookReady,
                    style: context.dsText.caption,
                  ),
                ),
                if (onWear != null)
                  TextButton(
                    onPressed: onWear,
                    child: Text(context.l10n.closetWoreIt),
                  ),
              ],
            )
          else
            Row(
              children: [
                Icon(
                  Icons.add_circle_outline_rounded,
                  size: 16,
                  color: colors.warning,
                ),
                DsGaps.hXxs,
                Expanded(
                  child: Text(
                    look.isOnePieceShort
                        ? context.l10n.closetLookShortOne(
                            look.missingSlots.first.label,
                          )
                        : context.l10n.closetLookShortMany(
                            look.missingSlots.length,
                          ),
                    style: context.dsText.caption.tint(colors.warning),
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
  const _PieceThumb({required this.piece});

  final LookPiece piece;

  @override
  Widget build(BuildContext context) {
    final colors = context.dsColors;
    final url = piece.owned?.imageUrl ?? piece.product?.coverUrl;

    return SizedBox(
      width: 56,
      height: 72,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(DsRadius.sm),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (url == null || url.isEmpty)
              Container(
                color: colors.surfaceVariant,
                alignment: Alignment.center,
                child: Icon(
                  Icons.checkroom_rounded,
                  size: 18,
                  color: colors.onSurfaceVariant,
                ),
              )
            else
              AuthorizedMediaImage(
                url: url,
                fallback: Container(color: colors.surfaceVariant),
              ),
            // A wanted piece is marked, always. Without it a look reads as
            // finished when a third of it is still in a shop.
            if (piece.isWanted)
              Align(
                alignment: Alignment.bottomCenter,
                child: Container(
                  width: double.infinity,
                  color: colors.warning.withValues(alpha: 0.9),
                  padding: const EdgeInsets.symmetric(vertical: 1),
                  child: Text(
                    context.l10n.closetMissing,
                    textAlign: TextAlign.center,
                    style: context.dsText.micro.tint(colors.onWarning),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
