import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:reem/core/router/route_names.dart';
import 'package:reem/features/home/data/datasources/dummy_data.dart';


import '../../../../core/design_system/design_system.dart';
import 'story_avatar.dart';
import '../screens/story_viewer_screen.dart';

class StoriesSection extends ConsumerWidget {
  const StoriesSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // final stories = ref.watch(homeNotifierProvider).stories;


    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const ReemSectionHeader(
          title: 'Stories',
          subtitle: 'New drops & style inspiration',
        ),
        const SizedBox(height: DsSpacing.md),
        SizedBox(
          height: 108,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: stories.length + 1,
            separatorBuilder: (_, _) => const SizedBox(width: DsSpacing.md),
            itemBuilder: (context, index) {
              if (index == 0) {
                return GestureDetector(
                  onTap: () => context.pushNamed(RouteNames.addStory),
                  child: const StoryAvatar(
                    image: '',
                    username: 'Your Story',
                    isAddStory: true,
                  ),
                );
              }

              final story = stories[index - 1];
              return GestureDetector(
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => StoryViewerScreen(
                      stories: stories,
                      initialIndex: index - 1,
                    ),
                  ),
                ),
                child: StoryAvatar(
                  image: story.media.url,
                  username: story.user.username,
                  isViewed: story.isViewed,
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

