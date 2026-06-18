import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/design_system/design_system.dart';
import '../../../../core/router/route_names.dart';
import '../providers/home_provider.dart';
import '../screens/story_viewer_screen.dart';
import 'home_section_header.dart';

/// Horizontal stories rail — "add story" entry plus friends'/boutiques' stories.
class HomeStoriesRail extends ConsumerWidget {
  const HomeStoriesRail({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(homeNotifierProvider);
    final stories = state.stories;
    final loading = state.storiesLoading;

    return SliverMainAxisGroup(
      slivers: [
        const SliverToBoxAdapter(
          child: HomeSectionHeader(
            eyebrow: 'Fresh today',
            title: 'Stories',
            padding: EdgeInsets.fromLTRB(
                DsSpacing.lg, 0, DsSpacing.lg, DsSpacing.sm),
          ),
        ),
        SliverToBoxAdapter(
          child: SizedBox(
            height: 104,
            child: loading && stories.isEmpty
                ? ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(
                        horizontal: DsSpacing.lg),
                    itemCount: 6,
                    separatorBuilder: (_, _) =>
                        const SizedBox(width: DsSpacing.sm),
                    itemBuilder: (_, _) => const DsStoryCardSkeleton(),
                  )
                : ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(
                        horizontal: DsSpacing.lg),
                    physics: const BouncingScrollPhysics(),
                    itemCount: stories.length + 1,
                    separatorBuilder: (_, _) =>
                        const SizedBox(width: DsSpacing.sm),
                    itemBuilder: (context, index) {
                      if (index == 0) {
                        return DsStoryAddCard(
                          label: 'Your story',
                          onTap: () => context.pushNamed(RouteNames.addStory),
                        );
                      }
                      final story = stories[index - 1];
                      return DsStoryCard(
                        label: story.user.username,
                        imageUrl: story.coverUrl,
                        seen: story.isViewed,
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => StoryViewerScreen(
                              stories: stories,
                              initialIndex: index - 1,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ),
      ],
    );
  }
}
