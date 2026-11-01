import 'package:flutter/material.dart';

import 'package:ohara/core/design_system/design_system.dart';
import 'package:ohara/core/localization/l10n_extension.dart';
import 'package:ohara/core/shared/entities/product.dart';

/// The product's description and its specification table.
///
/// Replaces a block of lorem-style filler with the product's own copy, and
/// surfaces `Product.attributes` — الخامة، طول الكم، درجة اللون — which the
/// serializer has always sent and no screen ever showed.
class ProductDetailBody extends StatefulWidget {
  const ProductDetailBody({super.key, required this.product});

  final Product product;

  @override
  State<ProductDetailBody> createState() => _ProductDetailBodyState();
}

class _ProductDetailBodyState extends State<ProductDetailBody> {
  bool _expanded = false;

  /// Long copy is folded so the page below stays reachable; four lines is
  /// enough to judge whether the rest is worth opening.
  static const int _collapsedLines = 4;

  @override
  Widget build(BuildContext context) {
    final text = context.dsText;
    final l10n = context.l10n;
    final product = widget.product;
    final attributes = _ordered(product)
        .where((e) => _valueText(context, e.value).isNotEmpty)
        .toList();

    if (product.description.trim().isEmpty && attributes.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.productDetailsSection, style: text.sectionTitle),
        DsGaps.vSm,
        SurfaceCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (product.description.trim().isNotEmpty) ...[
                AnimatedSize(
                  duration: DsMotion.normal,
                  curve: DsMotion.gentle,
                  alignment: Alignment.topCenter,
                  child: Text(
                    product.description,
                    maxLines: _expanded ? null : _collapsedLines,
                    overflow: _expanded ? null : TextOverflow.ellipsis,
                    style: text.body,
                  ),
                ),
                DsGaps.vXs,
                GestureDetector(
                  onTap: () => setState(() => _expanded = !_expanded),
                  child: Text(
                    _expanded ? l10n.showLess : l10n.showMore,
                    style: text.link,
                  ),
                ),
              ],
              if (attributes.isNotEmpty) ...[
                if (product.description.trim().isNotEmpty) ...[
                  DsGaps.vSm,
                  Divider(color: context.dsColors.divider, height: 1),
                  DsGaps.vSm,
                ],
                for (var i = 0; i < attributes.length; i++) ...[
                  if (i > 0)
                    Divider(
                      color: context.dsColors.divider.withValues(alpha: 0.5),
                      height: DsSpacing.md,
                    ),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 2,
                        child: Text(
                          _label(context, product, attributes[i].key),
                          style: text.caption.tint(
                            context.dsColors.onSurfaceVariant,
                          ),
                        ),
                      ),
                      DsGaps.hSm,
                      Expanded(
                        flex: 3,
                        child: Text(
                          _valueText(context, attributes[i].value),
                          style: text.bodySmall.semibold,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ],
          ),
        ),
      ],
    );
  }

  /// The schema's order — what a category lists first is what matters most
  /// about it — then anything the schema does not name.
  static List<MapEntry<String, dynamic>> _ordered(Product product) {
    final keys = [
      for (final key in product.attributeLabels.keys)
        if (product.attributes.containsKey(key)) key,
      for (final key in product.attributes.keys)
        if (!product.attributeLabels.containsKey(key)) key,
    ];
    return [for (final key in keys) MapEntry(key, product.attributes[key])];
  }

  /// What a specification is called, in the reader's language.
  ///
  /// The category schema's own title first — an admin can add any attribute
  /// and name it. Then the app's names for the common ones, for a payload that
  /// carried no titles. Never the raw key: «material» and «sleeve_length» on
  /// an Arabic page is what this replaced.
  static String _label(BuildContext context, Product product, String key) {
    final fromSchema = product.attributeLabels[key];
    if (fromSchema != null && fromSchema.isNotEmpty) return fromSchema;
    final l10n = context.l10n;
    return switch (key) {
      'material' || 'fabric' => l10n.productAttrMaterial,
      'sleeve_length' => l10n.productAttrSleeveLength,
      'skin_type' => l10n.productAttrSkinType,
      'color' || 'colour' => l10n.productAttrColor,
      'fit' => l10n.productAttrFit,
      'length' => l10n.productAttrLength,
      'pattern' => l10n.productAttrPattern,
      'care' => l10n.productAttrCare,
      'origin' || 'made_in' => l10n.productAttrOrigin,
      // An unnamed key, made readable rather than shown as code.
      _ => key.replaceAll('_', ' '),
    };
  }

  /// A value as a sentence: a list joined, a yes/no said in words.
  static String _valueText(BuildContext context, Object? value) => switch (value) {
    null => '',
    true => context.l10n.productAttrYes,
    false => context.l10n.productAttrNo,
    final List<dynamic> list => list
        .map((item) => '$item'.trim())
        .where((item) => item.isNotEmpty)
        .join('، '),
    _ => '$value'.trim(),
  };
}
