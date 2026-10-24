import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show ProviderListenable;
import 'package:go_router/go_router.dart';

import 'package:reem/core/design_system/design_system.dart';
import 'package:reem/core/localization/l10n_extension.dart';
import 'package:reem/core/platform/app_haptics.dart';
import 'package:reem/core/router/route_paths.dart';
import 'package:reem/core/shared/entities/product.dart';
import 'package:reem/features/discovery/presentation/providers/collection_state.dart';
import 'package:reem/features/discovery/presentation/providers/discovery_providers.dart';
import 'package:reem/features/highlights/presentation/widgets/highlights_rail.dart';
import 'package:reem/features/product_social/presentation/providers/product_social_providers.dart';
import 'package:reem/features/product_social/presentation/widgets/product_shelf.dart';
import 'package:reem/features/social/domain/entities/content.dart';
import 'package:reem/features/social/presentation/open_stories.dart';
import 'package:reem/features/social/presentation/providers/social_providers.dart';
import 'package:reem/features/social/presentation/widgets/interactive_content_card.dart';
import 'package:reem/features/user_profile/domain/entities/user_profile.dart';
import 'package:reem/features/user_profile/presentation/providers/user_profile_providers.dart';
import 'package:reem/features/user_profile/presentation/widgets/my_page_card.dart';
import 'package:reem/features/user_profile/presentation/widgets/profile_page_header.dart';
import 'package:reem/features/user_profile/presentation/widgets/seller_reviews_section.dart';

/// What a page can show.
enum ProfileTab { products, posts, reels, picks, stories, reviews }

/// Somebody's page — a boutique's or a shopper's. Pass [userId] = null to show
/// the signed-in user's own.
///
/// It used to stop under the follow button. A boutique's page had a rail of six
/// products and its reviews; a shopper's page had nothing at all, so a woman
/// who tapped another woman's face in the comments found a name and a count
/// of posts she could not open. The page is now what the client described: a
/// boutique's pieces in the same three shapes as «وصل حديثاً», and for anyone
/// her posts, her reels, her live stories and the pieces she added to her page
/// — behind her own choice to open the page at all.
class UserProfileScreen extends ConsumerStatefulWidget {
  const UserProfileScreen({super.key, this.userId});

  final String? userId;

  @override
  ConsumerState<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends ConsumerState<UserProfileScreen> {
  final _scroll = ScrollController();
  ProfileTab? _tab;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scroll
      ..removeListener(_onScroll)
      ..dispose();
    super.dispose();
  }

  List<ProfileTab> _tabsFor(UserProfile profile) => profile.isSeller
      ? const [
          ProfileTab.products,
          ProfileTab.posts,
          ProfileTab.reels,
          ProfileTab.stories,
          ProfileTab.reviews,
        ]
      : const [
          ProfileTab.posts,
          ProfileTab.reels,
          ProfileTab.picks,
          ProfileTab.stories,
        ];

  ProfileTab _selected(UserProfile profile) {
    final tabs = _tabsFor(profile);
    final tab = _tab;
    return tab != null && tabs.contains(tab) ? tab : tabs.first;
  }

  /// Pages the active tab while there is still a screenful to read.
  void _onScroll() {
    if (!_scroll.hasClients) return;
    final position = _scroll.position;
    if (position.maxScrollExtent - position.pixels > 700) return;

    final profile = ref
        .read(userProfileNotifierProvider(widget.userId))
        .profile;
    if (profile == null || !profile.isReadable) return;
    final id = profile.user.id;
    switch (_selected(profile)) {
      case ProfileTab.products:
        ref.read(sellerProductsProvider(id).notifier).loadMore();
      case ProfileTab.picks:
        ref.read(userPicksProvider(id).notifier).loadMore();
      case ProfileTab.posts:
        ref.read(userTimelineProvider(id).notifier).loadMore();
      case ProfileTab.reels:
        ref.read(userReelsProvider(id).notifier).loadMore();
      case ProfileTab.stories || ProfileTab.reviews:
        break;
    }
  }

  Future<void> _refresh() async {
    final notifier = ref.read(
      userProfileNotifierProvider(widget.userId).notifier,
    );
    await notifier.refresh();
    final profile = ref
        .read(userProfileNotifierProvider(widget.userId))
        .profile;
    if (profile == null) return;
    final id = profile.user.id;
    ref
      ..invalidate(userTimelineProvider(id))
      ..invalidate(userReelsProvider(id))
      ..invalidate(userStoriesProvider(id))
      ..invalidate(userPicksProvider(id));
    if (profile.isSeller) ref.invalidate(sellerProductsProvider(id));
  }

  void _select(ProfileTab tab) {
    AppHaptics.selection();
    setState(() => _tab = tab);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final state = ref.watch(userProfileNotifierProvider(widget.userId));
    final notifier = ref.read(
      userProfileNotifierProvider(widget.userId).notifier,
    );
    final profile = state.profile;

    return ReemScrollPage(
      controller: _scroll,
      onRefresh: _refresh,
      slivers: [
        // Until there is somebody to frame, a plain bar with a way back.
        if (profile == null)
          PremiumAppBar(title: l10n.profileTitle, showBack: true),
        if (state.isLoading && profile == null)
          const SliverFillRemaining(
            hasScrollBody: false,
            child: Center(child: DsLoadingIndicator()),
          )
        else if (profile == null)
          SliverFillRemaining(
            hasScrollBody: false,
            child: DsErrorState(
              message: state.error ?? l10n.profileLoadFailed,
              onRetry: notifier.load,
            ),
          )
        else ...[
          SliverToBoxAdapter(
            child: ProfilePageHeader(
              profile: profile,
              isFollowLoading: state.isFollowLoading,
              onToggleFollow: notifier.toggleFollow,
            ),
          ),
          if (profile.isMe && !profile.isSeller)
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(
                DsSpacing.lg,
                0,
                DsSpacing.lg,
                DsSpacing.lg,
              ),
              sliver: SliverToBoxAdapter(
                child: MyPageCard(
                  showViewPage: false,
                  profileKey: widget.userId,
                ),
              ),
            ),
          if (!profile.isReadable)
            SliverToBoxAdapter(child: _PrivatePage(name: profile.user.name))
          else ...[
            // «الأبرز», above the tabs: a highlight is part of who this page
            // *is*, the way a bio is, rather than one more thing filed under a
            // tab. It draws nothing on a page with none unless it is her own.
            SliverToBoxAdapter(
              child: HighlightsRail(
                ownerId: profile.isMe ? null : profile.user.id,
              ),
            ),
            SliverPersistentHeader(
              pinned: true,
              delegate: _TabsHeader(
                tabs: _tabsFor(profile),
                selected: _selected(profile),
                onSelect: _select,
                labelOf: (tab) => _label(context, tab, profile),
                tone: profile.isSeller
                    ? ProfileTone.boutique
                    : ProfileTone.shopper,
              ),
            ),
            ..._tabSlivers(profile, _selected(profile)),
          ],
        ],
        // Room under the last card for the floating bottom bar.
        const SliverToBoxAdapter(child: SizedBox(height: DsSpacing.huge)),
      ],
    );
  }

  static String _label(BuildContext context, ProfileTab tab, UserProfile p) {
    final l10n = context.l10n;
    return switch (tab) {
      ProfileTab.products => l10n.products,
      ProfileTab.posts => l10n.profilePosts,
      ProfileTab.reels => l10n.profileTabReels,
      ProfileTab.picks =>
        p.isMe ? l10n.profileTabMyPicks : l10n.profileTabPicks,
      ProfileTab.stories => l10n.profileTabStories,
      ProfileTab.reviews => l10n.reviewsAndRatings,
    };
  }

  List<Widget> _tabSlivers(UserProfile profile, ProfileTab tab) {
    final id = profile.user.id;
    return switch (tab) {
      ProfileTab.products => [
        _ProductShelf(
          provider: sellerProductsProvider(id),
          emptyMessage: context.l10n.noProductsFound,
        ),
      ],
      ProfileTab.picks => [
        _ProductShelf(
          provider: userPicksProvider(id),
          emptyMessage: profile.isMe
              ? context.l10n.profileEmptyPicksMine
              : context.l10n.profileEmptyPicks,
        ),
      ],
      ProfileTab.posts => [_PostsTab(userId: id, isMe: profile.isMe)],
      ProfileTab.reels => [_ReelsTab(userId: id)],
      ProfileTab.stories => [_StoriesTab(userId: id)],
      ProfileTab.reviews => [
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: DsSpacing.lg),
          sliver: SliverToBoxAdapter(
            child: SellerReviewsSection(sellerId: id, isMe: profile.isMe),
          ),
        ),
      ],
    };
  }
}

/// A shopper's page she has not opened. Said plainly, so a visitor does not
/// read an empty page as a woman who never posted.
class _PrivatePage extends StatelessWidget {
  const _PrivatePage({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: DsSpacing.xl),
      child: DsEmptyState(
        icon: Icons.lock_outline_rounded,
        title: context.l10n.profilePrivateTitle,
        message: context.l10n.profilePrivateBody(name),
      ),
    );
  }
}

// ── Tabs ────────────────────────────────────────────────────────────────────

class _TabsHeader extends SliverPersistentHeaderDelegate {
  _TabsHeader({
    required this.tabs,
    required this.selected,
    required this.onSelect,
    required this.labelOf,
    required this.tone,
  });

  final List<ProfileTab> tabs;
  final ProfileTab selected;
  final ValueChanged<ProfileTab> onSelect;
  final String Function(ProfileTab tab) labelOf;
  final ProfileTone tone;

  static const double _height = 68;

  @override
  double get minExtent => _height;

  @override
  double get maxExtent => _height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlaps) {
    final c = context.dsColors;
    return ColoredBox(
      color: c.background.withValues(alpha: overlaps ? 0.94 : 0),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: DsSpacing.lg,
          vertical: DsSpacing.xxs,
        ),
        child: ProfileTabBar(
          tone: tone,
          items: [
            for (final tab in tabs)
              ProfileTabItem(icon: _iconOf(tab), label: labelOf(tab)),
          ],
          selected: tabs.indexOf(selected),
          onSelect: (index) => onSelect(tabs[index]),
        ),
      ),
    );
  }

  static IconData _iconOf(ProfileTab tab) => switch (tab) {
    ProfileTab.products => Icons.shopping_bag_rounded,
    ProfileTab.posts => Icons.grid_view_rounded,
    ProfileTab.reels => Icons.play_circle_rounded,
    ProfileTab.picks => Icons.bookmark_added_rounded,
    ProfileTab.stories => Icons.auto_stories_rounded,
    ProfileTab.reviews => Icons.star_rounded,
  };

  @override
  bool shouldRebuild(_TabsHeader old) =>
      old.selected != selected || old.tabs != tabs || old.tone != tone;
}

/// A boutique's products or a shopper's picks, in whichever of the three
/// shapes she prefers — the same switcher, the same cards and the same
/// gestures as «وصل حديثاً».
class _ProductShelf extends ConsumerWidget {
  const _ProductShelf({required this.provider, required this.emptyMessage});

  final ProviderListenable<CollectionState> provider;
  final String emptyMessage;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(provider);
    final products = state.items;
    final loading = state.isLoading;

    if (!loading && products.isEmpty) {
      return SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: DsSpacing.xl),
          child: DsEmptyState(
            icon: Icons.shopping_bag_outlined,
            title: emptyMessage,
          ),
        ),
      );
    }

    void open(Product product) =>
        unawaited(context.push(RoutePaths.productDetailsOf(product.id)));

    return SliverMainAxisGroup(
      slivers: [
        // The same shelf a department draws. Her shop's pieces are the
        // catalogue's pieces, and a heart filled here is filled there.
        SliverProductShelf(
          products: products,
          isLoading: loading,
          onTapProduct: open,
        ),
        if (state.isLoadingMore)
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.all(DsSpacing.lg),
              child: DsLoadingIndicator(),
            ),
          ),
      ],
    );
  }
}

/// What she published, and what she added from other pages, newest first.
/// Reels and stories have their own tabs.
class _PostsTab extends ConsumerWidget {
  const _PostsTab({required this.userId, required this.isMe});

  final String userId;
  final bool isMe;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(userTimelineProvider(userId));
    final entries = [
      for (final entry in state.items)
        if (entry.content.format != ContentFormat.reel &&
            entry.content.format != ContentFormat.story)
          entry,
    ];

    if (state.isLoading && entries.isEmpty) {
      return const _Skeletons();
    }
    if (entries.isEmpty) {
      return _Empty(
        icon: Icons.photo_library_outlined,
        title: context.l10n.profileEmptyPosts,
        message: isMe ? context.l10n.profileEmptyPostsMine : null,
      );
    }

    return SliverList.separated(
      itemCount: entries.length + 1,
      separatorBuilder: (_, _) => DsGaps.vLg,
      itemBuilder: (context, index) {
        if (index == entries.length) {
          return state.isLoadingMore
              ? const Padding(
                  padding: EdgeInsets.all(DsSpacing.lg),
                  child: DsLoadingIndicator(),
                )
              : const SizedBox.shrink();
        }
        final entry = entries[index];
        return switch (entry) {
          ResharedContentEntry(:final reshare) => InteractiveContentCard(
            key: ValueKey(entry.entryId),
            content: reshare.content,
          ),
          _ => InteractiveContentCard(
            key: ValueKey(entry.entryId),
            content: entry.content,
            featured: index == 0,
          ),
        };
      },
    );
  }
}

class _ReelsTab extends ConsumerWidget {
  const _ReelsTab({required this.userId});

  final String userId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(userReelsProvider(userId));
    if (state.isLoading && state.items.isEmpty) return const _Skeletons();
    if (state.items.isEmpty) {
      return _Empty(
        icon: Icons.movie_creation_outlined,
        title: context.l10n.profileEmptyReels,
      );
    }
    return SliverList.separated(
      itemCount: state.items.length,
      separatorBuilder: (_, _) => DsGaps.vLg,
      itemBuilder: (context, index) => InteractiveContentCard(
        key: ValueKey(state.items[index].id),
        content: state.items[index],
      ),
    );
  }
}

/// Her live stories as tiles; a tap plays them from that one on.
class _StoriesTab extends ConsumerWidget {
  const _StoriesTab({required this.userId});

  final String userId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stories = ref.watch(userStoriesProvider(userId));
    return stories.when(
      loading: () => const SliverToBoxAdapter(
        child: Padding(
          padding: EdgeInsets.all(DsSpacing.xl),
          child: DsLoadingIndicator(),
        ),
      ),
      error: (error, _) => SliverToBoxAdapter(
        child: DsErrorState(
          onRetry: () => ref.invalidate(userStoriesProvider(userId)),
        ),
      ),
      data: (groups) {
        final all = [for (final group in groups) ...group.stories];
        if (all.isEmpty) {
          return _Empty(
            icon: Icons.amp_stories_outlined,
            title: context.l10n.profileEmptyStories,
          );
        }
        return SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: DsSpacing.lg),
          sliver: SliverGrid.builder(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              mainAxisSpacing: DsSpacing.sm,
              crossAxisSpacing: DsSpacing.sm,
              childAspectRatio: 9 / 16,
            ),
            itemCount: all.length,
            itemBuilder: (context, index) {
              final story = all[index];
              final cover = story.cover;
              return Semantics(
                button: true,
                label: context.l10n.profileTabStories,
                child: GestureDetector(
                  onTap: () => context.push(
                    RoutePaths.storyViewer,
                    extra: storyViewerArgsFor(all, initialIndex: index),
                  ),
                  child: ClipRRect(
                    borderRadius: DsRadius.borderLg,
                    child: cover == null
                        ? const DsMediaFallback()
                        : DsMediaFrame(item: cover),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}

class _Skeletons extends StatelessWidget {
  const _Skeletons();

  @override
  Widget build(BuildContext context) {
    return SliverList.separated(
      itemCount: 2,
      separatorBuilder: (_, _) => DsGaps.vLg,
      itemBuilder: (_, _) => const Padding(
        padding: EdgeInsets.symmetric(horizontal: DsSpacing.gutter),
        child: DsPostCardSkeleton(),
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.icon, required this.title, this.message});

  final IconData icon;
  final String title;
  final String? message;

  @override
  Widget build(BuildContext context) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: DsSpacing.xl),
        child: DsEmptyState(icon: icon, title: title, message: message),
      ),
    );
  }
}
