import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:reem/core/design_system/patterns/product_rail.dart';
import 'package:reem/core/localization/l10n_extension.dart';
import 'package:reem/core/router/route_paths.dart';
import 'package:reem/core/shared/entities/product.dart';
import 'package:reem/features/profile/presentation/providers/profile_overview_provider.dart';

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
      eyebrow: context.l10n.recentlyViewed,
      title: context.l10n.recentlyViewed,
      products: products,
      isLoading: isLoading,
      onTapProduct: (p) =>
          context.push('${RoutePaths.productDetails}?id=${p.id}'),
    );
  }
}
