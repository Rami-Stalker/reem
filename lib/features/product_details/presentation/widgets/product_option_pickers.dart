import 'package:flutter/material.dart';

import 'package:reem/core/design_system/design_system.dart';
import 'package:reem/core/localization/l10n_extension.dart';
import 'package:reem/core/shared/entities/product_variant.dart';
import 'package:reem/core/shared/entities/seller_offer.dart';

/// Pickers for the choices a product actually offers.
///
/// The page previously carried a `ProductSizeSelector` hard-coded to
/// XS–XL and a `ProductColorSelector` hard-coded to four Material swatches,
/// neither of which was connected to the catalogue. A Reem product carries
/// [OfferVariant]s whose `attributes` map holds the real axes — المقاس,
/// اللون, الحجم — so the picker is generated from them and a product with no
/// options renders nothing at all.
class ProductVariantPicker extends StatelessWidget {
  const ProductVariantPicker({
    super.key,
    required this.variants,
    required this.selected,
    required this.onSelect,
  });

  final List<OfferVariant> variants;
  final OfferVariant? selected;
  final ValueChanged<OfferVariant> onSelect;

  @override
  Widget build(BuildContext context) {
    if (variants.length < 2) return const SizedBox.shrink();

    final l10n = context.l10n;
    // Variants name their own axis when they have exactly one attribute;
    // anything richer falls back to the variant's own display name.
    final axes = <String>{
      for (final v in variants) ...v.attributes.keys,
    };
    final axisLabel = axes.length == 1 ? axes.first : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          axisLabel != null
              ? l10n.productChooseOption(axisLabel)
              : l10n.formVariantsTitle,
          style: context.dsText.sectionTitle,
        ),
        DsGaps.vSm,
        Wrap(
          spacing: DsSpacing.xs,
          runSpacing: DsSpacing.xs,
          children: [
            for (final variant in variants)
              DsChip(
                label: _label(variant, axisLabel),
                selected: selected?.id == variant.id,
                enabled: variant.inStock,
                onTap: variant.inStock ? () => onSelect(variant) : null,
              ),
          ],
        ),
      ],
    );
  }

  static String _label(OfferVariant variant, String? axis) {
    if (axis != null) {
      final value = variant.attributes[axis];
      if (value != null) return '$value';
    }
    return variant.name;
  }
}

/// Which boutique she is buying from.
///
/// One catalogue entry can carry several sellers' offers at different prices,
/// which is the whole point of the shared catalogue. Until now the page always
/// silently used the cheapest; this makes the choice hers.
class ProductOfferPicker extends StatelessWidget {
  const ProductOfferPicker({
    super.key,
    required this.offers,
    required this.selected,
    required this.onSelect,
  });

  final List<SellerOffer> offers;
  final SellerOffer? selected;
  final ValueChanged<SellerOffer> onSelect;

  @override
  Widget build(BuildContext context) {
    if (offers.length < 2) return const SizedBox.shrink();

    final text = context.dsText;
    final colors = context.dsColors;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(context.l10n.productChooseSeller, style: text.sectionTitle),
        DsGaps.vSm,
        for (final offer in offers) ...[
          SurfaceCard(
            onTap: offer.isBuyable ? () => onSelect(offer) : null,
            child: Row(
              children: [
                DsAvatar(
                  imageUrl: offer.seller.imageUrl,
                  name: offer.seller.name,
                  size: DsSizes.avatarSm,
                ),
                DsGaps.hSm,
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        offer.seller.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: text.cardTitle,
                      ),
                      Text(
                        offer.isBuyable
                            ? context.l10n.inStock
                            : context.l10n.outOfStock,
                        style: text.caption.tint(
                          offer.isBuyable ? colors.success : colors.error,
                        ),
                      ),
                    ],
                  ),
                ),
                DsGaps.hSm,
                Text(offer.price.format(), style: text.price.tabular),
                DsGaps.hXs,
                Icon(
                  selected?.id == offer.id
                      ? Icons.radio_button_checked_rounded
                      : Icons.radio_button_unchecked_rounded,
                  size: DsSizes.iconSm,
                  color: selected?.id == offer.id
                      ? colors.primary
                      : colors.onSurfaceVariant,
                ),
              ],
            ),
          ),
          DsGaps.vXs,
        ],
      ],
    );
  }
}

/// How many, bounded by what the selected seller can actually ship.
class ProductQuantityPicker extends StatelessWidget {
  const ProductQuantityPicker({
    super.key,
    required this.quantity,
    required this.min,
    required this.max,
    required this.onChanged,
  });

  final int quantity;
  final int min;
  final int max;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final text = context.dsText;
    final colors = context.dsColors;
    final canDecrement = quantity > min;
    final canIncrement = quantity < max;

    return SurfaceCard(
      child: Row(
        children: [
          Expanded(
            child: Text(context.l10n.quantity, style: text.cardTitle),
          ),
          Container(
            decoration: BoxDecoration(
              color: colors.surfaceVariant,
              borderRadius: DsRadius.borderFull,
              border: Border.all(color: colors.border),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  tooltip: 'إنقاص الكمية',
                  visualDensity: VisualDensity.compact,
                  iconSize: DsSizes.iconXs,
                  icon: Icon(
                    Icons.remove_rounded,
                    color: canDecrement ? colors.primary : colors.disabled,
                  ),
                  onPressed:
                      canDecrement ? () => onChanged(quantity - 1) : null,
                ),
                SizedBox(
                  width: DsSizes.iconLg,
                  child: Center(
                    child: Text('$quantity', style: text.labelStrong.tabular),
                  ),
                ),
                IconButton(
                  tooltip: 'زيادة الكمية',
                  visualDensity: VisualDensity.compact,
                  iconSize: DsSizes.iconXs,
                  icon: Icon(
                    Icons.add_rounded,
                    color: canIncrement ? colors.primary : colors.disabled,
                  ),
                  onPressed:
                      canIncrement ? () => onChanged(quantity + 1) : null,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
