import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:reem/core/design_system/design_system.dart';
import 'package:reem/core/localization/l10n_extension.dart';
import 'package:reem/core/shared/entities/story.dart';
import 'package:reem/features/home/presentation/providers/home_provider.dart';
import 'package:reem/features/home/presentation/widgets/home_section_header.dart';
import 'package:reem/features/stories/presentation/screens/story_viewer_screen.dart';

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

  /// Carried by the rail rather than left as a sliver behind it, so a day when
  /// no boutique has posted costs the page nothing at all.
  static const double _trailingGap = DsSpacing.lg;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(homeNotifierProvider);
    final stories = state.stories;
    final loading = state.storiesLoading && stories.isEmpty;
    // One ring per boutique. The feed lists every story on its own, and a
    // shop with three frames up used to take three places in the row.
    final shops = HomeStoriesRail.groupStoriesByShop(stories);
    final playlist = [for (final shop in shops) ...shop];

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
              DsSpacing.xxxs,
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
                    padding: const EdgeInsets.symmetric(
                      horizontal: DsSpacing.lg,
                    ),
                    itemCount: shops.length,
                    separatorBuilder: (_, _) =>
                        const SizedBox(width: DsSpacing.sm),
                    itemBuilder: (context, index) {
                      final shop = shops[index];
                      final story = shop.first;
                      // Where this shop's frames start in the playlist, so
                      // the viewer plays shop by shop.
                      final start = shops
                          .take(index)
                          .fold<int>(0, (sum, s) => sum + s.length);
                      return DsStoryCard(
                        label: _boutiqueName(story),
                        imageUrl: story.user.imageUrl,
                        seen: shop.every((frame) => frame.isViewed),
                        isVerified: story.user.isVerified,
                        size: 68,
                        width: 80,
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => StoryViewerScreen(
                              stories: playlist,
                              initialIndex: start,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: _trailingGap)),
      ],
    );
  }

  /// Stories grouped by the shop that posted them, in the order each shop
  /// first appears in the feed; each shop's frames keep their feed order.
  @visibleForTesting
  static List<List<Story>> groupStoriesByShop(List<Story> stories) {
    final shops = <String, List<Story>>{};
    for (final story in stories) {
      shops.putIfAbsent(story.user.id, () => []).add(story);
    }
    return shops.values.toList(growable: false);
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
