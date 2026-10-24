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
    final attributes = product.attributes.entries
        .where((e) => e.value != null && '${e.value}'.trim().isNotEmpty)
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
                for (final entry in attributes)
                  Padding(
                    padding:
                        const EdgeInsets.symmetric(vertical: DsSpacing.xxs),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: DsSizes.thumbLg,
                          child: Text(entry.key, style: text.caption),
                        ),
                        DsGaps.hSm,
                        Expanded(
                          child: Text('${entry.value}', style: text.bodySmall),
                        ),
                      ],
                    ),
                  ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
