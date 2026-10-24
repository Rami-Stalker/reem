import 'package:flutter/material.dart';

import 'package:ohara/core/design_system/design_system.dart';
import 'package:ohara/core/localization/l10n_extension.dart';
import 'package:ohara/core/shared/entities/product.dart';

/// Category, name, rating and the social counts — the top of the page body.
///
/// Everything here is the product's own. It replaces a block that read
/// "Dresses · New in / Elegant Silk Midi Dress / ★★★★★ 4.9 (2.4k reviews)"
/// for every item in the catalogue.
class ProductHeadline extends StatelessWidget {
  const ProductHeadline({super.key, required this.product});

  final Product product;

  @override
  Widget build(BuildContext context) {
    final text = context.dsText;
    final colors = context.dsColors;
    final l10n = context.l10n;

    final arabic = context.isArabic;
    final eyebrow = [
      product.category.name(arabic: arabic),
      if (product.brand != null) product.brand!.name(arabic: arabic),
    ].join(' · ');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (eyebrow.isNotEmpty) Text(eyebrow, style: text.overline),
        DsGaps.vXs,
        Text(product.title, style: text.pageTitle),
        if (product.rating > 0 || product.reviewsCount > 0) ...[
          DsGaps.vSm,
          Row(
            children: [
              _Stars(rating: product.rating),
              DsGaps.hXs,
              Text(
                l10n.productRatingSummary(
                  product.rating.toStringAsFixed(1),
                  product.reviewsCount,
                ),
                style: text.caption,
              ),
            ],
          ),
        ],
        DsGaps.vSm,
        Wrap(
          spacing: DsSpacing.md,
          runSpacing: DsSpacing.xs,
          children: [
            // Saves, views and purchases — each one a count of rows the
            // platform actually holds. A fourth figure used to lead this row,
            // `likesCount`, which nothing on the platform ever incremented.
            _Stat(
              icon: DsIcons.likeFilled,
              value: product.favoritesCount,
              tint: colors.favorite,
            ),
            _Stat(
              icon: Icons.visibility_rounded,
              value: product.viewsCount,
              tint: colors.onSurfaceVariant,
            ),
            _Stat(
              icon: DsIcons.cart,
              value: product.ordersCount,
              tint: colors.primary,
            ),
          ],
        ),
      ],
    );
  }
}

class _Stars extends StatelessWidget {
  const _Stars({required this.rating});

  final double rating;

  @override
  Widget build(BuildContext context) {
    final colors = context.dsColors;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 1; i <= 5; i++)
          Icon(
            // Half a star is drawn as a half-filled glyph so a 4.5 does not
            // round up into a promise the product has not earned.
            rating >= i
                ? DsIcons.star
                : rating >= i - 0.5
                    ? Icons.star_half_rounded
                    : DsIcons.starOutline,
            size: DsSizes.iconXs,
            color: colors.rating,
          ),
      ],
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.icon, required this.value, required this.tint});

  final IconData icon;
  final int value;
  final Color tint;

  @override
  Widget build(BuildContext context) {
    if (value <= 0) return const SizedBox.shrink();
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: DsSizes.iconXs, color: tint),
        DsGaps.hXxs,
        Text(
          _compact(value),
          style: context.dsText.caption.semibold.tint(tint),
        ),
      ],
    );
  }

  /// 1.2k rather than 1234 — the exact figure is noise next to a heart.
  static String _compact(int value) {
    if (value >= 1000000) {
      return '${(value / 1000000).toStringAsFixed(1)}M';
    }
    if (value >= 1000) return '${(value / 1000).toStringAsFixed(1)}k';
    return '$value';
  }
}
