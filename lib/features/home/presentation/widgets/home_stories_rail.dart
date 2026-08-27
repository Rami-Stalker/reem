import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:reem/core/design_system/design_system.dart';
import 'package:reem/core/localization/l10n_extension.dart';
import 'package:reem/core/shared/entities/story.dart';
import 'package:reem/features/home/presentation/providers/home_provider.dart';
import 'package:reem/features/home/presentation/screens/story_viewer_screen.dart';
import 'package:reem/features/home/presentation/widgets/home_section_header.dart';

/// The boutiques' stories — today's frames from the shops she follows.
///
/// This is a shop-window rail, not a friends rail: it carries boutiques, so it
/// shows the shop's name (with its verified tick) rather than a handle, and it
/// no longer opens with a "your story" composer — a buyer posting into a row of
/// storefronts made no sense. It collapses entirely when no shop has posted,
/// instead of leaving a lone empty bubble on the page.
class HomeStoriesRail extends ConsumerWidget {
  const HomeStoriesRail({super.key});

  static const double _height = 108;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(homeNotifierProvider);
    final stories = state.stories;
    final loading = state.storiesLoading && stories.isEmpty;

    if (!loading && stories.isEmpty) {
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }

    return SliverMainAxisGroup(
      slivers: [
        SliverToBoxAdapter(
          child: HomeSectionHeader(
            eyebrow: context.l10n.homeStoriesEyebrow,
            title: context.l10n.homeBoutiqueStories,
            padding: const EdgeInsets.fromLTRB(
              DsSpacing.lg,
              0,
              DsSpacing.lg,
              DsSpacing.sm,
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: SizedBox(
            height: _height,
            child: loading
                ? _skeleton()
                : ListView.separated(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(
                      horizontal: DsSpacing.lg,
                    ),
                    itemCount: stories.length,
                    separatorBuilder: (_, _) =>
                        const SizedBox(width: DsSpacing.sm),
                    itemBuilder: (context, index) {
                      final story = stories[index];
                      return DsStoryCard(
                        label: _boutiqueName(story),
                        imageUrl: story.user.imageUrl,
                        seen: story.isViewed,
                        isVerified: story.user.isVerified,
                        size: 68,
                        width: 80,
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => StoryViewerScreen(
                              stories: stories,
                              initialIndex: index,
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

  /// The shop's display name, falling back to the handle for the rare account
  /// that has not set one.
  static String _boutiqueName(Story story) {
    final name = story.user.name.trim();
    return name.isEmpty ? story.user.username : name;
  }

  Widget _skeleton() {
    return DsShimmer(
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: DsSpacing.lg),
        itemCount: 6,
        separatorBuilder: (_, _) => const SizedBox(width: DsSpacing.sm),
        itemBuilder: (_, _) => const DsStoryCardSkeleton(),
      ),
    );
  }
}
