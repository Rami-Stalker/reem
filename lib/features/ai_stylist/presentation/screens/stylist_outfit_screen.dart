import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ohara/core/design_system/design_system.dart';
import 'package:ohara/core/localization/l10n_extension.dart';
import 'package:ohara/core/media/authorized_media_image.dart';
import 'package:ohara/core/media/media_variants.dart';
import 'package:ohara/core/router/route_paths.dart';
import 'package:ohara/features/ai_stylist/domain/entities/stylist_outfit.dart';
import 'package:ohara/features/ai_stylist/presentation/providers/ai_stylist_providers.dart';

/// One look, full screen.
///
/// Laid out as a vertical list of slots rather than the compact board used
/// inside the chat: here she is deciding what to actually buy, so each piece
/// gets its price, its seller, and its own reason.
class StylistOutfitScreen extends ConsumerWidget {
  const StylistOutfitScreen({super.key, required this.outfitId});

  final String outfitId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.dsColors;
    final outfitAsync = ref.watch(stylistOutfitProvider(outfitId));

    return Scaffold(
      backgroundColor: colors.background,
      appBar: OharaAppBar(title: context.l10n.stylistOutfitTitle),
      body: outfitAsync.when(
        loading: () => const Center(child: DsLoadingIndicator()),
        error: (_, _) => DsErrorState(
          message: context.l10n.stylistLookFailed,
          onRetry: () => ref.invalidate(stylistOutfitProvider(outfitId)),
        ),
        data: (outfit) => _OutfitBody(outfit: outfit),
      ),
    );
  }
}

class _OutfitBody extends ConsumerWidget {
  const _OutfitBody({required this.outfit});

  final StylistOutfit outfit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.dsColors;
    final actions = ref.read(stylistActionsProvider);

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(DsSpacing.md),
            children: [
              Text(
                outfit.title,
                style: context.dsText.screenTitle.bold.tint(colors.onSurface),
              ),
              if (outfit.occasionLabel != null) ...[
                const SizedBox(height: DsSpacing.xxs),
                Text(
                  outfit.occasionLabel!,
                  style: context.dsText.body.tint(colors.primary),
                ),
              ],
              if (outfit.note != null && outfit.note!.isNotEmpty) ...[
                const SizedBox(height: DsSpacing.sm),
                Text(
                  outfit.note!,
                  style: context.dsText.body.tint(colors.onSurfaceVariant).copyWith(height: 1.65),
                ),
              ],
              const SizedBox(height: DsSpacing.lg),
              for (final piece in outfit.items) ...[
                _PieceRow(piece: piece),
                const SizedBox(height: DsSpacing.sm),
              ],
              // Stated rather than hidden: a saved look outlives the offers it
              // was built from, and she should know which piece went away
              // before she plans an outfit around it.
              if (!outfit.isComplete) ...[
                const SizedBox(height: DsSpacing.xs),
                Row(
                  children: [
                    Icon(
                      Icons.info_outline_rounded,
                      size: 15,
                      color: colors.warning,
                    ),
                    const SizedBox(width: DsSpacing.xs),
                    Expanded(
                      child: Text(
                        context.l10n.stylistLookPartlyUnavailable,
                        style: context.dsText.labelMedium
                            .tint(colors.onSurfaceVariant)
                            .copyWith(height: 1.5),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
        _Footer(outfit: outfit, actions: actions),
      ],
    );
  }
}

class _PieceRow extends StatelessWidget {
  const _PieceRow({required this.piece});

  final OutfitPiece piece;

  @override
  Widget build(BuildContext context) {
    final colors = context.dsColors;
    final product = piece.product;
    // Null for a piece whose product has been withdrawn — the row still draws,
    // saying «لم تعد متوفرة», and there is nothing to like.
    final action = product == null
        ? null
        : DsProductActions.of(context, product, DsProductSurface.rail);

    return Material(
      color: colors.card,
      borderRadius: BorderRadius.circular(DsRadius.lg),
      child: InkWell(
        borderRadius: BorderRadius.circular(DsRadius.lg),
        onTap: product == null
            ? null
            : () => context.push(RoutePaths.productDetailsOf(product.id)),
        child: Padding(
          padding: const EdgeInsets.all(DsSpacing.sm),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(DsRadius.md),
                child: SizedBox(
                  width: 76,
                  height: 76,
                  child: product?.coverUrl != null
                      ? AuthorizedMediaImage(
                          url: product!.coverUrl!,
                          blurHash: product.coverBlurHash,
                          variantWidth: MediaVariants.thumbnail,
                        )
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
              const SizedBox(width: DsSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      piece.slotLabel,
                      style: context.dsText.caption.semibold.tint(colors.primary),
                    ),
                    Text(
                      product?.title ?? context.l10n.stylistNoLongerAvailable,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: context.dsText.body.semibold.tint(colors.onSurface).copyWith(height: 1.35),
                    ),
                    if (product?.displaySeller != null)
                      Text(
                        product!.displaySeller!.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.dsText.caption.tint(colors.onSurfaceVariant),
                      ),
                    if (piece.reason != null && piece.reason!.isNotEmpty) ...[
                      const SizedBox(height: DsSpacing.xxs),
                      Text(
                        piece.reason!,
                        style: context.dsText.caption.tint(colors.onSurfaceVariant).copyWith(height: 1.45),
                      ),
                    ],
                  ],
                ),
              ),
              if (piece.price != null) ...[
                const SizedBox(width: DsSpacing.xs),
                Text(
                  piece.price!.format(),
                  style: context.dsText.labelLarge.bold.tint(colors.primary),
                ),
              ],
              // «التنسيقات» were named by the client as a surface that must
              // carry the interactions, and this row had none: an outfit was
              // the one place she could be shown six pieces and not be able to
              // say she liked one of them.
              if (action != null) ...[
                const SizedBox(width: DsSpacing.xs),
                action,
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _Footer extends StatelessWidget {
  const _Footer({required this.outfit, required this.actions});

  final StylistOutfit outfit;
  final StylistActions actions;

  @override
  Widget build(BuildContext context) {
    final colors = context.dsColors;

    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(top: BorderSide(color: colors.divider)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(DsSpacing.md),
          child: Row(
            children: [
              if (outfit.total != null)
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        context.l10n.stylistTotal,
                        style: context.dsText.caption.tint(
                          colors.onSurfaceVariant,
                        ),
                      ),
                      Text(
                        outfit.total!.format(),
                        style: context.dsText.cardTitle.bold.tint(colors.primary),
                      ),
                    ],
                  ),
                )
              else
                const Spacer(),
              const SizedBox(width: DsSpacing.sm),
              PrimaryButton(
                isExpanded: false,
                label: outfit.isSaved
                    ? context.l10n.stylistLookSaved
                    : context.l10n.stylistSaveLook,
                onPressed: outfit.isSaved
                    ? null
                    : () async {
                        final saved = await actions.setOutfitStatus(
                          outfit.id,
                          StylistOutfitStatus.saved,
                        );
                        if (!context.mounted) return;
                        DsSnackbar.show(
                          context,
                          message: saved
                              ? context.l10n.stylistLookSavedToCloset
                              : context.l10n.stylistLookSaveFailed,
                          type: saved
                              ? DsSnackbarType.success
                              : DsSnackbarType.error,
                        );
                      },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
