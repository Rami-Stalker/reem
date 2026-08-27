import 'dart:math' as math;
import 'dart:ui';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:reem/core/design_system/design_system.dart';
import 'package:reem/core/localization/l10n_extension.dart';
import 'package:reem/core/router/route_paths.dart';
import 'package:reem/core/shared/entities/media.dart';
import 'package:reem/core/shared/entities/post.dart';
import 'package:reem/core/shared/entities/product.dart';
import 'package:reem/features/cart/presentation/providers/cart_providers.dart';
import 'package:reem/features/social_posts/presentation/providers/social_posts_providers.dart';
import 'package:reem/features/social_posts/presentation/widgets/comment_sheet.dart';

/// The centrepiece of Reem's home: a product told as a **post**.
///
/// The brief was Instagram, only lovelier. What that turned into: a swipeable
/// gallery instead of one frozen frame, a rose-to-champagne thread around the
/// card, a frosted "shop this" plate floating over the foot of the image, and a
/// double-tap that scatters petals rather than stamping a flat heart. Every
/// colour, radius and easing reads from the design system, so the card
/// restyles with the theme and turns aubergine in dark mode.
class ReemPostCard extends ConsumerStatefulWidget {
  const ReemPostCard({super.key, required this.post, this.featured = false});

  final Post post;

  /// The first card of the feed is given a little more presence — a wider ring
  /// and a warmer glow — so the eye lands there first.
  final bool featured;

  @override
  ConsumerState<ReemPostCard> createState() => _ReemPostCardState();
}

class _ReemPostCardState extends ConsumerState<ReemPostCard>
    with TickerProviderStateMixin {
  late bool _liked = widget.post.isLiked;
  late bool _saved = widget.post.isSaved;
  late int _likes = widget.post.likesCount;
  bool _captionExpanded = false;
  bool _addingToBag = false;
  int _mediaIndex = 0;

  late final AnimationController _burst = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );

  @override
  void dispose() {
    _burst.dispose();
    super.dispose();
  }

  Post get post => widget.post;

  List<MediaItem> get _media => post.media;

  void _toggleLike({bool fromDoubleTap = false}) {
    final willLike = fromDoubleTap ? true : !_liked;
    if (willLike != _liked) {
      setState(() {
        _likes += willLike ? 1 : -1;
        _liked = willLike;
      });
      ref.read(toggleLikeUseCaseProvider).call(post.id);
    }
    if (fromDoubleTap) {
      _burst.forward(from: 0);
      HapticFeedback.lightImpact();
    } else {
      HapticFeedback.selectionClick();
    }
  }

  void _toggleSave() {
    setState(() => _saved = !_saved);
    HapticFeedback.selectionClick();
    ref.read(toggleSaveUseCaseProvider).call(post.id);
  }

  /// Only meaningful when the post tags something; a look or an announcement
  /// has nowhere to send her, so the affordances that call this are hidden.
  void _openProduct() {
    final product = post.product;
    if (product == null) return;
    context.push('${RoutePaths.productDetails}?id=${product.id}');
  }

  void _openAuthor() => context.push(RoutePaths.userProfileOf(post.author.id));

  void _openComments() => showCommentSheet(context, post.id);

  /// A post is "just in" for its first three days — long enough that the
  /// ribbon still means something on a feed she opens twice a week.
  bool get _isFresh =>
      DateTime.now().difference(post.createdAt) < const Duration(days: 3);

  /// Only offered when there is a live offer to add; a catalogue entry nobody
  /// is currently selling gets the plain "open the product" arrow instead.
  String? get _addableOfferId {
    final offer = post.product?.bestOffer;
    if (offer == null || offer.stock <= 0) return null;
    return offer.id;
  }

  Future<void> _addToBag() async {
    final offerId = _addableOfferId;
    if (offerId == null || _addingToBag) return;

    setState(() => _addingToBag = true);
    HapticFeedback.mediumImpact();
    final added = await ref.read(cartNotifierProvider.notifier).add(
      offerId: offerId,
    );
    if (!mounted) return;
    setState(() => _addingToBag = false);

    final l10n = context.l10n;
    if (added) {
      DsSnackbar.success(context, l10n.addedToBag);
    } else {
      DsSnackbar.error(context, l10n.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;

    // A thread, not a frame: brand-coloured but held well under full opacity,
    // so a whole column of these still reads calm.
    final ring = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        c.primary.withValues(alpha: widget.featured ? 0.62 : 0.38),
        c.secondary.withValues(alpha: widget.featured ? 0.34 : 0.18),
        c.accent.withValues(alpha: widget.featured ? 0.62 : 0.38),
      ],
    );

    return DsGradientBorder(
      radius: 34,
      width: widget.featured ? 1.6 : 1.1,
      gradient: ring,
      backgroundColor: c.card,
      boxShadow: [
        // A rose bloom under the card, then a neutral lift. Two shadows read
        // as light falling on silk; one flat drop reads as a box.
        BoxShadow(
          color: c.primary.withValues(alpha: widget.featured ? 0.18 : 0.10),
          blurRadius: widget.featured ? 40 : 30,
          offset: const Offset(0, 16),
        ),
        BoxShadow(color: c.shadow, blurRadius: 18, offset: const Offset(0, 6)),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          _PostHeader(
            post: post,
            onAuthor: _openAuthor,
            onMore: post.hasProduct ? _openProduct : null,
          ),
          // A post with nothing to show and nothing to shop is a note, not a
          // gallery: give it a painted canvas rather than an empty frame.
          if (_media.isEmpty && !post.hasProduct)
            _QuoteCanvas(
              caption: post.caption,
              onDoubleTap: () => _toggleLike(fromDoubleTap: true),
              burst: _burst,
            )
          else
            _PostMedia(
              media: _media,
              product: post.product,
              index: _mediaIndex,
              burst: _burst,
              isFresh: _isFresh,
              onIndex: (i) => setState(() => _mediaIndex = i),
              onTap: _openProduct,
              onDoubleTap: () => _toggleLike(fromDoubleTap: true),
              onAddToBag: _addableOfferId == null ? null : _addToBag,
            ),
          if (_media.length > 1)
            Padding(
              padding: const EdgeInsets.only(top: DsSpacing.sm),
              child: Center(
                child: _MediaDots(count: _media.length, index: _mediaIndex),
              ),
            ),
          _PostActions(
            liked: _liked,
            saved: _saved,
            commentsCount: post.commentsCount,
            sharesCount: post.sharesCount,
            onLike: _toggleLike,
            onComment: _openComments,
            onSave: _toggleSave,
            onShare: () {
              HapticFeedback.selectionClick();
              ref.read(sharePostUseCaseProvider).call(post.id);
            },
          ),
          _PostCaption(
            post: post,
            likes: _likes,
            // The quote canvas already set the caption in serif; repeating it
            // underneath would read as a stutter.
            showCaption: _media.isNotEmpty || post.hasProduct,
            expanded: _captionExpanded,
            onExpand: () => setState(() => _captionExpanded = true),
            onComments: _openComments,
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Header
// ---------------------------------------------------------------------------

class _PostHeader extends StatelessWidget {
  const _PostHeader({
    required this.post,
    required this.onAuthor,
    required this.onMore,
  });

  final Post post;
  final VoidCallback onAuthor;
  final VoidCallback? onMore;

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    final theme = Theme.of(context);
    final author = post.author;

    return Padding(
      // Directional: the tighter end inset belongs beside the "more" button,
      // which sits on the left in Arabic.
      padding: const EdgeInsetsDirectional.fromSTEB(
        DsSpacing.sm,
        DsSpacing.sm,
        DsSpacing.xs,
        DsSpacing.sm,
      ),
      child: Row(
        children: [
          DsAvatar(
            imageUrl: author.imageUrl,
            name: author.name,
            size: 46,
            hasRing: true,
            onTap: onAuthor,
          ),
          const SizedBox(width: DsSpacing.sm),
          Expanded(
            child: GestureDetector(
              onTap: onAuthor,
              behavior: HitTestBehavior.opaque,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        // Set in the display serif: the boutique's name is the
                        // masthead of its post, and Cairo picks up the Arabic
                        // through the family fallback.
                        child: Text(
                          author.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: c.onSurface,
                            fontFamily: DsTypography.fontFamilyDisplay,
                            fontFamilyFallback: DsTypography.displayFallback,
                            fontSize: DsTypography.titleSmall,
                            fontWeight: DsTypography.bold,
                            height: 1.25,
                          ),
                        ),
                      ),
                      if (author.isVerified) ...[
                        const SizedBox(width: DsSpacing.xxs),
                        Icon(
                          Icons.verified_rounded,
                          size: 15,
                          color: c.secondary,
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 1),
                  Row(
                    children: [
                      DsSparkle(size: 8, color: c.accent, opacity: 0.9),
                      const SizedBox(width: DsSpacing.xxs),
                      Flexible(
                        child: Text(
                          _subtitle(context, post),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: c.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (onMore != null)
            DsIconButton(
              icon: Icons.more_horiz_rounded,
              variant: DsIconButtonVariant.ghost,
              size: 36,
              onPressed: onMore,
            ),
        ],
      ),
    );
  }

  /// "Jewellery · 2h".
  ///
  /// Prefers the product's own category over [Post.category]: the latter is a
  /// coarse nine-way bucket that lands most of the real taxonomy — jewellery,
  /// lingerie, homeware — in "Gifts". The bucket is still the fallback for a
  /// post that tags nothing.
  static String _subtitle(BuildContext context, Post post) {
    final arabic = Localizations.localeOf(context).languageCode == 'ar';
    final category =
        post.product?.category.name(arabic: arabic) ?? post.category.label;
    return '$category · ${_shortTimeAgo(context, post.createdAt)}';
  }
}

// ---------------------------------------------------------------------------
// Media
// ---------------------------------------------------------------------------

class _PostMedia extends StatefulWidget {
  const _PostMedia({
    required this.media,
    required this.product,
    required this.index,
    required this.burst,
    required this.isFresh,
    required this.onIndex,
    required this.onTap,
    required this.onDoubleTap,
    required this.onAddToBag,
  });

  final List<MediaItem> media;
  final Product? product;
  final int index;

  /// Posted within the last few days — earns the champagne "new" ribbon.
  final bool isFresh;
  final VoidCallback? onAddToBag;
  final AnimationController burst;
  final ValueChanged<int> onIndex;
  final VoidCallback onTap;
  final VoidCallback onDoubleTap;

  @override
  State<_PostMedia> createState() => _PostMediaState();
}

class _PostMediaState extends State<_PostMedia> {
  final PageController _pages = PageController();

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    final product = widget.product;
    final count = math.max(widget.media.length, 1);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: DsSpacing.xs),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(DsRadius.xxl),
        child: GestureDetector(
          onTap: widget.onTap,
          onDoubleTap: widget.onDoubleTap,
          child: AspectRatio(
            aspectRatio: 4 / 5,
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (widget.media.isEmpty)
                  const _MediaFallback()
                else
                  PageView.builder(
                    controller: _pages,
                    physics: count > 1
                        ? const BouncingScrollPhysics()
                        : const NeverScrollableScrollPhysics(),
                    onPageChanged: widget.onIndex,
                    itemCount: count,
                    itemBuilder: (_, i) => _MediaFrame(item: widget.media[i]),
                  ),

                // Scrims: a whisper at the top so the badges read, a deeper one
                // at the foot so the frosted plate has something to sit on.
                IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(gradient: context.imageScrimTop),
                  ),
                ),
                IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(gradient: context.imageScrim),
                  ),
                ),

                PositionedDirectional(
                  top: DsSpacing.sm,
                  start: DsSpacing.sm,
                  child: Row(
                    children: [
                      if (product != null && product.hasDiscount) ...[
                        DsDiscountBadge(percentOff: product.discountPercent),
                        const SizedBox(width: DsSpacing.xxs),
                      ],
                      if (widget.isFresh) const _FreshRibbon(),
                    ],
                  ),
                ),

                PositionedDirectional(
                  top: DsSpacing.sm,
                  end: DsSpacing.sm,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      if (count > 1)
                        _CounterPill(index: widget.index, count: count),
                      if (product != null && product.rating > 0) ...[
                        if (count > 1) const SizedBox(height: DsSpacing.xxs),
                        _RatingChip(
                          rating: product.rating,
                          reviews: product.reviewsCount,
                        ),
                      ],
                    ],
                  ),
                ),

                if (product != null)
                  PositionedDirectional(
                    start: DsSpacing.sm,
                    end: DsSpacing.sm,
                    bottom: DsSpacing.sm,
                    child: _ShopPlate(
                      product: product,
                      onTap: widget.onTap,
                      onAddToBag: widget.onAddToBag,
                    ),
                  ),

                IgnorePointer(
                  child: Center(
                    child: _LoveBurst(
                      controller: widget.burst,
                      color: c.favorite,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MediaFrame extends StatelessWidget {
  const _MediaFrame({required this.item});

  final MediaItem item;

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    final url = item.displayUrl;
    if (url.isEmpty) return const _MediaFallback();

    return Stack(
      fit: StackFit.expand,
      children: [
        CachedNetworkImage(
          imageUrl: url,
          fit: BoxFit.cover,
          fadeInDuration: DsMotion.normal,
          placeholder: (_, _) => ColoredBox(color: c.shimmerBase),
          errorWidget: (_, _, _) => const _MediaFallback(),
        ),
        if (item.isVideo)
          Center(
            child: Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.black.withValues(alpha: 0.34),
                border: Border.all(color: Colors.white70, width: 1.4),
              ),
              child: const Icon(
                Icons.play_arrow_rounded,
                color: Colors.white,
                size: 30,
              ),
            ),
          ),
      ],
    );
  }
}

class _MediaFallback extends StatelessWidget {
  const _MediaFallback();

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    return ColoredBox(
      color: c.surfaceVariant,
      child: Center(
        child: DsSparkle(size: 34, color: c.primary, opacity: 0.4),
      ),
    );
  }
}

/// A painted canvas for a post that carries only words.
///
/// A boutique's note, a thank-you, an announcement — content with no gallery
/// and nothing tagged. Rather than leave a grey rectangle where an image
/// should be, the caption is set large in the display serif on a blush wash,
/// framed by sparkles. It still takes a double-tap, so loving a note feels no
/// different from loving a dress.
class _QuoteCanvas extends StatelessWidget {
  const _QuoteCanvas({
    required this.caption,
    required this.onDoubleTap,
    required this.burst,
  });

  final String caption;
  final VoidCallback onDoubleTap;
  final AnimationController burst;

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: DsSpacing.xs),
      child: GestureDetector(
        onDoubleTap: onDoubleTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 190),
          padding: const EdgeInsets.symmetric(
            horizontal: DsSpacing.xl,
            vertical: DsSpacing.xxl,
          ),
          decoration: BoxDecoration(
            gradient: context.softGradient,
            borderRadius: BorderRadius.circular(DsRadius.xxl),
            border: Border.all(color: c.primary.withValues(alpha: 0.14)),
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              PositionedDirectional(
                top: 0,
                start: 0,
                child: DsSparkle(size: 14, color: c.accent, opacity: 0.75),
              ),
              PositionedDirectional(
                bottom: 0,
                end: 0,
                child: DsSparkle(size: 11, color: c.primary, opacity: 0.6),
              ),
              Text(
                caption,
                textAlign: TextAlign.center,
                maxLines: 6,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: c.onSurface,
                  fontFamily: DsTypography.fontFamilyDisplay,
                  fontFamilyFallback: DsTypography.displayFallback,
                  fontSize: DsTypography.titleLarge,
                  fontWeight: DsTypography.semiBold,
                  height: 1.5,
                ),
              ),
              IgnorePointer(
                child: _LoveBurst(controller: burst, color: c.favorite),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// "1/3" over the gallery — frosted, never a hard black chip.
class _CounterPill extends StatelessWidget {
  const _CounterPill({required this.index, required this.count});

  final int index;
  final int count;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: DsRadius.borderPill,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: DsBlur.light, sigmaY: DsBlur.light),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: DsSpacing.xs,
            vertical: 3,
          ),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.28),
            borderRadius: DsRadius.borderPill,
            border: Border.all(color: Colors.white24),
          ),
          child: Text(
            '${index + 1}/$count',
            style: const TextStyle(
              color: Colors.white,
              fontSize: DsTypography.labelSmall,
              fontWeight: DsTypography.semiBold,
            ),
          ),
        ),
      ),
    );
  }
}

/// The frosted "shop this" plate floating over the foot of the image.
class _ShopPlate extends StatelessWidget {
  const _ShopPlate({
    required this.product,
    required this.onTap,
    this.onAddToBag,
  });

  final Product product;
  final VoidCallback onTap;

  /// Null when nothing is in stock to add — the plate then only navigates.
  final VoidCallback? onAddToBag;

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    final theme = Theme.of(context);

    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(DsRadius.xl),
        child: BackdropFilter(
          filter: ImageFilter.blur(
            sigmaX: DsBlur.medium,
            sigmaY: DsBlur.medium,
          ),
          child: Container(
            padding: const EdgeInsets.all(DsSpacing.xs),
            decoration: BoxDecoration(
              color: c.surface.withValues(alpha: 0.82),
              borderRadius: BorderRadius.circular(DsRadius.xl),
              border: Border.all(color: Colors.white.withValues(alpha: 0.28)),
            ),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    gradient: context.primaryGradient,
                    borderRadius: BorderRadius.circular(DsRadius.md),
                    boxShadow: context.glowShadow(
                      c.primary,
                      blur: 14,
                      alpha: 0.34,
                    ),
                  ),
                  child: Icon(
                    Icons.shopping_bag_outlined,
                    size: 19,
                    color: c.onPrimary,
                  ),
                ),
                const SizedBox(width: DsSpacing.xs),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        product.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: c.onSurface,
                          fontWeight: DsTypography.semiBold,
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(height: 1),
                      // Two flexible children split the row evenly when both
                      // want more than half, which was clipping the live price
                      // ("264,000 …") to make room for a decorative strike.
                      // The weights hand the price the larger share; the
                      // was-price gives way first.
                      Row(
                        children: [
                          Flexible(
                            flex: 3,
                            child: Text(
                              product.price?.format() ?? '',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: DsTypography.price(
                                c.price,
                                size: DsTypography.labelLarge,
                              ),
                            ),
                          ),
                          if (product.hasDiscount) ...[
                            const SizedBox(width: DsSpacing.xxs),
                            Flexible(
                              flex: 2,
                              child: Text(
                                product.compareAtPrice?.format() ?? '',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: DsTypography.priceStrike(
                                  c.onSurfaceVariant,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: DsSpacing.xxs),
                // The plate now closes a sale rather than only pointing at
                // one: tapping the bag drops the cheapest live offer straight
                // into the cart, without leaving the feed.
                if (onAddToBag != null)
                  _AddToBagButton(onTap: onAddToBag!)
                else
                  Padding(
                    padding: const EdgeInsetsDirectional.only(
                      end: DsSpacing.xs,
                    ),
                    child: Icon(
                      Icons.arrow_forward_rounded,
                      size: 17,
                      color: c.primary,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A champagne "just in" ribbon for a post only a few days old.
class _FreshRibbon extends StatelessWidget {
  const _FreshRibbon();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: DsSpacing.xs,
        vertical: 3,
      ),
      decoration: BoxDecoration(
        gradient: context.champagneGradient,
        borderRadius: DsRadius.borderPill,
        boxShadow: context.shadowXs,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const DsSparkle(size: 9, color: Color(0xFF79551F)),
          const SizedBox(width: DsSpacing.xxs),
          Text(
            context.l10n.justIn.toUpperCase(),
            style: const TextStyle(
              // Deep gold ink on the champagne wash — the one place a literal
              // colour beats a token, because the ribbon's ground is a fixed
              // brand gradient in both themes.
              color: Color(0xFF79551F),
              fontSize: DsTypography.labelSmall,
              fontWeight: DsTypography.bold,
              height: 1.1,
            ),
          ),
        ],
      ),
    );
  }
}

/// Rating over the media — social proof where the eye already is.
class _RatingChip extends StatelessWidget {
  const _RatingChip({required this.rating, required this.reviews});

  final double rating;
  final int reviews;

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    return ClipRRect(
      borderRadius: DsRadius.borderPill,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: DsBlur.light, sigmaY: DsBlur.light),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: DsSpacing.xs,
            vertical: 3,
          ),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.28),
            borderRadius: DsRadius.borderPill,
            border: Border.all(color: Colors.white24),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.star_rounded, size: 12, color: c.rating),
              const SizedBox(width: 3),
              Text(
                rating.toStringAsFixed(1),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: DsTypography.labelSmall,
                  fontWeight: DsTypography.bold,
                  height: 1.1,
                ),
              ),
              if (reviews > 0) ...[
                const SizedBox(width: 3),
                Text(
                  '(${formatCount(reviews)})',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.78),
                    fontSize: DsTypography.labelSmall,
                    height: 1.1,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// The gradient bag inside the shop plate.
class _AddToBagButton extends StatelessWidget {
  const _AddToBagButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          gradient: context.primaryGradient,
          borderRadius: BorderRadius.circular(DsRadius.md),
          boxShadow: context.glowShadow(c.primary, blur: 12, alpha: 0.36),
        ),
        child: Icon(Icons.add_rounded, size: 22, color: c.onPrimary),
      ),
    );
  }
}

/// Gallery position: soft dots with the active one stretched into a rose
/// capsule — quicker to read at a glance than a bare "2/5".
class _MediaDots extends StatelessWidget {
  const _MediaDots({required this.count, required this.index});

  final int count;
  final int index;

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < count; i++)
          AnimatedContainer(
            duration: DsMotion.fast,
            curve: Curves.easeOut,
            margin: const EdgeInsets.symmetric(horizontal: 3),
            width: i == index ? 18 : 6,
            height: 6,
            decoration: BoxDecoration(
              gradient: i == index ? context.primaryGradient : null,
              color: i == index ? null : c.border,
              borderRadius: DsRadius.borderPill,
            ),
          ),
      ],
    );
  }
}

/// The double-tap reward: one big heart plus a scatter of petals and sparkles.
class _LoveBurst extends StatelessWidget {
  const _LoveBurst({required this.controller, required this.color});

  final AnimationController controller;
  final Color color;

  static const int _petals = 9;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final v = controller.value;
        if (v == 0) return const SizedBox.shrink();

        final pop = Curves.easeOutBack.transform((v / 0.42).clamp(0.0, 1.0));
        final fade =
            1 - Curves.easeIn.transform(((v - 0.5) / 0.5).clamp(0.0, 1.0));
        final spread = Curves.easeOutCubic.transform(v);

        return Stack(
          alignment: Alignment.center,
          children: [
            for (var i = 0; i < _petals; i++) _petal(i, spread, fade),
            Opacity(
              opacity: fade,
              child: Transform.scale(
                scale: 0.45 + pop * 0.7,
                child: Icon(
                  Icons.favorite_rounded,
                  size: 104,
                  color: Colors.white.withValues(alpha: 0.94),
                  shadows: [
                    Shadow(
                      blurRadius: 30,
                      color: color.withValues(alpha: 0.55),
                    ),
                    const Shadow(blurRadius: 18, color: Colors.black26),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _petal(int i, double spread, double fade) {
    final angle = (i / _petals) * math.pi * 2 + 0.32;
    final distance = 34 + 82 * spread;
    final size = 9.0 + (i.isEven ? 7 : 3);
    return Transform.translate(
      offset: Offset(math.cos(angle) * distance, math.sin(angle) * distance),
      child: Opacity(
        opacity: fade * 0.9,
        child: Transform.rotate(
          angle: angle,
          child: Icon(
            i.isEven ? Icons.favorite_rounded : Icons.auto_awesome_rounded,
            size: size,
            color: i.isEven ? color : Colors.white,
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Actions
// ---------------------------------------------------------------------------

class _PostActions extends StatelessWidget {
  const _PostActions({
    required this.liked,
    required this.saved,
    required this.commentsCount,
    required this.sharesCount,
    required this.onLike,
    required this.onComment,
    required this.onSave,
    required this.onShare,
  });

  final bool liked;
  final bool saved;
  final int commentsCount;
  final int sharesCount;
  final VoidCallback onLike;
  final VoidCallback onComment;
  final VoidCallback onSave;
  final VoidCallback onShare;

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        DsSpacing.xs,
        DsSpacing.xs,
        DsSpacing.xs,
        DsSpacing.xxs,
      ),
      child: Row(
        children: [
          _ActionButton(
            icon: liked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
            color: liked ? c.favorite : c.onSurface,
            active: liked,
            onTap: onLike,
          ),
          _ActionButton(
            icon: Icons.mode_comment_outlined,
            color: c.onSurface,
            label: commentsCount > 0 ? formatCount(commentsCount) : null,
            onTap: onComment,
          ),
          _ActionButton(
            icon: Icons.send_rounded,
            color: c.onSurface,
            label: sharesCount > 0 ? formatCount(sharesCount) : null,
            onTap: onShare,
          ),
          const Spacer(),
          _ActionButton(
            icon: saved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
            color: saved ? c.secondary : c.onSurface,
            active: saved,
            onTap: onSave,
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.color,
    required this.onTap,
    this.label,
    this.active = false,
  });

  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final String? label;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return InkResponse(
      onTap: onTap,
      radius: 26,
      child: Padding(
        padding: const EdgeInsets.all(DsSpacing.xs),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedScale(
              scale: active ? 1.16 : 1,
              duration: DsMotion.fast,
              curve: DsMotion.softSpring,
              child: Icon(icon, size: DsConstraints.iconMd, color: color),
            ),
            if (label != null) ...[
              const SizedBox(width: DsSpacing.xxs),
              Text(
                label!,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: context.dsColors.onSurface,
                  fontWeight: DsTypography.medium,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Caption
// ---------------------------------------------------------------------------

class _PostCaption extends StatelessWidget {
  const _PostCaption({
    required this.post,
    required this.likes,
    required this.showCaption,
    required this.expanded,
    required this.onExpand,
    required this.onComments,
  });

  final Post post;
  final int likes;
  final bool showCaption;
  final bool expanded;
  final VoidCallback onExpand;
  final VoidCallback onComments;

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    final theme = Theme.of(context);
    final l10n = context.l10n;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        DsSpacing.sm,
        DsSpacing.xxs,
        DsSpacing.sm,
        DsSpacing.md,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (likes > 0)
            Row(
              children: [
                Icon(Icons.favorite_rounded, size: 13, color: c.favorite),
                const SizedBox(width: DsSpacing.xxs),
                Text(
                  l10n.postLikesCount(formatCount(likes)),
                  style: theme.textTheme.labelLarge?.copyWith(
                    fontWeight: DsTypography.semiBold,
                  ),
                ),
              ],
            ),
          if (showCaption && post.caption.isNotEmpty) ...[
            const SizedBox(height: DsSpacing.xxs),
            GestureDetector(
              onTap: expanded ? null : onExpand,
              child: RichText(
                maxLines: expanded ? null : 2,
                overflow: expanded ? TextOverflow.clip : TextOverflow.ellipsis,
                text: TextSpan(
                  style: theme.textTheme.bodyMedium?.copyWith(height: 1.45),
                  children: [
                    TextSpan(
                      text: '${post.author.name}  ',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: DsTypography.bold,
                      ),
                    ),
                    ..._captionSpans(post.caption, c.primary),
                    if (!expanded)
                      TextSpan(
                        text: '  ${l10n.postMore}',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: c.onSurfaceVariant,
                          fontWeight: DsTypography.semiBold,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
          if (post.commentsCount > 0) ...[
            const SizedBox(height: DsSpacing.xs),
            GestureDetector(
              onTap: onComments,
              child: Text(
                l10n.postViewComments(formatCount(post.commentsCount)),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: c.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Splits the caption so hashtags and mentions come through in brand rose —
  /// the one place in the card where copy is allowed to be colourful.
  static List<InlineSpan> _captionSpans(String caption, Color accent) {
    final tokens = caption.split(RegExp(r'(?=\s)|(?<=\s)'));
    return [
      for (final token in tokens)
        if (token.startsWith('#') || token.startsWith('@'))
          TextSpan(
            text: token,
            style: TextStyle(
              color: accent,
              fontWeight: DsTypography.semiBold,
            ),
          )
        else
          TextSpan(text: token),
    ];
  }
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Compact engagement counts — 1.2K, 3.4M.
String formatCount(int n) {
  if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
  if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
  return '$n';
}

String _shortTimeAgo(BuildContext context, DateTime date) {
  final l10n = context.l10n;
  final diff = DateTime.now().difference(date);
  if (diff.inMinutes < 1) return l10n.justNow;
  if (diff.inMinutes < 60) return l10n.shortMinutesAgo(diff.inMinutes);
  if (diff.inHours < 24) return l10n.shortHoursAgo(diff.inHours);
  if (diff.inDays < 7) return l10n.shortDaysAgo(diff.inDays);
  return l10n.shortWeeksAgo((diff.inDays / 7).floor());
}
