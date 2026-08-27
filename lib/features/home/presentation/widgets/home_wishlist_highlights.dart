import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/localization/l10n_extension.dart';
import '../../../../core/router/route_paths.dart';
import '../../../../core/design_system/patterns/product_rail.dart';
import '../../../profile/presentation/providers/profile_provider.dart';

/// "From your wishlist" — surfaces a few saved pieces so the customer can pick
/// back up. Reuses the live favorites provider; collapses when empty.
class HomeWishlistHighlights extends ConsumerStatefulWidget {
  const HomeWishlistHighlights({super.key});

  @override
  ConsumerState<HomeWishlistHighlights> createState() =>
      _HomeWishlistHighlightsState();
}

class _HomeWishlistHighlightsState
    extends ConsumerState<HomeWishlistHighlights> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final state = ref.read(favoritesNotifierProvider);
      if (state.favorites.isEmpty && !state.isLoading) {
        ref.read(favoritesNotifierProvider.notifier).load();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(favoritesNotifierProvider);
    final isLoading = state.isLoading && state.favorites.isEmpty;

    return ProductRail(
      eyebrow: context.l10n.homeWishlistEyebrow,
      title: context.l10n.homeWishlist,
      products: state.favorites.take(10).toList(),
      isLoading: isLoading,
      onSeeAll: () => context.push(RoutePaths.favorites),
      onTapProduct: (p) =>
          context.push('${RoutePaths.productDetails}?id=${p.id}'),
    );
  }
}
