import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ohara/core/design_system/design_system.dart';
import 'package:ohara/core/localization/l10n_extension.dart';
import 'package:ohara/core/router/route_paths.dart';
import 'package:ohara/core/shared/services/share_service.dart';
import 'package:ohara/features/auth/presentation/providers/auth_provider.dart';
import 'package:ohara/features/auth/presentation/widgets/auth_prompt_sheet.dart';
import 'package:ohara/features/discovery/presentation/providers/sponsored_providers.dart';
import 'package:ohara/features/profile/presentation/widgets/save_to_collection_sheet.dart';
import 'package:ohara/features/social/domain/entities/content.dart';
import 'package:ohara/features/social/domain/repositories/social_repository.dart';
import 'package:ohara/features/social/presentation/open_stories.dart';
import 'package:ohara/features/social/presentation/providers/content_feed_notifier.dart';
import 'package:ohara/features/social/presentation/providers/social_providers.dart';
import 'package:ohara/features/social/presentation/widgets/community_chrome.dart';
import 'package:ohara/features/social/presentation/widgets/content_card.dart';
import 'package:ohara/features/social/presentation/widgets/content_comments_sheet.dart';
import 'package:ohara/features/social/presentation/widgets/post_options_sheet.dart';
import 'package:ohara/features/social/presentation/widgets/reshare_sheet.dart';

/// The social feed: what everyone is posting, and what the women she follows
/// are posting.
///
/// Two tabs rather than one blended feed. The client asked for a mixed feed
/// (followed + suggested) and that is what «اكتشفي» is; «أتابع» is the other
/// half, and separating them means a woman who follows six boutiques can
/// actually find their posts rather than hunting for them among two hundred
/// suggestions.
///
/// The two halves are pages she can swipe between under one frosted header,
/// each keeping its place: leaving «أتابع» for a look in «اكتشفي» and coming
/// back finds her where she was, not at the top of a refetched list.
class SocialFeedScreen extends ConsumerStatefulWidget {
  const SocialFeedScreen({super.key});

  @override
  ConsumerState<SocialFeedScreen> createState() => _SocialFeedScreenState();
}

class _SocialFeedScreenState extends ConsumerState<SocialFeedScreen> {
  final _pages = PageController();
  final _scrolls = [ScrollController(), ScrollController()];
  bool _shareVisible = true;

  @override
  void dispose() {
    _pages.dispose();
    for (final scroll in _scrolls) {
      scroll.dispose();
    }
    super.dispose();
  }

  int get _current => _pages.hasClients ? (_pages.page ?? 0).round() : 0;

  /// Tapping the half she is already on takes her back to its top — the one
  /// gesture every feed has taught her.
  void _select(int index) {
    if (index == _current) {
      _toTop(index);
      return;
    }
    unawaited(
      _pages.animateToPage(
        index,
        duration: DsReducedMotion.duration(DsDurations.moderate),
        curve: DsCurves.emphasized,
      ),
    );
  }

  void _toTop(int index) {
    final scroll = _scrolls[index];
    if (!scroll.hasClients) return;
    unawaited(
      scroll.animateTo(
        0,
        duration: DsReducedMotion.duration(DsDurations.slow),
        curve: DsCurves.emphasized,
      ),
    );
  }

  /// The share pill steps aside while she reads downward and returns the
  /// moment she scrolls back or stops.
  bool _onScroll(UserScrollNotification notification) {
    // The feeds sit one level inside the page view; the page view's own
    // sideways swipes are not reading.
    if (notification.metrics.axis != Axis.vertical) return false;
    final visible = switch (notification.direction) {
      ScrollDirection.reverse => false,
      ScrollDirection.forward => true,
      ScrollDirection.idle => _shareVisible,
    };
    if (visible != _shareVisible) setState(() => _shareVisible = visible);
    return false;
  }

  Future<void> _compose() async {
    final signedIn = await requireAuthenticatedUser(
      context,
      ref,
      title: context.l10n.signInToInteract,
      message: context.l10n.signInToInteractBody,
      from: RoutePaths.socialFeed,
    );
    if (!signedIn || !mounted) return;
    await context.push(RoutePaths.compose);
  }

  @override
  Widget build(BuildContext context) {
    final p = context.boutique;
    final headerExtent =
        MediaQuery.paddingOf(context).top + CommunityHeader.extent;

    return Scaffold(
      // A pushed route: nothing is painted under it, so a transparent ground
      // left the feed floating on black. The boutique's silk goes here.
      backgroundColor: p.background,
      body: Stack(
        children: [
          const Positioned.fill(child: CustomerBackdrop()),
          NotificationListener<UserScrollNotification>(
            onNotification: _onScroll,
            child: PageView(
              controller: _pages,
              onPageChanged: (_) {
                if (!_shareVisible) setState(() => _shareVisible = true);
              },
              children: [
                _FeedPage(
                  feed: CommunityFeed.discover,
                  scroll: _scrolls[0],
                  topInset: headerExtent,
                  onBackToTop: () => _toTop(0),
                  onExplore: () => _select(0),
                ),
                _FeedPage(
                  feed: CommunityFeed.following,
                  scroll: _scrolls[1],
                  topInset: headerExtent,
                  onBackToTop: () => _toTop(1),
                  onExplore: () => _select(0),
                ),
              ],
            ),
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: CommunityHeader(
              pages: _pages,
              onSelect: _select,
              onOpenReels: () => context.push(RoutePaths.reels),
            ),
          ),
          PositionedDirectional(
            bottom: MediaQuery.paddingOf(context).bottom + DsSpacing.lg,
            start: DsSpacing.none,
            end: DsSpacing.none,
            child: Center(
              child: ShareLookButton(
                visible: _shareVisible,
                onPressed: _compose,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// One half of the community, paged, kept alive while she visits the other.
class _FeedPage extends ConsumerStatefulWidget {
  const _FeedPage({
    required this.feed,
    required this.scroll,
    required this.topInset,
    required this.onBackToTop,
    required this.onExplore,
  });

  final CommunityFeed feed;
  final ScrollController scroll;
  final double topInset;
  final VoidCallback onBackToTop;

  /// Takes her to «اكتشفي» — the way out of an empty «أتابع».
  final VoidCallback onExplore;

  @override
  ConsumerState<_FeedPage> createState() => _FeedPageState();
}

class _FeedPageState extends ConsumerState<_FeedPage>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  bool get _isDiscover => widget.feed == CommunityFeed.discover;

  TimelineFeedNotifier get _notifier =>
      ref.read(communityFeedProvider(widget.feed).notifier);

  /// Fetch the next page while there is still a screenful to read, so the
  /// spinner is rarely the thing she is looking at. A page that just failed
  /// waits for her to ask again, rather than being retried on every pixel of
  /// scroll.
  bool _onScroll(ScrollNotification notification) {
    if (notification.depth != 0) return false;
    final metrics = notification.metrics;
    final state = ref.read(communityFeedProvider(widget.feed));
    if (state.error == null &&
        metrics.maxScrollExtent - metrics.pixels < 900) {
      unawaited(_notifier.loadMore());
    }
    return false;
  }

  Future<void> _refresh() async {
    if (_isDiscover) ref.invalidate(storiesTrayProvider);
    await _notifier.refresh();
    if (!mounted) return;
    final error = ref.read(communityFeedProvider(widget.feed)).error;
    if (error != null) DsSnackbar.error(context, error);
  }

  Future<bool> _signedIn() => requireAuthenticatedUser(
    context,
    ref,
    title: context.l10n.signInToInteract,
    message: context.l10n.signInToInteractBody,
    from: RoutePaths.socialFeed,
  );

  Future<void> _signIn() => showAuthPrompt(
    context,
    title: context.l10n.signInToInteract,
    message: context.l10n.signInToInteractBody,
    from: RoutePaths.socialFeed,
  );

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final l10n = context.l10n;
    final signedIn = ref.watch(
      authNotifierProvider.select((s) => s.isAuthenticated),
    );

    // «أتابع» is hers alone; signed out, there is nobody to follow yet.
    if (!_isDiscover && !signedIn) {
      return _scrollable(
        refreshable: false,
        slivers: [
          SliverFillRemaining(
            hasScrollBody: false,
            child: Center(
              child: CommunityInviteCard(
                icon: Icons.favorite_rounded,
                title: l10n.socialFeedGuestFollowingTitle,
                message: l10n.socialFeedGuestFollowingBody,
                actionLabel: l10n.signIn,
                actionIcon: Icons.login_rounded,
                onAction: _signIn,
                secondaryLabel: l10n.socialFeedExploreAction,
                onSecondary: widget.onExplore,
              ),
            ),
          ),
        ],
      );
    }

    final state = ref.watch(communityFeedProvider(widget.feed));
    final me = ref.watch(authNotifierProvider.select((s) => s.user?.id));

    final heading = SliverToBoxAdapter(
      child: CommunitySectionHeading(
        eyebrow: _isDiscover
            ? l10n.socialFeedDiscoverEyebrow
            : l10n.socialFeedFollowingEyebrow,
        title: _isDiscover
            ? l10n.socialFeedDiscoverHeading
            : l10n.socialFeedFollowingHeading,
      ),
    );

    final List<Widget> body;
    if (state.isLoading && state.items.isEmpty) {
      body = [
        heading,
        SliverList.separated(
          itemCount: 2,
          separatorBuilder: (_, _) => DsGaps.vLg,
          itemBuilder: (_, _) => const Padding(
            padding: EdgeInsets.symmetric(horizontal: DsSpacing.gutter),
            child: DsPostCardSkeleton(mediaAspectRatio: 0.8),
          ),
        ),
      ];
    } else if (state.hasError) {
      body = [
        SliverFillRemaining(
          hasScrollBody: false,
          child: DsErrorState(message: state.error, onRetry: _notifier.load),
        ),
      ];
    } else if (state.items.isEmpty) {
      body = [
        SliverFillRemaining(
          hasScrollBody: false,
          child: Center(
            child: _isDiscover
                ? DsEmptyState(
                    icon: Icons.auto_awesome_rounded,
                    title: l10n.socialFeedEmptyTitle,
                    message: l10n.socialFeedEmptyBody,
                  )
                : CommunityInviteCard(
                    icon: Icons.person_add_alt_1_rounded,
                    title: l10n.socialFeedFollowingEmptyTitle,
                    message: l10n.socialFeedFollowingEmptyBody,
                    actionLabel: l10n.socialFeedExploreAction,
                    actionIcon: Icons.auto_awesome_rounded,
                    onAction: widget.onExplore,
                  ),
          ),
        ),
      ];
    } else {
      body = [
        heading,
        SliverList.separated(
          itemCount: state.items.length,
          separatorBuilder: (_, _) => DsGaps.vXl,
          itemBuilder: (context, index) {
            final card = _card(state.items[index], index: index, me: me);
            // Only the first screenful rises in; a card scrolled back into
            // view should simply be there.
            return index < 3
                ? DsStaggerAnimations.item(index: index, child: card)
                : card;
          },
        ),
        SliverToBoxAdapter(
          child: CommunityFeedFooter(
            isLoadingMore: state.isLoadingMore,
            hasMore: state.hasNextPage,
            failed: state.error != null,
            onRetry: () => unawaited(_notifier.loadMore()),
            onBackToTop: widget.onBackToTop,
          ),
        ),
      ];
    }

    return _scrollable(
      slivers: [
        if (_isDiscover) const _StoriesTray(),
        ...body,
      ],
    );
  }

  Widget _scrollable({required List<Widget> slivers, bool refreshable = true}) {
    final view = NotificationListener<ScrollNotification>(
      onNotification: _onScroll,
      child: CustomScrollView(
        controller: widget.scroll,
        slivers: [
          SliverToBoxAdapter(
            child: SizedBox(height: widget.topInset + DsSpacing.lg),
          ),
          ...slivers,
          // Room for the share pill, so the last card's actions stay tappable.
          const SliverToBoxAdapter(
            child: SizedBox(height: DsSizes.bottomSafeGap + DsSpacing.xl),
          ),
        ],
      ),
    );
    if (!refreshable) return view;
    final p = context.boutique;
    return RefreshIndicator(
      onRefresh: _refresh,
      color: p.primary,
      backgroundColor: p.surface,
      edgeOffset: widget.topInset,
      child: view,
    );
  }

  Widget _card(TimelineEntry entry, {required int index, String? me}) {
    // A reshare is drawn as the boutique's own post, with no «أضافته …»
    // band above it — the client asked for that band to go everywhere.
    final content = entry.content;
    final mine = content.author.id == me;

    return ContentCard(
      key: ValueKey(entry.entryId),
      content: content,
      featured: index == 0,
      onOpenAuthor: (userId) =>
          unawaited(context.push(RoutePaths.userProfileOf(userId))),
      onOpenProduct: (productId) {
        // A tap on a paid post is credited to the offer that paid for it.
        if (content.sponsorship case final sponsored?) {
          ref
              .read(discoverySignalsProvider)
              .sponsoredTapped(
                offerId: sponsored.offerId,
                placement: sponsored.placement,
              );
        }
        unawaited(context.push(RoutePaths.productDetailsOf(productId)));
      },
      onLike: () => _like(content),
      onReact: (glyph) => _react(content, glyph),
      onSave: () => _save(content),
      onComment: () => _comment(content),
      onShare: () => _share(content),
      // She cannot add her own post to her own page.
      onReshare: mine ? null : () => _reshare(content),
      onMore: () => _openMenu(content, me),
    );
  }

  Future<void> _react(Content content, String? glyph) async {
    if (!await _signedIn() || !mounted) return;
    await _notifier.react(content.id, glyph);
  }

  Future<void> _like(Content content) async {
    if (!await _signedIn() || !mounted) return;
    await _notifier.toggleLike(content.id);
  }

  Future<void> _save(Content content) async {
    if (!await _signedIn() || !mounted) return;
    final wasSaved = content.viewer.isSaved;
    final nowSaved = await _notifier.toggleSave(content.id);
    // Newly saved: ask where to keep it, the same way a product does.
    if (wasSaved || !nowSaved || !mounted) return;
    await SaveToCollectionSheet.show(
      context,
      kind: SaveTargetKind.post,
      targetId: content.id,
    );
  }

  Future<void> _comment(Content content) async {
    if (!await _signedIn() || !mounted) return;
    final notifier = _notifier;
    final delta = await showContentComments(context, contentId: content.id);
    if (!mounted) return;
    notifier.adjustComments(content.id, delta);
  }

  Future<void> _share(Content content) async {
    final notifier = _notifier;
    final shared = await ShareService.post(
      context: context,
      postId: content.id,
      caption: content.caption,
      authorName: content.author.name,
      imageUrl: content.shareImageUrl,
    );
    // A share sheet she dismissed is not a share, and a guest's share is
    // nobody's to count.
    if (!shared || !mounted) return;
    if (!ref.read(authNotifierProvider).isAuthenticated) return;
    await notifier.recordShare(content.id);
  }

  Future<void> _reshare(Content content) async {
    if (!await _signedIn() || !mounted) return;
    final notifier = _notifier;
    final String? failure;
    if (content.viewer.isReshared) {
      failure = await notifier.toggleReshare(content.id);
    } else {
      final note = await showReshareSheet(context, content: content);
      if (note == null || !mounted) return;
      failure = await notifier.toggleReshare(
        content.id,
        note: note.isEmpty ? null : note,
      );
    }
    if (failure != null && mounted) DsSnackbar.error(context, failure);
  }

  /// The «…» menu. Hiding a post or an account takes the cards out of this
  /// feed at once; «تراجع» puts them back where they stood.
  Future<void> _openMenu(Content content, String? me) async {
    final notifier = _notifier;
    var removed = <(int, TimelineEntry)>[];
    final authorId = content.author.id;
    final mine = authorId == me;
    await showPostOptions(
      context,
      ref,
      target: PostMenuTarget(
        contentId: content.id,
        author: content.author,
        productId: content.productTags.isEmpty
            ? null
            : content.productTags.first.product.id,
        isReshared: content.viewer.isReshared,
        content: content,
      ),
      callbacks: PostMenuCallbacks(
        onEdited: mine ? notifier.replace : null,
        onDeleted: mine ? () => notifier.drop(content.id) : null,
        onHidden: () =>
            removed = notifier.removeWhere((item) => item.id == content.id),
        onUnhidden: () => notifier.restore(removed),
        onMuted: () =>
            removed = notifier.removeWhere((item) => item.author.id == authorId),
        onUnmuted: () => notifier.restore(removed),
        onToggleReshare: mine ? null : () => _reshare(content),
      ),
    );
  }
}

/// Live stories, along the top of «اكتشفي», under their own heading.
class _StoriesTray extends ConsumerWidget {
  const _StoriesTray();

  static const double _ring = DsSizes.storyRing;
  static const double _bubbleWidth = DsSizes.storyRing + DsSpacing.md;

  /// Ring, gap and one line of name.
  static const double _height = DsSizes.storyRing + DsSpacing.xxxl;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tray = ref.watch(storiesTrayProvider);
    final groups = tray.value ?? const <StoryGroup>[];

    // The rail collapses when there is nothing live rather than showing an
    // empty strip — a row of nothing reads as a broken component.
    if (groups.isEmpty) return const SliverToBoxAdapter(child: DsGaps.none);

    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.only(bottom: DsSpacing.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            CommunitySectionHeading(
              eyebrow: context.l10n.socialFeedStoriesEyebrow,
              title: context.l10n.socialFeedStoriesTitle,
              live: true,
            ),
            SizedBox(
              height: _height,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: DsSpacing.lg),
                itemCount: groups.length,
                separatorBuilder: (_, _) => DsGaps.hXs,
                itemBuilder: (context, index) {
                  final group = groups[index];
                  final author = group.first.author;
                  return DsStoryCard(
                    label: author.name,
                    imageUrl: author.imageUrl,
                    seen: group.allSeen,
                    isVerified: author.isVerified,
                    size: _ring,
                    width: _bubbleWidth,
                    onTap: () async {
                      await openStoryGroups(context, groups, startGroup: index);
                      // Back from the viewer: the rings she watched close.
                      ref.invalidate(storiesTrayProvider);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
