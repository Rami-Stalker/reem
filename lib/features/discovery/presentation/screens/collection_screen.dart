import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:go_router/go_router.dart';

import 'package:reem/core/design_system/design_system.dart';
import 'package:reem/core/localization/l10n_extension.dart';
import 'package:reem/core/platform/app_haptics.dart';
import 'package:reem/core/presentation/providers/product_shape_provider.dart';
import 'package:reem/core/router/route_paths.dart';
import 'package:reem/core/shared/entities/product.dart';
import 'package:reem/features/discovery/presentation/providers/collection_notifier.dart';
import 'package:reem/features/discovery/presentation/providers/collection_state.dart';
import 'package:reem/features/product_social/presentation/providers/product_social_providers.dart';
import 'package:reem/features/product_social/presentation/widgets/product_post_card.dart';
import 'package:reem/features/profile/presentation/providers/profile_provider.dart';

/// Every full listing of products — a department, a collection, "see all"
/// under a rail — in whichever of the three shapes she prefers.
///
/// It used to be a fixed two-column grid. The switcher existed, but only on
/// the home page's "new in" showcase, which made the three shapes look like a
/// decoration on one section rather than the way this catalogue is read: she
/// would set the page to posts, tap into «فساتين», and be handed a grid.
/// Shape is chosen once, in [productShapeProvider], and every listing honours
/// it.
class CollectionScreen extends ConsumerStatefulWidget {
  const CollectionScreen({
    super.key,
    required this.provider,
    required this.title,
  });

  final StateNotifierProvider<CollectionNotifier, CollectionState> provider;
  final String title;

  @override
  ConsumerState<CollectionScreen> createState() => _CollectionScreenState();
}

class _CollectionScreenState extends ConsumerState<CollectionScreen> {
  final _controller = ScrollController();

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onScroll);
  }

  @override
  void dispose() {
    _controller
      ..removeListener(_onScroll)
      ..dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_controller.position.pixels >=
        _controller.position.maxScrollExtent - 400) {
      ref.read(widget.provider.notifier).loadMore();
    }
  }

  void _openProduct(Product product) =>
      context.push(RoutePaths.productDetailsOf(product.id));

  void _toggleFavorite(Product product) =>
      ref.read(favoritesNotifierProvider.notifier).toggleFavorite(product.id);

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(widget.provider);
    final shape = ref.watch(productShapeProvider);
    final colors = context.dsColors;

    return Scaffold(
      backgroundColor: colors.background,
      body: RefreshIndicator(
        onRefresh: () async {
          await ref.read(widget.provider.notifier).refresh();
          // Her hearts and picks are re-read with the page, not left as they
          // were when it first opened.
          ref
              .read(productEngagementProvider.notifier)
              .refresh(ref.read(widget.provider).items.map((p) => p.id));
        },
        child: CustomScrollView(
          controller: _controller,
          slivers: [
            PremiumAppBar(title: widget.title, showBack: true),
            if (state.isLoading && state.items.isEmpty)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: DsLoadingIndicator(),
              )
            else if (state.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: DsEmptyState(
                icon: Icons.checkroom_rounded,
                title: context.l10n.noProductsFound,
              ),
              )
            else ...[
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    DsSpacing.lg,
                    DsSpacing.xs,
                    DsSpacing.lg,
                    DsSpacing.lg,
                  ),
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
                // The same card «وصل حديثاً» uses — heart, thread, share,
                // «أضيفي إلى صفحتي» and bookmark — so a department's posts are
                // the home page's posts.
                DsProductShape.posts => SliverProductPostCards(
                  products: state.items,
                ),
                DsProductShape.mosaic => SliverProductMosaic(
                  products: state.items,
                  onTapProduct: _openProduct,
                ),
                DsProductShape.grid => SliverProductGrid(
                  products: state.items,
                  onTapProduct: _openProduct,
                  onToggleFavorite: _toggleFavorite,
                ),
              },
              if (state.isLoadingMore)
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.all(DsSpacing.lg),
                    child: DsLoadingIndicator(),
                  ),
                ),
              // Room under the last card for the floating bottom bar.
              const SliverToBoxAdapter(child: SizedBox(height: DsSpacing.xxxl)),
            ],
          ],
        ),
      ),
    );
  }
}
