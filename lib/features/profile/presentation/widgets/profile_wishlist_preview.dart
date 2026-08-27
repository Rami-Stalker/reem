import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/route_paths.dart';
import '../../../../core/design_system/patterns/product_rail.dart';
import '../providers/profile_provider.dart';
import '../../../../core/localization/l10n_extension.dart';

/// "Wishlist" preview rail — live favorites, with a route into the full grid.
class ProfileWishlistPreview extends ConsumerWidget {
  const ProfileWishlistPreview({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(favoritesNotifierProvider);
    final isLoading = state.isLoading && state.favorites.isEmpty;

    return ProductRail(
      eyebrow: context.l10n.savedForLater,
      title: context.l10n.yourWishlist,
      products: state.favorites.take(10).toList(),
      isLoading: isLoading,
      onSeeAll: () => context.push(RoutePaths.favorites),
      onTapProduct: (p) =>
          context.push('${RoutePaths.productDetails}?id=${p.id}'),
    );
  }
}
