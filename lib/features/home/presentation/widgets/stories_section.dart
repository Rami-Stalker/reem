import 'package:flutter/material.dart';

import '../../../../core/design_system/design_system.dart';
import '../../../../core/shared/wedgets/app/reem_section_header.dart';
import 'story_avatar.dart';

class StoriesSection extends StatelessWidget {
  const StoriesSection({super.key});

  static const _storyImages = [
    'https://images.unsplash.com/photo-1487412720507-e7ab37603c6f',
    'https://images.unsplash.com/photo-1529139574466-a303027c1d8b',
    'https://images.unsplash.com/photo-1496747611176-843222e1e57c',
    'https://images.unsplash.com/photo-1515886657613-9f3515b0c78f',
    'https://images.unsplash.com/photo-1534528741775-53994a69daeb',
  ];

  @override
  Widget build(BuildContext context) {
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
            itemCount: _storyImages.length + 1,
            separatorBuilder: (_, __) => const SizedBox(width: DsSpacing.md),
            itemBuilder: (context, index) {
              if (index == 0) {
                return const StoryAvatar(
                  image: '',
                  username: 'Your Story',
                  isAddStory: true,
                );
              }
              return StoryAvatar(
                image: _storyImages[index - 1],
                username: index == 1 ? 'New ✨' : 'Style',
                isViewed: index > 3,
              );
            },
          ),
        ),
      ],
    );
  }
}
