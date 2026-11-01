import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:ohara/core/design_system/design_system.dart';
import 'package:ohara/core/localization/l10n_extension.dart';
import 'package:ohara/core/router/route_paths.dart';
import 'package:ohara/core/shared/entities/product.dart';

/// «القطع بهالمنشور» — every piece tagged in a post, reel or story.
///
/// A post can carry several pieces, but only the first ever reached the
/// screen: the others were saved, sent back by the server, and then dropped.
/// The ticket shows the first and a «+N» that opens this list.
abstract final class TaggedPiecesSheet {
  /// [onOpen] decides what picking a piece does once the sheet has closed;
  /// by default the piece's page is pushed. The story viewer passes its own,
  /// so the story closes first instead of playing on behind the page.
  static Future<void> show(
    BuildContext context,
    List<Product> products, {
    ValueChanged<Product>? onOpen,
  }) {
    // Read when a piece is picked, not when the sheet opens.
    final router = GoRouter.maybeOf(context);
    return DsBottomSheet.showTitled<void>(
      context,
      title: context.l10n.postTaggedPiecesTitle,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final (index, product) in products.indexed) ...[
            if (index > 0) DsGaps.vSm,
            _PieceRow(
              product: product,
              onTap: () {
                Navigator.of(context, rootNavigator: true).pop();
                if (onOpen != null) {
                  onOpen(product);
                } else {
                  router?.push(RoutePaths.productDetailsOf(product.id));
                }
              },
            ),
          ],
        ],
      ),
    );
  }
}

class _PieceRow extends StatelessWidget {
  const _PieceRow({required this.product, required this.onTap});

  final Product product;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.dsColors;
    final image = product.media.isEmpty ? null : product.media.first;
    return Material(
      color: colors.surface,
      borderRadius: DsRadius.borderLg,
      child: InkWell(
        borderRadius: DsRadius.borderLg,
        onTap: onTap,
        child: Padding(
          padding: DsSpacing.paddingSm,
          child: Row(
            children: [
              ClipRRect(
                borderRadius: DsRadius.borderMd,
                child: SizedBox.square(
                  dimension: DsSizes.thumbMd,
                  child: image == null
                      ? const DsMediaFallback()
                      : DsMediaFrame(item: image),
                ),
              ),
              DsGaps.hMd,
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: context.dsText.bodyStrong,
                    ),
                    if (product.price case final price?) ...[
                      DsGaps.vXxs,
                      Text(
                        price.format(),
                        style: context.dsText.bodySmall.tint(colors.price),
                      ),
                    ],
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: DsSizes.iconXs,
                color: colors.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// «+2 قطع» over a reel or a story — the way to the rest of the pieces when
/// the plate shows only the first.
class MorePiecesChip extends StatelessWidget {
  const MorePiecesChip({super.key, required this.products});

  /// Every tagged piece; the chip counts those beyond the first.
  final List<Product> products;

  @override
  Widget build(BuildContext context) {
    if (products.length < 2) return const SizedBox.shrink();
    return Semantics(
      button: true,
      label: context.l10n.postTaggedPiecesTitle,
      child: GestureDetector(
        onTap: () => TaggedPiecesSheet.show(context, products),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: DsSpacing.sm,
            vertical: DsSpacing.xs,
          ),
          decoration: BoxDecoration(
            color: DsColors.white.withValues(alpha: 0.22),
            borderRadius: DsRadius.borderFull,
            border: Border.all(color: DsColors.white.withValues(alpha: 0.4)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.shopping_bag_outlined,
                size: DsSizes.iconXs,
                color: DsColors.onMedia,
              ),
              DsGaps.hXxs,
              Text(
                context.l10n.postMorePieces(products.length - 1),
                style: context.dsText.labelStrong.tint(DsColors.onMedia),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
