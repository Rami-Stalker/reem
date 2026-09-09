import 'dart:async';

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:reem/core/design_system/design_system.dart';
import 'package:reem/core/errors/failure.dart';
import 'package:reem/core/localization/l10n_extension.dart';
import 'package:reem/core/platform/app_haptics.dart';
import 'package:reem/core/result/result.dart';
import 'package:reem/core/router/route_paths.dart';
import 'package:reem/core/shared/entities/media.dart';
import 'package:reem/core/shared/entities/post.dart';
import 'package:reem/core/shared/entities/product.dart';
import 'package:reem/core/shared/services/share_service.dart';
import 'package:reem/core/shared/value_objects/money_format.dart';
import 'package:reem/core/sync/outbox_providers.dart';
import 'package:reem/features/auth/presentation/widgets/auth_prompt_sheet.dart';
import 'package:reem/features/cart/presentation/providers/cart_providers.dart';
import 'package:reem/features/social_posts/data/outbox_handlers.dart';
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
  late int _shares = widget.post.sharesCount;
  late int _comments = widget.post.commentsCount;
  bool _captionExpanded = false;
  bool _addingToBag = false;
  int _mediaIndex = 0;

  late final AnimationController _burst = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );

  @override
  void didUpdateWidget(ReemPostCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    // A refreshed feed hands the card a new `Post` carrying the server's own
    // tallies. They win over anything this card counted locally — otherwise a
    // comment she left would be added a second time on top of a count that
    // already includes it.
    final post = widget.post;
    if (post.id != oldWidget.post.id ||
        post.commentsCount != oldWidget.post.commentsCount) {
      _comments = post.commentsCount;
    }
  }

  @override
  void dispose() {
    _burst.dispose();
    super.dispose();
  }

  Post get post => widget.post;

  List<MediaItem> get _media => post.media;

  /// Every engagement is account-bound on the server — `/posts/:id/like` and
  /// its siblings carry no `@OptionalAuth`, unlike the read routes. Without
  /// this gate a guest saw a filled heart and got a silent 401: the tap looked
  /// like it worked and nothing was ever recorded.
  Future<bool> _requireAccount() async {
    return requireAuthenticatedUser(
      context,
      ref,
      title: context.l10n.signInToInteract,
      message: context.l10n.signInToInteractBody,
      from: RoutePaths.home,
    );
  }

  /// Decides what a failed engagement means, and does the right thing.
  ///
  /// Two failures wearing the same coat. A **network** failure means she is on
  /// a lift or a bad street: her tap is good, it simply has not arrived, so it
  /// goes in the outbox and the heart stays filled. Anything else — the post
  /// was deleted, the server refused — means the tap cannot succeed, and
  /// leaving it filled would be a lie she discovers weeks later.
  Future<void> _settleFailure(
    Failure failure, {
    required String kind,
    required bool desired,
    required VoidCallback restore,
  }) async {
    if (failure is NetworkFailure) {
      await ref
          .read(outboxProvider)
          .enqueue(kind: kind, entityId: post.id, desired: desired);
      // No snackbar. She did the thing; the app is holding it. Telling her
      // about our transport problem is our anxiety, not her business.
      return;
    }
    if (!mounted) return;
    setState(restore);
    DsSnackbar.error(context, context.l10n.actionDidNotSave);
  }

  Future<void> _toggleLike({bool fromDoubleTap = false}) async {
    // The petals and the haptic fire first either way: they acknowledge the
    // gesture, and a double tap on an already-liked post is still a gesture.
    if (fromDoubleTap) {
      unawaited(_burst.forward(from: 0));
      AppHaptics.light();
    } else {
      AppHaptics.selection();
    }

    final willLike = fromDoubleTap ? true : !_liked;
    if (willLike == _liked) return;
    if (!await _requireAccount()) return;
    if (!mounted) return;

    final wasLiked = _liked;
    final wasLikes = _likes;
    setState(() {
      _likes += willLike ? 1 : -1;
      _liked = willLike;
    });

    final result = await ref.read(toggleLikeUseCaseProvider).call(post.id);
    if (result case Error(:final failure)) {
      await _settleFailure(
        failure,
        kind: EngagementIntents.like,
        desired: willLike,
        restore: () {
          _liked = wasLiked;
          _likes = wasLikes;
        },
      );
    }
  }

  Future<void> _toggleSave() async {
    AppHaptics.selection();
    if (!await _requireAccount()) return;
    if (!mounted) return;

    final wasSaved = _saved;
    setState(() => _saved = !_saved);

    // Where it went. A silent bookmark left the shopper with no idea the post
    // had gone anywhere at all — the answer is «المفضّلة», and the snackbar
    // takes her there rather than only naming it.
    final l10n = context.l10n;
    DsSnackbar.show(
      context,
      message: wasSaved ? l10n.postUnsaved : l10n.postSaved,
      type: DsSnackbarType.success,
      actionLabel: wasSaved ? null : l10n.viewSaved,
      onAction: wasSaved ? null : () => context.push(RoutePaths.favorites),
    );

    final result = await ref.read(toggleSaveUseCaseProvider).call(post.id);
    if (result case Error(:final failure)) {
      await _settleFailure(
        failure,
        kind: EngagementIntents.save,
        desired: !wasSaved,
        restore: () => _saved = wasSaved,
      );
    }
  }

  /// Opens the OS share sheet, and only tells the server about a share she
  /// actually went through with — a sheet she dismissed is not a share.
  Future<void> _share() async {
    AppHaptics.selection();
    final shared = await ShareService.post(
      context: context,
      postId: post.id,
      caption: post.caption,
      authorName: post.author.name,
    );
    if (!shared || !mounted) return;

    setState(() => _shares += 1);
    final result = await ref.read(sharePostUseCaseProvider).call(post.id);
    if (result case Error()) {
      // The share happened; only the tally failed. Correcting the number is
      // right, but there is nothing here worth interrupting her about.
      if (mounted) setState(() => _shares -= 1);
    }
  }

  Future<void> _openComments() async {
    if (!await _requireAccount()) return;
    if (!mounted) return;
    await showCommentSheet(
      context,
      post.id,
      // The tally under the post moves as she comments, rather than staying
      // frozen at whatever the feed was fetched with.
      onCountChanged: (delta) {
        if (mounted) setState(() => _comments += delta);
      },
    );
  }

  /// Only meaningful when the post tags something; a look or an announcement
  /// has nowhere to send her, so the affordances that call this are hidden.
  void _openProduct() {
    final product = post.product;
    if (product == null) return;
    context.push(RoutePaths.productDetailsOf(product.id));
  }

  void _openAuthor() => context.push(RoutePaths.userProfileOf(post.author.id));

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
    AppHaptics.confirm();
    final added = await ref
        .read(cartNotifierProvider.notifier)
        .add(offerId: offerId);
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
            commentsCount: _comments,
            sharesCount: _shares,
            onLike: _toggleLike,
            onComment: _openComments,
            onSave: _toggleSave,
            onShare: _share,
          ),
          _PostCaption(
            post: post,
            likes: _likes,
            comments: _comments,
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
                          style: context.dsText.tileTitle.displayFamily.bold
                              .tint(c.onSurface)
                              .copyWith(height: 1.25),
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
                  DsGaps.vXxxs,
                  Row(
                    children: [
                      DsSparkle(size: 8, color: c.accent, opacity: 0.9),
                      const SizedBox(width: DsSpacing.xxs),
                      Flexible(
                        child: Text(
                          _subtitle(context, post),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: context.dsText.caption.copyWith(
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
            tooltip: 'خيارات المنشور',
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
                  const DsMediaFallback()
                else
                  PageView.builder(
                    controller: _pages,
                    physics: count > 1
                        ? null
                        : const NeverScrollableScrollPhysics(),
                    onPageChanged: widget.onIndex,
                    itemCount: count,
                    itemBuilder: (_, i) => DsMediaFrame(item: widget.media[i]),
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
                        DsCounterPill(index: widget.index, count: count),
                      if (product != null && product.rating > 0) ...[
                        if (count > 1) const SizedBox(height: DsSpacing.xxs),
                        DsRatingChip(
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
                    child: DsShopPlate(
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
                style: context.dsText.sectionTitle.displayFamily
                    .tint(c.onSurface)
                    .copyWith(height: 1.5),
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

/// A champagne "just in" ribbon for a post only a few days old.
class _FreshRibbon extends StatelessWidget {
  const _FreshRibbon();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: DsSpacing.xs,
        vertical: DsSpacing.xxs,
      ),
      decoration: BoxDecoration(
        gradient: context.champagneGradient,
        borderRadius: DsRadius.borderPill,
        boxShadow: context.shadowXs,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const DsSparkle(size: 9, color: DsColors.onChampagne),
          const SizedBox(width: DsSpacing.xxs),
          Text(
            context.l10n.justIn.toUpperCase(),
            // Deep gold ink: the ribbon's ground is the champagne gradient,
            // which is fixed in both themes, so the text must be too.
            style: context.dsText.badge.tint(DsColors.onChampagne),
          ),
        ],
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
            margin: const EdgeInsets.symmetric(horizontal: DsSpacing.xxs),
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
                  color: DsColors.onMedia.withValues(alpha: 0.94),
                  shadows: [
                    Shadow(
                      blurRadius: 30,
                      color: color.withValues(alpha: 0.55),
                    ),
                    const Shadow(blurRadius: 18, color: DsColors.mediaScrim),
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
            color: i.isEven ? color : DsColors.onMedia,
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
            icon: liked
                ? Icons.favorite_rounded
                : Icons.favorite_border_rounded,
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
            icon: saved
                ? Icons.bookmark_rounded
                : Icons.bookmark_border_rounded,
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
                style: context.dsText.label.copyWith(
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
    required this.comments,
    required this.showCaption,
    required this.expanded,
    required this.onExpand,
    required this.onComments,
  });

  final Post post;
  final int likes;

  /// The card's live tally, not `post.commentsCount` — the two differ from the
  /// moment she leaves a comment until the feed is next fetched.
  final int comments;
  final bool showCaption;
  final bool expanded;
  final VoidCallback onExpand;
  final VoidCallback onComments;

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
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
                  style: context.dsText.labelLarge.copyWith(
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
                  style: context.dsText.body.copyWith(height: 1.45),
                  children: [
                    TextSpan(
                      text: '${post.author.name}  ',
                      style: context.dsText.body.copyWith(
                        fontWeight: DsTypography.bold,
                      ),
                    ),
                    ..._captionSpans(post.caption, c.primary),
                    if (!expanded)
                      TextSpan(
                        text: '  ${l10n.postMore}',
                        style: context.dsText.body.copyWith(
                          color: c.onSurfaceVariant,
                          fontWeight: DsTypography.semiBold,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
          if (comments > 0) ...[
            const SizedBox(height: DsSpacing.xs),
            GestureDetector(
              onTap: onComments,
              child: Text(
                l10n.postViewComments(formatCount(comments)),
                style: context.dsText.cardSubtitle.copyWith(
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
            // ds-ignore: no-hand-rolled-text-styles -- a TextSpan child is an
            // overlay on the parent span, so it must not carry a full role or
            // it overrides the caption size the caller chose.
            style: TextStyle(color: accent, fontWeight: DsTypography.semiBold),
          )
        else
          TextSpan(text: token),
    ];
  }
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

String _shortTimeAgo(BuildContext context, DateTime date) {
  final l10n = context.l10n;
  final diff = DateTime.now().difference(date);
  if (diff.inMinutes < 1) return l10n.justNow;
  if (diff.inMinutes < 60) return l10n.shortMinutesAgo(diff.inMinutes);
  if (diff.inHours < 24) return l10n.shortHoursAgo(diff.inHours);
  if (diff.inDays < 7) return l10n.shortDaysAgo(diff.inDays);
  return l10n.shortWeeksAgo((diff.inDays / 7).floor());
}
