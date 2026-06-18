import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/design_system/design_system.dart';
import '../providers/home_provider.dart';
import 'feed_post_card.dart';
import 'home_section_header.dart';

/// The social feed — products presented as posts. Returns a sliver group so it
/// composes directly into the home [CustomScrollView].
class FeedSection extends ConsumerWidget {
  const FeedSection({super.key});

  static const _hPad = EdgeInsets.symmetric(horizontal: DsSpacing.lg);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(homeNotifierProvider);
    final posts = state.feed;
    final loading = state.feedLoading;

    return SliverMainAxisGroup(
      slivers: [
        const SliverToBoxAdapter(
          child: HomeSectionHeader(
            eyebrow: 'Curated for you',
            title: 'The Feed',
            subtitle: 'Shop the looks she’s loving right now',
          ),
        ),
        if (loading && posts.isEmpty)
          SliverList.separated(
            itemCount: 2,
            separatorBuilder: (_, _) => const SizedBox(height: DsSpacing.xl),
            itemBuilder: (_, _) => const Padding(
              padding: _hPad,
              child: DsPostCardSkeleton(mediaAspectRatio: 4 / 5),
            ),
          )
        else if (posts.isEmpty)
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: DsSpacing.xxl),
              child: DsEmptyState(
                icon: Icons.auto_awesome_rounded,
                title: 'Your feed is warming up',
                message:
                    'Follow boutiques you love to fill your feed with beautiful finds.',
              ),
            ),
          )
        else
          SliverList.separated(
            itemCount: posts.length,
            separatorBuilder: (_, _) => const SizedBox(height: DsSpacing.xl),
            itemBuilder: (context, index) => Padding(
              padding: _hPad,
              child: FeedPostCard(post: posts[index]),
            ),
          ),
      ],
    );
  }
}
