import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:reem/core/design_system/design_system.dart';
import 'package:reem/core/localization/l10n_extension.dart';
import 'package:reem/core/media/media_variants.dart';
import 'package:reem/features/social/domain/entities/content_draft.dart';

/// What she may tag, and what she may not.
///
/// A shopper sees the pieces actually delivered to her; a boutique sees its
/// live listings. The server decides which — and the ineligible are shown
/// greyed with a reason rather than hidden, because a picker that omits a
/// dress she is holding is a bug report, and one that explains itself is an
/// answer.
class ProductTagPicker extends StatelessWidget {
  const ProductTagPicker({
    super.key,
    required this.products,
    required this.selected,
    required this.onToggle,
  });

  final List<TaggableProduct> products;
  final List<String> selected;
  final ValueChanged<String> onToggle;

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(context.l10n.composerTagProducts, style: context.dsText.labelLarge),
        DsGaps.vXxs,
        Text(
          context.l10n.composerTagProductsHelp,
          style: context.dsText.caption.tint(c.onSurfaceVariant),
        ),
        DsGaps.vSm,
        if (products.isEmpty)
          // Not an error. A woman who has not received an order yet simply has
          // nothing to tag, and saying so is kinder than an empty box.
          Text(
            context.l10n.composerTagProductsEmpty,
            style: context.dsText.caption.tint(c.onSurfaceVariant),
          )
        else
          SizedBox(
            height: 132,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: products.length,
              separatorBuilder: (_, _) => DsGaps.hSm,
              itemBuilder: (context, index) {
                final product = products[index];
                return _ProductTile(
                  product: product,
                  isSelected: selected.contains(product.productId),
                  onTap: product.eligible
                      ? () => onToggle(product.productId)
                      : null,
                );
              },
            ),
          ),
      ],
    );
  }
}

class _ProductTile extends StatelessWidget {
  const _ProductTile({
    required this.product,
    required this.isSelected,
    this.onTap,
  });

  final TaggableProduct product;
  final bool isSelected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    final image = product.imageUrl;

    return Semantics(
      button: onTap != null,
      selected: isSelected,
      label: product.title,
      child: GestureDetector(
        onTap: onTap,
        child: Opacity(
          opacity: product.eligible ? 1 : 0.45,
          child: SizedBox(
            width: 96,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(DsRadius.md),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        if (image != null && image.isNotEmpty)
                          CachedNetworkImage(
                            imageUrl: MediaVariants.thumb(image),
                            fit: BoxFit.cover,
                            placeholder: (_, _) =>
                                ColoredBox(color: c.shimmerBase),
                            errorWidget: (_, _, _) => const DsMediaFallback(),
                          )
                        else
                          const DsMediaFallback(),
                        if (isSelected)
                          DecoratedBox(
                            decoration: BoxDecoration(
                              color: c.primary.withValues(alpha: 0.35),
                              border: Border.all(color: c.primary, width: 2),
                              borderRadius: BorderRadius.circular(DsRadius.md),
                            ),
                            child: Icon(
                              Icons.check_circle_rounded,
                              color: DsColors.onMedia,
                              size: DsSizes.iconMd,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                DsGaps.vXxs,
                Text(
                  product.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: context.dsText.micro,
                ),
                if (!product.eligible && product.reason != null)
                  Text(
                    product.reason!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.dsText.micro.tint(c.onSurfaceVariant),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
