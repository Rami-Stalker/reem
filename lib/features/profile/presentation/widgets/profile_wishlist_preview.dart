import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/route_paths.dart';
import '../../../../core/shared/wedgets/product/product_rail.dart';
import '../providers/profile_provider.dart';

/// "Wishlist" preview rail — live favorites, with a route into the full grid.
class ProfileWishlistPreview extends ConsumerWidget {
  const ProfileWishlistPreview({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(favoritesNotifierProvider);
    final isLoading = state.isLoading && state.favorites.isEmpty;

    return ProductRail(
      eyebrow: 'Saved for later',
      title: 'Your wishlist',
      products: state.favorites.take(10).toList(),
      isLoading: isLoading,
      onSeeAll: () => context.push(RoutePaths.favorites),
      onTapProduct: (p) =>
          context.push('${RoutePaths.productDetails}?id=${p.id}'),
    );
  }
}
