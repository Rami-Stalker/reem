import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:reem/core/design_system/design_system.dart';
import 'package:reem/core/localization/l10n_extension.dart';
import 'package:reem/core/shared/entities/product.dart';
import 'package:reem/core/shared/value_objects/money_format.dart';
import 'package:reem/features/product_social/presentation/product_gestures.dart';

/// Category, name, rating and what the piece has done — the top of the body.
///
/// Every figure is counted from the rows behind it when the page is served
/// (see `ProductsService.liveCounters`): the stars are the average of approved
/// reviews, a view is one person once a day and never the boutique herself,
/// «في مفضّلة» is the favourites that hold it, and «بيعت» is units in orders
/// that were not cancelled. Each says what it counts in words, because a bare
/// heart beside a bare number read as decoration — and the heart already
/// means the public like, which the action bar right below carries.
class ProductHeadline extends ConsumerWidget {
  const ProductHeadline({super.key, required this.product});

  final Product product;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = context.dsText;
    final colors = context.dsColors;
    final l10n = context.l10n;

    final arabic = context.isArabic;
    final eyebrow = [
      product.category.name(arabic: arabic),
      if (product.brand != null) product.brand!.name(arabic: arabic),
    ].join(' · ');

    // Her own bookmark moves the figure at once: the count was served with
    // her old answer in it, so that answer is taken out and the current one
    // put in.
    final savedNow = ProductGestures.watch(ref, product).isSaved;
    final saves =
        (product.favoritesCount - (product.isLiked ? 1 : 0) + (savedNow ? 1 : 0))
            .clamp(0, 1 << 31);

    final stats = [
      if (product.viewsCount > 0)
        _Stat(
          icon: Icons.visibility_outlined,
          label: l10n.productStatViews(
            product.viewsCount,
            formatCount(product.viewsCount),
          ),
          tint: colors.onSurfaceVariant,
        ),
      if (saves > 0)
        _Stat(
          icon: Icons.bookmark_rounded,
          label: l10n.productStatSaves(saves, formatCount(saves)),
          tint: colors.primary,
        ),
      if (product.ordersCount > 0)
        _Stat(
          icon: DsIcons.cart,
          label: l10n.productStatSold(
            product.ordersCount,
            formatCount(product.ordersCount),
          ),
          tint: colors.success,
        ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (eyebrow.isNotEmpty) Text(eyebrow, style: text.overline),
        DsGaps.vXs,
        Text(product.title, style: text.pageTitle),
        if (product.reviewsCount > 0) ...[
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
        if (stats.isNotEmpty) ...[
          DsGaps.vSm,
          Wrap(
            spacing: DsSpacing.md,
            runSpacing: DsSpacing.xs,
            children: stats,
          ),
        ],
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
  const _Stat({required this.icon, required this.label, required this.tint});

  final IconData icon;
  final String label;
  final Color tint;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: DsSizes.iconXs, color: tint),
        DsGaps.hXxs,
        Text(label, style: context.dsText.caption.semibold.tint(tint)),
      ],
    );
  }
}
