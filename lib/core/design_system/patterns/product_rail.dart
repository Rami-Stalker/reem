import 'package:flutter/material.dart';
import 'package:ohara/core/design_system/design_system.dart';
import 'package:ohara/core/localization/l10n_extension.dart';
import 'package:ohara/core/shared/entities/product.dart';
import 'package:ohara/features/discovery/presentation/widgets/product_card_compact.dart';

/// A reusable, presentational horizontal product rail with a premium header
/// (optional eyebrow + title + "See all"), skeleton loading and graceful empty
/// collapse. Shared across Home, Profile and Seller surfaces — driven entirely
/// by props, with no provider coupling.
class ProductRail extends StatelessWidget {
  const ProductRail({
    super.key,
    required this.title,
    this.eyebrow,
    this.products = const [],
    this.isLoading = false,
    this.onSeeAll,
    this.onTapProduct,
    this.trailingBuilder,
    this.skeletonCount = 4,
  });

  final String title;
  final String? eyebrow;
  final List<Product> products;
  final bool isLoading;
  final VoidCallback? onSeeAll;
  final void Function(Product product)? onTapProduct;

  /// Optional overlay (e.g. a "note" chip) rendered on top of each card.
  final Widget Function(BuildContext context, Product product)? trailingBuilder;
  final int skeletonCount;

  static const double _cardWidth = 152;
  static const double _railHeight = 236;

  @override
  Widget build(BuildContext context) {
    if (!isLoading && products.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Header(
          eyebrow: eyebrow,
          title: title,
          onSeeAll: products.isNotEmpty ? onSeeAll : null,
        ),
        SizedBox(
          height: _railHeight,
          child: isLoading
              ? _skeleton()
              : ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: DsSpacing.lg),
                  itemCount: products.length,
                  separatorBuilder: (_, _) =>
                      const SizedBox(width: DsSpacing.md),
                  itemBuilder: (context, i) {
                    final product = products[i];
                    final card = ProductCardCompact(
                      product: product,
                      onTap: () => onTapProduct?.call(product),
                    );
                    if (trailingBuilder == null) {
                      return SizedBox(width: _cardWidth, child: card);
                    }
                    return SizedBox(
                      width: _cardWidth,
                      child: Stack(
                        children: [
                          card,
                          Positioned(
                            top: DsSpacing.xs,
                            left: DsSpacing.xs,
                            child: trailingBuilder!(context, product),
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _skeleton() {
    return DsShimmer(
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: DsSpacing.lg),
        itemCount: skeletonCount,
        separatorBuilder: (_, _) => const SizedBox(width: DsSpacing.md),
        itemBuilder: (_, _) => const SizedBox(
          width: _cardWidth,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DsSkeleton.box(height: _cardWidth, borderRadius: DsRadius.lg),
              SizedBox(height: DsSpacing.xs),
              DsSkeleton.line(width: 120),
              SizedBox(height: DsSpacing.xs),
              DsSkeleton.line(width: 70),
            ],
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.title, this.eyebrow, this.onSeeAll});

  final String title;
  final String? eyebrow;
  final VoidCallback? onSeeAll;

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        DsSpacing.lg,
        0,
        DsSpacing.lg,
        DsSpacing.md,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (eyebrow != null) ...[
                  Text(
                    eyebrow!.toUpperCase(),
                    style: DsTypography.overline(c.primary),
                  ),
                  const SizedBox(height: DsSpacing.xxs),
                ],
                Text(
                  title,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: DsTypography.bold,
                  ),
                ),
              ],
            ),
          ),
          if (onSeeAll != null)
            GestureDetector(
              onTap: onSeeAll,
              child: Row(
                children: [
                  Text(
                    context.l10n.viewAll,
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: c.primary,
                      fontWeight: DsTypography.semiBold,
                    ),
                  ),
                  Icon(Icons.chevron_right_rounded, size: 18, color: c.primary),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
