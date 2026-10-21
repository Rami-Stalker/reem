import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:reem/core/design_system/design_system.dart';
import 'package:reem/core/platform/app_haptics.dart';
import 'package:reem/core/presentation/providers/product_shape_provider.dart';
import 'package:reem/core/shared/entities/product.dart';
import 'package:reem/features/product_social/presentation/widgets/product_post_card.dart';

/// A shelf of products in whichever shape she has chosen — and the switcher
/// that chooses it.
///
/// Three screens drew this block, and they had drifted. The home showcase's
/// post shape rendered a *different set of objects* from its own mosaic and
/// grid, so switching shape quietly changed what she was looking at; the
/// department page and a boutique's page each wired the grid's heart to the
/// favourites store while their post shape wired it to the product store. One
/// shelf, one switcher, one answer.
///
/// The interactions are not passed in. Every shape gets them from
/// `DsProductActions`, installed once above the navigator: the post shape from
/// [ProductPostCard]'s own action bar, the mosaic and grid from the heart on
/// each tile. So a piece liked as a post is liked as a tile, and the rule
/// holds for whatever shape is added next.
class SliverProductShelf extends ConsumerWidget {
  const SliverProductShelf({
    super.key,
    required this.products,
    this.isLoading = false,
    this.onTapProduct,
    this.showSwitcher = true,
    this.switcherPadding = const EdgeInsets.fromLTRB(
      DsSpacing.lg,
      DsSpacing.xs,
      DsSpacing.lg,
      DsSpacing.lg,
    ),
  });

  final List<Product> products;
  final bool isLoading;
  final void Function(Product product)? onTapProduct;

  /// Off where the page draws its own switcher above other furniture.
  final bool showSwitcher;
  final EdgeInsetsGeometry switcherPadding;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final shape = ref.watch(productShapeProvider);

    return SliverMainAxisGroup(
      slivers: [
        if (showSwitcher)
          SliverToBoxAdapter(
            child: Padding(
              padding: switcherPadding,
              child: ShapeSwitcher(
                selected: shape,
                onSelect: (next) {
                  AppHaptics.selection();
                  ref.read(productShapeProvider.notifier).state = next;
                },
              ),
            ),
          ),
        switch (shape) {
          // The same card the home page's «وصل حديثاً» uses — heart, thread,
          // share, «أضيفي إلى صفحتي» and bookmark — so a department's posts
          // are the home page's posts.
          DsProductShape.posts => SliverProductPostCards(
            products: products,
            isLoading: isLoading,
          ),
          DsProductShape.mosaic => SliverProductMosaic(
            products: products,
            isLoading: isLoading,
            onTapProduct: onTapProduct,
          ),
          DsProductShape.grid => SliverProductGrid(
            products: products,
            isLoading: isLoading,
            onTapProduct: onTapProduct,
          ),
        },
      ],
    );
  }
}
