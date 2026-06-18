import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/route_paths.dart';
import '../../../../core/shared/entities/product.dart';
import '../../../../core/shared/wedgets/product/product_rail.dart';
import '../providers/profile_overview_provider.dart';

/// "Recently viewed" rail on the profile centre.
class ProfileRecentlyViewed extends ConsumerWidget {
  const ProfileRecentlyViewed({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isLoading = ref.watch(
      profileOverviewNotifierProvider.select((s) => s.isInitialLoading),
    );
    final products = ref.watch(
      profileOverviewNotifierProvider
          .select((s) => s.overview?.recentlyViewed ?? const <Product>[]),
    );

    return ProductRail(
      eyebrow: 'Jump back in',
      title: 'Recently viewed',
      products: products,
      isLoading: isLoading,
      onTapProduct: (p) =>
          context.push('${RoutePaths.productDetails}?id=${p.id}'),
    );
  }
}
