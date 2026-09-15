import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show ProviderListenable;
import 'package:go_router/go_router.dart';

import 'package:reem/core/design_system/design_system.dart';
import 'package:reem/core/localization/l10n_extension.dart';
import 'package:reem/core/platform/app_haptics.dart';
import 'package:reem/core/presentation/providers/product_shape_provider.dart';
import 'package:reem/core/router/route_paths.dart';
import 'package:reem/core/shared/entities/product.dart';
import 'package:reem/core/shared/entities/user.dart';
import 'package:reem/core/shared/services/share_service.dart';
import 'package:reem/features/chat/domain/entities/chat_start_request.dart';
import 'package:reem/features/chat/presentation/widgets/message_seller_button.dart';
import 'package:reem/features/discovery/presentation/providers/collection_state.dart';
import 'package:reem/features/discovery/presentation/providers/discovery_providers.dart';
import 'package:reem/features/product_social/presentation/providers/product_social_providers.dart';
import 'package:reem/features/product_social/presentation/widgets/product_post_card.dart';
import 'package:reem/features/profile/presentation/providers/profile_provider.dart';
import 'package:reem/features/social/domain/entities/content.dart';
import 'package:reem/features/social/presentation/open_stories.dart';
import 'package:reem/features/social/presentation/providers/social_providers.dart';
import 'package:reem/features/social/presentation/widgets/interactive_content_card.dart';
import 'package:reem/features/user_profile/domain/entities/user_profile.dart';
import 'package:reem/features/user_profile/presentation/providers/user_profile_providers.dart';
import 'package:reem/features/user_profile/presentation/widgets/follow_button.dart';
import 'package:reem/features/user_profile/presentation/widgets/my_page_card.dart';
import 'package:reem/features/user_profile/presentation/widgets/profile_stat_tile.dart';
import 'package:reem/features/user_profile/presentation/widgets/seller_reviews_section.dart';
import 'package:reem/features/user_profile/presentation/widgets/seller_stats_card.dart';

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

    final profile = ref.read(userProfileNotifierProvider(widget.userId)).profile;
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
    final profile = ref.read(userProfileNotifierProvider(widget.userId)).profile;
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
        PremiumAppBar(
          title: profile != null
              ? '@${profile.user.username}'
              : l10n.profileTitle,
          showBack: true,
          actions: [
            if (profile != null)
              DsIconButton(
                icon: Icons.ios_share_rounded,
                tooltip: l10n.contentShare,
                variant: DsIconButtonVariant.ghost,
                onPressed: () => ShareService.profile(
                  context: context,
                  userId: profile.user.id,
                  name: profile.user.name,
                ),
              ),
          ],
        ),
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
            child: _ProfileHeader(
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
            SliverPersistentHeader(
              pinned: true,
              delegate: _TabsHeader(
                tabs: _tabsFor(profile),
                selected: _selected(profile),
                onSelect: _select,
                labelOf: (tab) => _label(context, tab, profile),
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
      ProfileTab.picks => p.isMe ? l10n.profileTabMyPicks : l10n.profileTabPicks,
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

// ── Header ──────────────────────────────────────────────────────────────────

class _ProfileHeader extends ConsumerWidget {
  const _ProfileHeader({
    required this.profile,
    required this.isFollowLoading,
    required this.onToggleFollow,
  });

  final UserProfile profile;
  final bool isFollowLoading;
  final VoidCallback onToggleFollow;

  Future<void> _openStories(BuildContext context, WidgetRef ref) async {
    final groups = await ref.read(userStoriesProvider(profile.user.id).future);
    if (!context.mounted || groups.isEmpty) return;
    openStoryGroups(context, groups);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.dsColors;
    final user = profile.user;
    // The ring means "there is a story to watch", and only while there is.
    final hasStory = profile.hasStory && profile.isReadable;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        DsSpacing.lg,
        DsSpacing.md,
        DsSpacing.lg,
        DsSpacing.lg,
      ),
      child: Column(
        children: [
          DsAvatar(
            imageUrl: user.imageUrl,
            name: user.name,
            size: 104,
            hasRing: hasStory,
            onTap: hasStory ? () => _openStories(context, ref) : null,
          ),
          const SizedBox(height: DsSpacing.md),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(
                child: Text(
                  user.name,
                  textAlign: TextAlign.center,
                  style: context.dsText.screenTitle.bold.tint(colors.onSurface),
                ),
              ),
              if (user.isVerified) ...[
                const SizedBox(width: DsSpacing.xs),
                Icon(Icons.verified_rounded, color: colors.primary, size: 20),
              ],
            ],
          ),
          const SizedBox(height: DsSpacing.xs),
          _RoleBadge(role: user.role),
          if (user.bio != null && user.bio!.isNotEmpty) ...[
            const SizedBox(height: DsSpacing.md),
            Text(
              user.bio!,
              textAlign: TextAlign.center,
              style: context.dsText.body
                  .tint(colors.onSurfaceVariant)
                  .copyWith(height: 1.4),
            ),
          ],
          if (user.location != null && user.location!.isNotEmpty) ...[
            const SizedBox(height: DsSpacing.sm),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.place_outlined,
                  size: 16,
                  color: colors.onSurfaceVariant,
                ),
                DsGaps.hXxs,
                Text(
                  user.location!,
                  style: context.dsText.bodySmall.tint(colors.onSurfaceVariant),
                ),
              ],
            ),
          ],
          const SizedBox(height: DsSpacing.lg),
          _StatsRow(profile: profile),
          const SizedBox(height: DsSpacing.lg),
          if (profile.isMe) ...[
            SecondaryButton(
              label: context.l10n.profileEdit,
              onPressed: () => context.push(RoutePaths.editProfile),
            ),
            if (user.isSeller) ...[
              const SizedBox(height: DsSpacing.sm),
              PrimaryButton(
                label: context.l10n.profileManageStore,
                icon: Icons.storefront_outlined,
                onPressed: () => context.push(RoutePaths.myProducts),
              ),
            ],
          ] else ...[
            // A closed page cannot be followed — the server refuses it — so
            // the button is not offered rather than offered and refused.
            if (profile.isReadable)
              FollowButton(
                isFollowing: profile.isFollowing,
                isLoading: isFollowLoading,
                onPressed: onToggleFollow,
              ),
            // Only a boutique can be written to: the server refuses any
            // pairing that is not buyer↔seller.
            if (profile.isSeller) ...[
              const SizedBox(height: DsSpacing.sm),
              MessageSellerButton(
                label: context.l10n.messageSeller,
                request: ChatStartRequest.peer(peerId: user.id),
              ),
            ],
          ],
          if (profile.isSeller && profile.sellerStats != null) ...[
            const SizedBox(height: DsSpacing.xl),
            SellerStatsCard(stats: profile.sellerStats!),
          ],
        ],
      ),
    );
  }
}

class _StatsRow extends StatelessWidget {
  const _StatsRow({required this.profile});

  final UserProfile profile;

  @override
  Widget build(BuildContext context) {
    final colors = context.dsColors;
    Widget divider() => Container(width: 1, height: 28, color: colors.border);

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        ProfileStatTile(
          value: _compact(profile.postsCount),
          label: context.l10n.profilePosts,
        ),
        divider(),
        ProfileStatTile(
          value: _compact(profile.user.followersCount),
          label: context.l10n.profileFollowers,
          onTap: () => context.push(RoutePaths.followersOf(profile.user.id)),
        ),
        divider(),
        ProfileStatTile(
          value: _compact(profile.user.followingCount),
          label: context.l10n.profileFollowing,
          onTap: () => context.push(RoutePaths.followingOf(profile.user.id)),
        ),
      ],
    );
  }

  String _compact(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}k';
    return '$n';
  }
}

class _RoleBadge extends StatelessWidget {
  const _RoleBadge({required this.role});

  final UserRole role;

  @override
  Widget build(BuildContext context) {
    final colors = context.dsColors;
    final isSeller = role == UserRole.seller;
    final isAdmin = role == UserRole.admin;
    final color = isAdmin
        ? colors.error
        : isSeller
        ? colors.primary
        : colors.onSurfaceVariant;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: DsSpacing.sm,
        vertical: DsSpacing.xxs,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(DsRadius.full),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isAdmin
                ? Icons.shield_outlined
                : isSeller
                ? Icons.storefront_outlined
                : Icons.person_outline,
            size: 13,
            color: color,
          ),
          DsGaps.hXxs,
          Text(
            // `role.label` is the English wire identifier; the badge used to
            // print "Customer" on an Arabic page.
            isAdmin
                ? context.l10n.adminRoleAdmin
                : isSeller
                ? context.l10n.roleSeller
                : context.l10n.roleBuyer,
            style: context.dsText.bodySmall.semibold.tint(color),
          ),
        ],
      ),
    );
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
  });

  final List<ProfileTab> tabs;
  final ProfileTab selected;
  final ValueChanged<ProfileTab> onSelect;
  final String Function(ProfileTab tab) labelOf;

  static const double _height = 60;

  @override
  double get minExtent => _height;

  @override
  double get maxExtent => _height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlaps) {
    final c = context.dsColors;
    return ColoredBox(
      color: c.background.withValues(alpha: overlaps ? 0.96 : 0),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(
          horizontal: DsSpacing.lg,
          vertical: DsSpacing.sm,
        ),
        itemCount: tabs.length,
        separatorBuilder: (_, _) => DsGaps.hXs,
        itemBuilder: (context, index) {
          final tab = tabs[index];
          return DsChip(
            label: labelOf(tab),
            icon: _iconOf(tab),
            selected: tab == selected,
            onTap: () => onSelect(tab),
          );
        },
      ),
    );
  }

  static IconData _iconOf(ProfileTab tab) => switch (tab) {
    ProfileTab.products => Icons.shopping_bag_outlined,
    ProfileTab.posts => Icons.grid_on_rounded,
    ProfileTab.reels => Icons.movie_creation_outlined,
    ProfileTab.picks => Icons.add_to_photos_outlined,
    ProfileTab.stories => Icons.amp_stories_outlined,
    ProfileTab.reviews => Icons.star_outline_rounded,
  };

  @override
  bool shouldRebuild(_TabsHeader old) =>
      old.selected != selected || old.tabs != tabs;
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
    final shape = ref.watch(productShapeProvider);

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
          DsProductShape.posts => SliverProductPostCards(
            products: products,
            isLoading: loading,
          ),
          DsProductShape.mosaic => SliverProductMosaic(
            products: products,
            isLoading: loading,
            onTapProduct: open,
          ),
          DsProductShape.grid => SliverProductGrid(
            products: products,
            isLoading: loading,
            onTapProduct: open,
            onToggleFavorite: (p) => ref
                .read(favoritesNotifierProvider.notifier)
                .toggleFavorite(p.id),
          ),
        },
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
            resharedBy: reshare.resharer,
            reshareNote: reshare.note,
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
