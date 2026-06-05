import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:reem/features/home/data/datasources/dummy_data.dart';

import '../../../../core/design_system/design_system.dart';
import '../../../../core/shared/wedgets/app/reem_section_header.dart';
import '../providers/home_provider.dart';
import 'social_feed_post.dart';

class PostFeed extends ConsumerWidget {
  const PostFeed({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // final posts = ref.watch(homeNotifierProvider).posts;

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
          itemCount: posts.length,
          separatorBuilder: (_, _) => const SizedBox(height: DsSpacing.xl),
          itemBuilder: (context, index) {
            final post = posts[index];
            final productMedia = post.product.media;
            final imageUrl = productMedia.isNotEmpty ? productMedia.first.url : '';

            return SocialFeedPost(
              authorName: post.author.name,
              authorAvatar: post.author.imageUrl ?? '',
              imageUrl: imageUrl,
              caption: post.caption,
              likes: '${post.likesCount}K',
              comments: '${post.commentsCount}',
              productName: post.product.title,
              productPrice: '\$${post.product.price.toStringAsFixed(0)}',
              timeAgo: post.createdAt.isAfter(DateTime.now().subtract(const Duration(hours: 2)))
                  ? 'Just now'
                  : '',
              postId: post.id,
            );
          },
        ),
      ],
    );
  }
}

