import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:reem/core/design_system/design_system.dart';
import 'package:reem/core/errors/failure.dart';
import 'package:reem/core/localization/l10n_extension.dart';
import 'package:reem/core/platform/app_haptics.dart';
import 'package:reem/core/result/result.dart';
import 'package:reem/core/router/route_paths.dart';
import 'package:reem/core/shared/entities/post.dart';
import 'package:reem/core/shared/services/share_service.dart';
import 'package:reem/core/sync/outbox_providers.dart';
import 'package:reem/features/auth/presentation/providers/auth_provider.dart';
import 'package:reem/features/auth/presentation/widgets/auth_prompt_sheet.dart';
import 'package:reem/features/cart/presentation/providers/cart_providers.dart';
import 'package:reem/features/home/presentation/providers/home_provider.dart';
import 'package:reem/features/home/presentation/widgets/post_closet_strip.dart';
import 'package:reem/features/social/presentation/providers/social_providers.dart';
import 'package:reem/features/social/presentation/widgets/post_options_sheet.dart';
import 'package:reem/features/social_posts/data/outbox_handlers.dart';
import 'package:reem/features/social_posts/domain/entities/comment_thread.dart';
import 'package:reem/features/social_posts/presentation/providers/social_posts_providers.dart';
import 'package:reem/features/social_posts/presentation/widgets/comment_sheet.dart';

/// The centrepiece of Reem's home: a product told as a **post**.
///
/// The brief was Instagram, only lovelier: a swipeable gallery, a
/// rose-to-champagne thread around the card, a frosted "shop this" plate over
/// the foot of the image, and a double-tap that scatters petals. The shape
/// itself lives in the design system (`DsPostFrame`, `DsPostHeader`,
/// `DsPostGallery`, `DsPostActionBar`, `DsPostCaption`) so a product on a
/// department page is drawn by exactly the same pieces; this widget is what
/// makes them a *post* — its likes, its thread, its menu.
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
  late bool _reshared = widget.post.isReshared;
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
    if (post.id != oldWidget.post.id ||
        post.isReshared != oldWidget.post.isReshared) {
      _reshared = post.isReshared;
    }
  }

  @override
  void dispose() {
    _burst.dispose();
    super.dispose();
  }

  Post get post => widget.post;

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

  /// «أضيفي إلى صفحتي» — a pointer to the boutique's post on her page, never a
  /// copy, so the boutique keeps the credit and a takedown reaches her page.
  Future<void> _toggleReshare() async {
    AppHaptics.selection();
    if (!await _requireAccount()) return;
    if (!mounted) return;

    final l10n = context.l10n;
    final adding = !_reshared;
    setState(() => _reshared = adding);

    final repository = ref.read(socialRepositoryProvider);
    final result = adding
        ? await repository.reshare(post.id)
        : await repository.unreshare(post.id);
    if (!mounted) return;

    switch (result) {
      case Success(:final data):
        setState(() => _reshared = data);
        if (adding) AppHaptics.confirm();
        final me = ref.read(authNotifierProvider).user;
        final router = GoRouter.of(context);
        DsSnackbar.show(
          context,
          message: data ? l10n.productPickedDone : l10n.productUnpickedDone,
          type: DsSnackbarType.success,
          actionLabel: data && me != null ? l10n.viewMyPage : null,
          onAction: data && me != null
              ? () => router.push(RoutePaths.userProfileOf(me.id))
              : null,
        );
      case Error(:final failure):
        setState(() => _reshared = !adding);
        DsSnackbar.error(context, failure.message);
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
      CommentThread.post(post.id),
      // The tally under the post moves as she comments, rather than staying
      // frozen at whatever the feed was fetched with.
      onCountChanged: (delta) {
        if (mounted) setState(() => _comments += delta);
      },
    );
  }

  /// The «…» menu. The home feed owns the list, so hiding a post or an
  /// account takes the cards out of it here — and «تراجع» puts them back
  /// where they were.
  Future<void> _openMenu() async {
    final home = ref.read(homeNotifierProvider.notifier);
    var removed = <(int, Post)>[];
    final authorId = post.author.id;
    final postId = post.id;

    await showPostOptions(
      context,
      ref,
      target: PostMenuTarget(
        contentId: postId,
        author: post.author,
        productId: post.product?.id,
        isReshared: _reshared,
      ),
      callbacks: PostMenuCallbacks(
        onHidden: () => removed = home.removeFromFeed((p) => p.id == postId),
        onUnhidden: () => home.restoreToFeed(removed),
        onMuted: () =>
            removed = home.removeFromFeed((p) => p.author.id == authorId),
        onUnmuted: () => home.restoreToFeed(removed),
        onToggleReshare: _toggleReshare,
      ),
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

  /// "Jewellery · 2h".
  ///
  /// Prefers the product's own category over [Post.category]: the latter is a
  /// coarse nine-way bucket that lands most of the real taxonomy — jewellery,
  /// lingerie, homeware — in "Gifts". The bucket is still the fallback for a
  /// post that tags nothing.
  String _subtitle(BuildContext context) {
    final arabic = Localizations.localeOf(context).languageCode == 'ar';
    final category =
        post.product?.category.name(arabic: arabic) ?? post.category.label;
    return '$category · ${dsShortTimeAgo(context, post.createdAt)}';
  }

  @override
  Widget build(BuildContext context) {
    final media = post.media;
    final me = ref.watch(authNotifierProvider.select((s) => s.user?.id));
    final isMine = me != null && me == post.author.id;

    return DsPostFrame(
      featured: widget.featured,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          DsPostHeader(
            name: post.author.name,
            imageUrl: post.author.imageUrl,
            isVerified: post.author.isVerified,
            subtitle: _subtitle(context),
            onAuthor: _openAuthor,
            onMore: _openMenu,
          ),
          // A post with nothing to show and nothing to shop is a note, not a
          // gallery: give it a painted canvas rather than an empty frame.
          if (media.isEmpty && !post.hasProduct)
            DsPostQuote(
              caption: post.caption,
              onDoubleTap: () => _toggleLike(fromDoubleTap: true),
              burst: _burst,
            )
          else
            DsPostGallery(
              media: media,
              product: post.product,
              index: _mediaIndex,
              burst: _burst,
              isFresh: _isFresh,
              onIndex: (i) => setState(() => _mediaIndex = i),
              onTap: _openProduct,
              onDoubleTap: () => _toggleLike(fromDoubleTap: true),
              onAddToBag: _addableOfferId == null ? null : _addToBag,
            ),
          if (media.length > 1)
            Padding(
              padding: const EdgeInsets.only(top: DsSpacing.sm),
              child: Center(
                child: DsPostDots(count: media.length, index: _mediaIndex),
              ),
            ),
          DsPostActionBar(
            liked: _liked,
            saved: _saved,
            picked: _reshared,
            commentsCount: _comments,
            sharesCount: _shares,
            onLike: _toggleLike,
            onComment: _openComments,
            onSave: _toggleSave,
            onShare: _share,
            // Her own post is already on her page.
            onPick: isMine ? null : _toggleReshare,
          ),
          DsPostCaption(
            authorName: post.author.name,
            caption: post.caption,
            likes: _likes,
            comments: _comments,
            // The quote canvas already set the caption in serif; repeating it
            // underneath would read as a stutter.
            showCaption: media.isNotEmpty || post.hasProduct,
            expanded: _captionExpanded,
            onExpand: () => setState(() => _captionExpanded = true),
            onComments: _openComments,
          ),
          // A guest has no closet, and asking for one would only collect a
          // 401 per post.
          if (post.product case final product? when me != null)
            PostClosetStrip(productId: product.id),
        ],
      ),
    );
  }
}
