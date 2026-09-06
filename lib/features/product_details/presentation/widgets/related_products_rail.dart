import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:reem/core/design_system/design_system.dart';
import 'package:reem/core/localization/l10n_extension.dart';
import 'package:reem/core/router/route_paths.dart';
import 'package:reem/core/shared/entities/product.dart';
import 'package:reem/features/discovery/presentation/providers/discovery_providers.dart';

/// Pieces from the same corner of the catalogue.
///
/// It asks the server for this product's neighbours — `GET
/// /discovery/products/:id/similar`, which filters to the same category,
/// drops the product itself and ranks by rating then orders.
///
/// It used to fetch page one of the *whole* catalogue and keep the rows whose
/// category happened to match. Page one is twenty products spread over fifteen
/// categories, so the rail could show at most one neighbour and, for anything
/// outside those fifteen, none at all — a section that existed on every
/// product page and was empty on nearly all of them.
class RelatedProductsRail extends ConsumerWidget {
  const RelatedProductsRail({super.key, required this.product});

  final Product product;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(similarProductsProvider(product.id));
    final products = state.items;

    // Nothing to show and nothing on the way: the shop cannot fill this rail
    // for this piece, so it does not promise one.
    if (products.isEmpty && !state.isLoading) return const SizedBox.shrink();

    return ProductRail(
      title: context.l10n.productRelated,
      products: products,
      isLoading: state.isLoading && products.isEmpty,
      onTapProduct: (p) => context.push(RoutePaths.productDetailsOf(p.id)),
    );
  }
}
