import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:reem/core/design_system/design_system.dart';
import 'package:reem/core/localization/l10n_extension.dart';
import 'package:reem/core/media/authorized_media_image.dart';
import 'package:reem/core/media/media_variants.dart';
import 'package:reem/core/router/route_names.dart';
import 'package:reem/core/router/route_paths.dart';
import 'package:reem/core/shared/entities/post.dart';
import 'package:reem/core/shared/entities/product.dart';
import 'package:reem/core/shared/entities/user.dart';
import 'package:reem/features/profile/domain/entities/wishlist_entity.dart';
import 'package:reem/features/profile/presentation/providers/profile_provider.dart';
import 'package:reem/features/profile/presentation/widgets/favorite_product_card.dart';

class FavoritesScreen extends ConsumerStatefulWidget {
  const FavoritesScreen({super.key});

  @override
  ConsumerState<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends ConsumerState<FavoritesScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(wishlistNotifierProvider.notifier).load();
    });
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(wishlistNotifierProvider, (previous, next) {
      final link = next.shareLink;
      if (link == null || link == previous?.shareLink) return;
      Clipboard.setData(ClipboardData(text: link.shareUrl));
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.l10n.wishlistLinkCopied)));
    });

    final state = ref.watch(wishlistNotifierProvider);
    final overview = state.overview;
    final width = MediaQuery.sizeOf(context).width;
    final columns = width >= 900
        ? 4
        : width >= 560
        ? 3
        : 2;

    return ReemScrollPage(
      slivers: [
        PremiumAppBar(title: context.l10n.wishlist),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(
            DsSpacing.lg,
            DsSpacing.sm,
            DsSpacing.lg,
            DsSpacing.md,
          ),
          sliver: SliverToBoxAdapter(
            child: _WishlistHeader(
              totalSaved: overview.totalSaved,
              isLoading: state.isLoading,
              onCreateCollection: () => _showCreateCollectionSheet(context),
            ),
          ),
        ),
        if (state.error != null)
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: DsSpacing.lg),
            sliver: SliverToBoxAdapter(
              child: _ErrorBanner(
                message: state.error!,
                onRetry: () =>
                    ref.read(wishlistNotifierProvider.notifier).load(),
              ),
            ),
          ),
        if (state.isLoading && overview.isEmpty)
          const SliverFillRemaining(
            hasScrollBody: false,
            child: Center(child: CircularProgressIndicator.adaptive()),
          )
        else if (overview.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: _EmptyWishlistState(
              onCreateCollection: () => _showCreateCollectionSheet(context),
            ),
          )
        else ...[
          if (overview.collections.isNotEmpty)
            SliverToBoxAdapter(
              child: _CollectionsSection(
                collections: overview.collections,
                isMutating: state.isMutating,
                onShare: (id) => ref
                    .read(wishlistNotifierProvider.notifier)
                    .shareCollection(id),
              ),
            ),
          if (overview.sellers.isNotEmpty)
            SliverToBoxAdapter(
              child: _SavedSellersStrip(sellers: overview.sellers),
            ),
          if (overview.posts.isNotEmpty)
            SliverToBoxAdapter(child: _SavedPostsStrip(posts: overview.posts)),
          if (overview.products.isNotEmpty) ...[
            SliverPadding(
              padding: EdgeInsets.fromLTRB(
                DsSpacing.lg,
                DsSpacing.xl,
                DsSpacing.lg,
                DsSpacing.sm,
              ),
              sliver: SliverToBoxAdapter(
                child: ReemSectionHeader(
                  title: context.l10n.savedProducts,
                  subtitle: context.l10n.priceDropsBlurb,
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(
                DsSpacing.lg,
                DsSpacing.xxxs,
                DsSpacing.lg,
                120,
              ),
              sliver: SliverGrid(
                delegate: SliverChildBuilderDelegate(
                  (context, index) =>
                      FavoriteProductCard(product: overview.products[index]),
                  childCount: overview.products.length,
                ),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: columns,
                  crossAxisSpacing: DsSpacing.md,
                  mainAxisSpacing: DsSpacing.md,
                  childAspectRatio: 0.68,
                ),
              ),
            ),
          ],
        ],
      ],
    );
  }

  Future<void> _showCreateCollectionSheet(BuildContext context) async {
    final name = TextEditingController();
    final description = TextEditingController();
    final notifier = ref.read(wishlistNotifierProvider.notifier);

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) {
        final bottom = MediaQuery.viewInsetsOf(context).bottom;
        return Padding(
          padding: EdgeInsets.fromLTRB(
            DsSpacing.lg,
            DsSpacing.sm,
            DsSpacing.lg,
            bottom + DsSpacing.lg,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                context.l10n.newCollection,
                style: context.dsText.sectionTitle.copyWith(
                  fontWeight: DsTypography.bold,
                ),
              ),
              const SizedBox(height: DsSpacing.md),
              TextField(
                controller: name,
                autofocus: true,
                textInputAction: TextInputAction.next,
                decoration: InputDecoration(
                  labelText: context.l10n.fullName,
                  prefixIcon: Icon(Icons.folder_special_outlined),
                ),
              ),
              const SizedBox(height: DsSpacing.sm),
              TextField(
                controller: description,
                maxLines: 2,
                decoration: InputDecoration(
                  labelText: context.l10n.storeDescription,
                  prefixIcon: Icon(Icons.notes_outlined),
                ),
              ),
              const SizedBox(height: DsSpacing.lg),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: Text(context.l10n.cancel),
                    ),
                  ),
                  const SizedBox(width: DsSpacing.sm),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () {
                        final value = name.text.trim();
                        if (value.isEmpty) return;
                        notifier.createCollection(
                          name: value,
                          description: description.text,
                        );
                        Navigator.of(context).pop();
                      },
                      icon: const Icon(Icons.add_rounded),
                      label: Text(context.l10n.add),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
    name.dispose();
    description.dispose();
  }
}

class _WishlistHeader extends StatelessWidget {
  const _WishlistHeader({
    required this.totalSaved,
    required this.isLoading,
    required this.onCreateCollection,
  });

  final int totalSaved;
  final bool isLoading;
  final VoidCallback onCreateCollection;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: ReemSectionHeader(
            title: context.l10n.savedItems,
            subtitle: isLoading
                ? context.l10n.syncingWishlist
                : context.l10n.itemsCount(totalSaved),
          ),
        ),
        FilledButton.icon(
          onPressed: onCreateCollection,
          icon: const Icon(Icons.create_new_folder_outlined),
          label: Text(context.l10n.collections),
        ),
      ],
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final colors = context.dsColors;
    return Container(
      margin: const EdgeInsets.only(bottom: DsSpacing.md),
      padding: const EdgeInsets.all(DsSpacing.md),
      decoration: BoxDecoration(
        color: colors.errorContainer,
        borderRadius: DsRadius.borderLg,
        border: Border.all(color: colors.error.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline_rounded, color: colors.error),
          const SizedBox(width: DsSpacing.sm),
          Expanded(
            child: Text(message, style: context.dsText.body.tint(colors.error)),
          ),
          IconButton(
            tooltip: context.l10n.retry,
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
    );
  }
}

class _EmptyWishlistState extends StatelessWidget {
  const _EmptyWishlistState({required this.onCreateCollection});

  final VoidCallback onCreateCollection;

  @override
  Widget build(BuildContext context) {
    final colors = context.dsColors;
    return Padding(
      padding: const EdgeInsets.all(DsSpacing.xl),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.favorite_border_rounded, size: 56, color: colors.primary),
          const SizedBox(height: DsSpacing.md),
          Text(
            context.l10n.noSavedItems,
            style: context.dsText.cardTitle.copyWith(
              fontWeight: DsTypography.bold,
            ),
          ),
          const SizedBox(height: DsSpacing.xs),
          Text(
            context.l10n.collectionsBlurb,
            textAlign: TextAlign.center,
            style: context.dsText.body.tint(colors.onSurfaceVariant),
          ),
          const SizedBox(height: DsSpacing.lg),
          FilledButton.icon(
            onPressed: onCreateCollection,
            icon: const Icon(Icons.create_new_folder_outlined),
            label: Text(context.l10n.createCollection),
          ),
        ],
      ),
    );
  }
}

class _CollectionsSection extends StatelessWidget {
  const _CollectionsSection({
    required this.collections,
    required this.isMutating,
    required this.onShare,
  });

  final List<WishlistCollection> collections;
  final bool isMutating;
  final ValueChanged<String> onShare;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        DsSpacing.lg,
        DsSpacing.lg,
        DsSpacing.lg,
        DsSpacing.xxxs,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ReemSectionHeader(
            title: context.l10n.collections,
            subtitle: context.l10n.collectionsBlurb,
          ),
          const SizedBox(height: DsSpacing.md),
          ...collections.map(
            (collection) => Padding(
              padding: const EdgeInsets.only(bottom: DsSpacing.sm),
              child: _CollectionTile(
                collection: collection,
                isMutating: isMutating,
                onShare: () => onShare(collection.id),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CollectionTile extends StatelessWidget {
  const _CollectionTile({
    required this.collection,
    required this.isMutating,
    required this.onShare,
  });

  final WishlistCollection collection;
  final bool isMutating;
  final VoidCallback onShare;

  @override
  Widget build(BuildContext context) {
    final colors = context.dsColors;
    return Container(
      padding: const EdgeInsets.all(DsSpacing.md),
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: DsRadius.borderLg,
        border: Border.all(color: colors.border.withValues(alpha: 0.6)),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: colors.primaryContainer,
              borderRadius: DsRadius.borderMd,
            ),
            child: Icon(
              Icons.collections_bookmark_outlined,
              color: colors.primary,
            ),
          ),
          const SizedBox(width: DsSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  collection.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.dsText.body.semibold,
                ),
                Text(
                  context.l10n.itemsCount(collection.itemsCount),
                  style: context.dsText.body.tint(colors.onSurfaceVariant),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: context.l10n.a11yShare,
            onPressed: isMutating ? null : onShare,
            icon: const Icon(Icons.ios_share_rounded),
          ),
        ],
      ),
    );
  }
}

class _SavedSellersStrip extends StatelessWidget {
  const _SavedSellersStrip({required this.sellers});

  final List<SavedSeller> sellers;

  @override
  Widget build(BuildContext context) {
    return _HorizontalSection(
      title: context.l10n.savedSellers,
      subtitle: context.l10n.storesToRevisit,
      height: 116,
      itemCount: sellers.length,
      itemBuilder: (context, index) =>
          _SellerPill(seller: sellers[index].seller),
    );
  }
}

class _SavedPostsStrip extends StatelessWidget {
  const _SavedPostsStrip({required this.posts});

  final List<SavedPost> posts;

  @override
  Widget build(BuildContext context) {
    return _HorizontalSection(
      title: context.l10n.savedPosts,
      subtitle: context.l10n.priceDropsBlurb,
      height: 132,
      itemCount: posts.length,
      itemBuilder: (context, index) => _PostPreview(post: posts[index].post),
    );
  }
}

class _HorizontalSection extends StatelessWidget {
  const _HorizontalSection({
    required this.title,
    required this.subtitle,
    required this.height,
    required this.itemCount,
    required this.itemBuilder,
  });

  final String title;
  final String subtitle;
  final double height;
  final int itemCount;
  final IndexedWidgetBuilder itemBuilder;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        DsSpacing.lg,
        DsSpacing.xl,
        DsSpacing.lg,
        DsSpacing.xxxs,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ReemSectionHeader(title: title, subtitle: subtitle),
          const SizedBox(height: DsSpacing.md),
          SizedBox(
            height: height,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: itemCount,
              separatorBuilder: (_, _) => const SizedBox(width: DsSpacing.sm),
              itemBuilder: itemBuilder,
            ),
          ),
        ],
      ),
    );
  }
}

class _SellerPill extends StatelessWidget {
  const _SellerPill({required this.seller});

  final User seller;

  @override
  Widget build(BuildContext context) {
    final colors = context.dsColors;
    return Semantics(
      button: true,
      label: context.l10n.a11yOpen(seller.name),
      child: InkWell(
        borderRadius: DsRadius.borderLg,
        onTap: () => context.pushNamed(
          RouteNames.userProfile,
          pathParameters: {'id': seller.id},
        ),
        child: Container(
          width: 220,
          padding: const EdgeInsets.all(DsSpacing.md),
          decoration: BoxDecoration(
            color: colors.card,
            borderRadius: DsRadius.borderLg,
            border: Border.all(color: colors.border.withValues(alpha: 0.6)),
          ),
          child: Row(
            children: [
              CircleAvatar(
                backgroundImage: seller.imageUrl == null
                    ? null
                    : NetworkImage(seller.imageUrl!),
                child: seller.imageUrl == null
                    ? Text(seller.name.isEmpty ? '?' : seller.name[0])
                    : null,
              ),
              const SizedBox(width: DsSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      seller.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.dsText.body.semibold,
                    ),
                    Text(
                      '@${seller.username}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.dsText.body.tint(colors.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              if (seller.isVerified)
                Icon(Icons.verified_rounded, color: colors.primary, size: 18),
            ],
          ),
        ),
      ),
    );
  }
}

/// One saved post, as a card that opens something.
///
/// It used to open nothing: a shopper saved a post *because of the piece in
/// it*, came here to find the piece, and tapped a card that was not a button.
/// A post that tags a product goes straight to that product — which is what
/// she saved it for — and one that tags nothing opens the post itself.
class _PostPreview extends StatelessWidget {
  const _PostPreview({required this.post});

  final Post post;

  void _open(BuildContext context) {
    final product = post.product;
    if (product != null && product.id.isNotEmpty) {
      context.push(RoutePaths.productDetailsOf(product.id));
      return;
    }
    if (post.id.isNotEmpty) {
      context.push(RoutePaths.contentDetailOf(post.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.dsColors;
    final product = post.product;
    return Semantics(
      button: true,
      label: context.l10n.a11yOpen(product?.title ?? post.author.name),
      child: InkWell(
        borderRadius: DsRadius.borderLg,
        onTap: () => _open(context),
        child: Container(
          width: 250,
          padding: const EdgeInsets.all(DsSpacing.md),
          decoration: BoxDecoration(
            color: colors.card,
            borderRadius: DsRadius.borderLg,
            border: Border.all(color: colors.border.withValues(alpha: 0.6)),
          ),
          child: Row(
            children: [
              _PostProductImage(product: product),
              const SizedBox(width: DsSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      post.caption.isEmpty
                          ? (product?.title ?? post.author.name)
                          : post.caption,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: context.dsText.body.semibold,
                    ),
                    // A post that tags nothing has no second line to give.
                    if (product != null) ...[
                      DsGaps.vXxs,
                      Text(
                        product.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.dsText.body.tint(
                          colors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PostProductImage extends StatelessWidget {
  const _PostProductImage({required this.product});

  final Product? product;

  @override
  Widget build(BuildContext context) {
    final colors = context.dsColors;
    final url = product?.coverUrl;
    return ClipRRect(
      borderRadius: DsRadius.borderMd,
      child: SizedBox(
        width: 72,
        height: 92,
        child: url == null || url.isEmpty
            ? ColoredBox(
                color: colors.surfaceVariant,
                child: Icon(
                  Icons.image_outlined,
                  color: colors.onSurfaceVariant,
                ),
              )
            : AuthorizedMediaImage(
                url: url,
                variantWidth: MediaVariants.thumbnail,
              ),
      ),
    );
  }
}
