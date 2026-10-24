import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ohara/core/design_system/design_system.dart';
import 'package:ohara/core/localization/l10n_extension.dart';
import 'package:ohara/core/platform/app_haptics.dart';
import 'package:ohara/core/shared/entities/product.dart';
import 'package:ohara/features/cart/presentation/providers/cart_providers.dart';
import 'package:ohara/features/product_social/presentation/product_gestures.dart';
import 'package:ohara/features/product_social/presentation/providers/product_social_providers.dart';

/// One product, told as a post — with everything a post has.
///
/// The department pages used to draw their products "as posts" with a thinner
/// card of their own: a photograph and a caption, and no heart, no thread, no
/// share and no bookmark. The client's question was the right one — why are
/// the posts under «مكياج» not the posts under «وصل حديثاً»? — so this is
/// assembled from the same design-system pieces as the home feed's card and
/// differs only in what it is fed: the boutique heads it, the piece's own
/// gallery fills it, and its gestures are the product's.
class ProductPostCard extends ConsumerStatefulWidget {
  const ProductPostCard({super.key, required this.product, this.featured = false});

  final Product product;

  /// The first card of a run is given a wider ring.
  final bool featured;

  @override
  ConsumerState<ProductPostCard> createState() => _ProductPostCardState();
}

class _ProductPostCardState extends ConsumerState<ProductPostCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _burst = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );
  bool _addingToBag = false;

  Product get product => widget.product;

  ProductGestures get _gestures => ProductGestures(context, ref, product);

  @override
  void initState() {
    super.initState();
    _seed();
  }

  @override
  void didUpdateWidget(ProductPostCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.product.id != product.id) _seed();
  }

  /// The shared store is written after the frame: a provider may not change
  /// while the tree that watches it is being built.
  void _seed() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(productEngagementProvider.notifier).seed([product]);
    });
  }

  @override
  void dispose() {
    _burst.dispose();
    super.dispose();
  }

  void _doubleTapLike() {
    unawaited(_burst.forward(from: 0));
    AppHaptics.light();
    _gestures.like(fromDoubleTap: true);
  }

  Future<void> _addToBag() async {
    final offer = product.bestOffer;
    if (offer == null || !offer.isBuyable || _addingToBag) return;

    setState(() => _addingToBag = true);
    AppHaptics.confirm();
    final added = await ref
        .read(cartNotifierProvider.notifier)
        .add(offerId: offer.id);
    if (!mounted) return;
    setState(() => _addingToBag = false);

    final l10n = context.l10n;
    if (added) {
      DsSnackbar.success(context, l10n.addedToBag);
    } else {
      DsSnackbar.error(context, l10n.error);
    }
  }

  /// "Jewellery · 2h" — the department, and how new the listing is.
  String _subtitle(BuildContext context) {
    final arabic = Localizations.localeOf(context).languageCode == 'ar';
    final category = product.category.name(arabic: arabic);
    return '$category · ${dsShortTimeAgo(context, product.createdAt)}';
  }

  @override
  Widget build(BuildContext context) {
    final engagement = ProductGestures.watch(ref, product);
    final seller = product.displaySeller;
    final media = product.media;
    final gestures = _gestures;
    final isFresh =
        DateTime.now().difference(product.createdAt) < const Duration(days: 3);
    final caption = product.description.trim().isEmpty
        ? product.title
        : product.description.trim();

    return DsImmersivePost(
      featured: widget.featured,
      authorName: seller?.name ?? product.title,
      authorImageUrl: seller?.imageUrl,
      authorVerified: seller?.isVerified ?? false,
      subtitle: _subtitle(context),
      onAuthor: seller == null ? null : gestures.openSeller,
      onMore: gestures.options,
      media: media,
      product: product,
      onOpenProduct: gestures.openProduct,
      onAddToBag: product.bestOffer?.isBuyable ?? false ? _addToBag : null,
      // The ticket already names the piece; the caption carries only what
      // the boutique wrote about it.
      caption: caption == product.title ? '' : caption,
      isFresh: isFresh,
      liked: engagement.isLiked,
      saved: engagement.isSaved,
      picked: engagement.isPicked,
      likes: engagement.likes,
      comments: engagement.comments,
      shares: engagement.shares,
      burst: _burst,
      onLike: gestures.like,
      onDoubleTap: _doubleTapLike,
      onComment: gestures.comment,
      onShare: gestures.share,
      onSave: gestures.save,
      onPick: gestures.pick,
    );
  }
}

/// A shelf of products told as posts, for a scroll view.
///
/// The sliver every product listing uses for its post shape — a department,
/// "see all", a boutique's page, a woman's picks — so all of them are the same
/// card with the same gestures.
class SliverProductPostCards extends StatelessWidget {
  const SliverProductPostCards({
    super.key,
    required this.products,
    this.isLoading = false,
    this.skeletonCount = 2,
    this.padding = const EdgeInsets.symmetric(horizontal: DsSpacing.lg),
    this.animate = false,
  });

  final List<Product> products;
  final bool isLoading;
  final int skeletonCount;
  final EdgeInsetsGeometry padding;

  /// Fade each card in as it arrives — used where the list is the page's
  /// finale rather than a working listing.
  final bool animate;

  @override
  Widget build(BuildContext context) {
    if (isLoading && products.isEmpty) {
      return SliverList.separated(
        itemCount: skeletonCount,
        separatorBuilder: (_, _) => const SizedBox(height: DsSpacing.xl),
        itemBuilder: (_, _) => Padding(
          padding: padding,
          child: const DsPostCardSkeleton(mediaAspectRatio: 4 / 5),
        ),
      );
    }
    if (products.isEmpty) {
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }

    return SliverList.separated(
      itemCount: products.length,
      separatorBuilder: (_, _) => const SizedBox(height: DsSpacing.xl),
      itemBuilder: (context, index) {
        final card = ProductPostCard(
          key: ValueKey(products[index].id),
          product: products[index],
          featured: index == 0,
        );
        return Padding(
          padding: padding,
          child: animate
              ? card
                    .animate()
                    .fadeIn(duration: 420.ms, curve: Curves.easeOut)
                    .slideY(
                      begin: 0.04,
                      end: 0,
                      duration: 420.ms,
                      curve: Curves.easeOutCubic,
                    )
              : card,
        );
      },
    );
  }
}
