import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/design_system/patterns/product_rail.dart';
import '../../../../core/localization/l10n_extension.dart';
import '../../../../core/router/route_paths.dart';
import '../../../../core/shared/entities/product.dart';
import '../providers/home_content_provider.dart';

/// "Recently viewed" — a quick way back to pieces the customer just browsed.
class HomeRecentlyViewed extends ConsumerWidget {
  const HomeRecentlyViewed({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isLoading = ref.watch(
      homeContentNotifierProvider.select((s) => s.isInitialLoading),
    );
    final products = ref.watch(
      homeContentNotifierProvider
          .select((s) => s.content?.recentlyViewed ?? const <Product>[]),
    );

    return ProductRail(
      eyebrow: context.l10n.homeRecentlyViewedEyebrow,
      title: context.l10n.homeRecentlyViewed,
      products: products,
      isLoading: isLoading,
      onTapProduct: (p) =>
          context.push('${RoutePaths.productDetails}?id=${p.id}'),
    );
  }
}
