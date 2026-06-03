import 'package:flutter/material.dart';

import '../../../../core/design_system/design_system.dart';
import '../../../../core/shared/wedgets/app/reem_section_header.dart';
import 'social_feed_post.dart';

class PostFeed extends StatelessWidget {
  const PostFeed({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const ReemSectionHeader(
          title: 'For You',
          subtitle: 'Shop what she’s wearing',
        ),
        const SizedBox(height: DsSpacing.lg),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: 3,
          separatorBuilder: (_, __) => const SizedBox(height: DsSpacing.xl),
          itemBuilder: (context, index) {
            return SocialFeedPost(
              authorName: 'Sara Alenna',
              authorAvatar:
                  'https://images.unsplash.com/photo-1494790108377-be9c29b29330',
              imageUrl:
                  'https://images.unsplash.com/photo-1496747611176-843222e1e57c',
              caption:
                  'Obsessed with this blush set 💕 Perfect for date night!',
              likes: '${(index + 1) * 1.2}K',
              comments: '${(index + 1) * 89}',
              productName: 'Glow Blush Palette',
              productPrice: '\$42',
              timeAgo: '${index + 1}h ago',
            );
          },
        ),
      ],
    );
  }
}
