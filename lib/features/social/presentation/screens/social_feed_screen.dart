import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:reem/core/design_system/design_system.dart';
import 'package:reem/core/localization/l10n_extension.dart';
import 'package:reem/core/router/route_paths.dart';
import 'package:reem/core/shared/services/share_service.dart';
import 'package:reem/features/auth/presentation/providers/auth_provider.dart';
import 'package:reem/features/social/domain/entities/content.dart';
import 'package:reem/features/social/presentation/providers/social_providers.dart';
import 'package:reem/features/social/presentation/widgets/content_card.dart';
import 'package:reem/features/social/presentation/widgets/content_comments_sheet.dart';
import 'package:reem/features/social/presentation/widgets/reshare_sheet.dart';

/// The social feed: what everyone is posting, and what the women she follows
/// are posting.
///
/// Two tabs rather than one blended feed. The client asked for a mixed feed
/// (followed + suggested) and that is what «اكتشفي» is; «أتابع» is the other
/// half, and separating them means a woman who follows six boutiques can
/// actually find their posts rather than hunting for them among two hundred
/// suggestions.
class SocialFeedScreen extends ConsumerStatefulWidget {
  const SocialFeedScreen({super.key});

  @override
  ConsumerState<SocialFeedScreen> createState() => _SocialFeedScreenState();
}

class _SocialFeedScreenState extends ConsumerState<SocialFeedScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 2, vsync: this);

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: NestedScrollView(
        headerSliverBuilder: (_, _) => [
          PremiumAppBar(
            title: context.l10n.socialFeedTitle,
            actions: [
              DsIconButton(
                icon: Icons.add_box_outlined,
                tooltip: context.l10n.composerTitle,
                onPressed: () => context.push(RoutePaths.compose),
              ),
            ],
            bottom: TabBar(
              controller: _tabs,
              tabs: [
                Tab(text: context.l10n.socialFeedDiscover),
                Tab(text: context.l10n.socialFeedFollowing),
              ],
            ),
          ),
        ],
        body: TabBarView(
          controller: _tabs,
          children: const [
            _FeedList(kind: SocialFeedKind.discover, showStories: true),
            _FeedList(kind: SocialFeedKind.following),
          ],
        ),
      ),
    );
  }
}

/// One feed, paged, with the stories tray on top of the discover tab.
class _FeedList extends ConsumerStatefulWidget {
  const _FeedList({required this.kind, this.showStories = false});

  final SocialFeedKind kind;
  final bool showStories;

  @override
  ConsumerState<_FeedList> createState() => _FeedListState();
}

class _FeedListState extends ConsumerState<_FeedList> {
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scroll.removeListener(_onScroll);
    _scroll.dispose();
    super.dispose();
  }

  /// Fetch the next page while there is still a screenful to read, so the
  /// spinner is rarely the thing she is looking at.
  void _onScroll() {
    if (!_scroll.hasClients) return;
    final remaining = _scroll.position.maxScrollExtent - _scroll.position.pixels;
    if (remaining < 900) {
      ref.read(contentFeedProvider(widget.kind).notifier).loadMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(contentFeedProvider(widget.kind));
    final notifier = ref.read(contentFeedProvider(widget.kind).notifier);
    final me = ref.watch(authNotifierProvider.select((s) => s.user?.id));

    if (state.isLoading && state.items.isEmpty) {
      return ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: DsSpacing.md),
        itemCount: 3,
        itemBuilder: (_, _) => const Padding(
          padding: EdgeInsets.symmetric(
            horizontal: DsSpacing.gutter,
            vertical: DsSpacing.sm,
          ),
          child: DsPostCardSkeleton(),
        ),
      );
    }

    if (state.hasError && state.items.isEmpty) {
      return DsErrorState(message: state.error, onRetry: notifier.load);
    }

    if (state.items.isEmpty) {
      return DsEmptyState(
        icon: Icons.auto_awesome_rounded,
        title: widget.kind == SocialFeedKind.following
            ? context.l10n.socialFeedFollowingEmptyTitle
            : context.l10n.socialFeedEmptyTitle,
        message: widget.kind == SocialFeedKind.following
            ? context.l10n.socialFeedFollowingEmptyBody
            : context.l10n.socialFeedEmptyBody,
      );
    }

    return RefreshIndicator(
      onRefresh: notifier.refresh,
      child: ListView.separated(
        controller: _scroll,
        padding: const EdgeInsets.only(
          top: DsSpacing.md,
          bottom: DsSpacing.huge,
        ),
        itemCount: state.items.length + (widget.showStories ? 1 : 0) + 1,
        separatorBuilder: (_, _) => DsGaps.vLg,
        itemBuilder: (context, index) {
          if (widget.showStories && index == 0) return const _StoriesTray();
          final offset = widget.showStories ? 1 : 0;

          if (index - offset >= state.items.length) {
            return state.isLoadingMore
                ? const Padding(
                    padding: EdgeInsets.all(DsSpacing.lg),
                    child: DsLoadingIndicator(),
                  )
                : DsGaps.vXl;
          }

          final content = state.items[index - offset];
          return ContentCard(
            content: content,
            featured: index - offset == 0,
            onOpenAuthor: (userId) =>
                context.push(RoutePaths.userProfileOf(userId)),
            onOpenProduct: (productId) =>
                context.push(RoutePaths.productDetailsOf(productId)),
            onLike: () => notifier.toggleLike(content.id),
            onSave: () => notifier.toggleSave(content.id),
            onComment: () async {
              final delta = await showContentComments(
                context,
                contentId: content.id,
              );
              notifier.adjustComments(content.id, delta);
            },
            onShare: () async {
              final shared = await ShareService.post(
                context: context,
                postId: content.id,
                caption: content.caption,
                authorName: content.author.name,
              );
              // A share sheet she dismissed is not a share.
              if (shared) await notifier.recordShare(content.id);
            },
            // She cannot add her own post to her own page.
            onReshare: content.author.id == me
                ? null
                : () => _reshare(context, notifier, content),
          );
        },
      ),
    );
  }

  Future<void> _reshare(
    BuildContext context,
    dynamic notifier,
    Content content,
  ) async {
    if (content.viewer.isReshared) {
      await notifier.toggleReshare(content.id);
      return;
    }
    final note = await showReshareSheet(context, content: content);
    if (note == null) return;
    await notifier.toggleReshare(content.id, note: note.isEmpty ? null : note);
  }
}

/// Live stories, along the top of the discover tab.
class _StoriesTray extends ConsumerWidget {
  const _StoriesTray();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tray = ref.watch(storiesTrayProvider);

    return tray.when(
      // The rail collapses when there is nothing live rather than showing an
      // empty strip — a row of nothing reads as a broken component.
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
      data: (groups) {
        if (groups.isEmpty) return const SizedBox.shrink();
        return SizedBox(
          height: DsSizes.storyRing + DsSpacing.xl,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: DsSpacing.gutter),
            itemCount: groups.length,
            separatorBuilder: (_, _) => DsGaps.hSm,
            itemBuilder: (context, index) {
              final group = groups[index];
              return StoryBubble(
                author: group.first.author,
                allSeen: group.allSeen,
                onTap: () => context.push(
                  RoutePaths.storyViewer,
                  extra: groups.skip(index).toList(),
                ),
              );
            },
          ),
        );
      },
    );
  }
}
