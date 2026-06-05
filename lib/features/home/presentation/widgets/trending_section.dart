import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/design_system/design_system.dart';
import '../../../../core/localization/l10n_extension.dart';
import '../../../../core/shared/wedgets/app/reem_section_header.dart';
import 'luxury_post_card.dart';
import '../providers/home_provider.dart';

class TrendingSection extends ConsumerWidget {
  const TrendingSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final posts = ref.watch(homeNotifierProvider).posts;

    final top = posts.take(5).toList();

    // Keep UI stable while backend integration is still maturing.
    final demoFallback = top.isNotEmpty
        ? top
        : [
            ...List.generate(
              5,
              (i) => null,
            )
          ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ReemSectionHeader(
          title: l10n.trendingNow,
          subtitle: l10n.trendingSubtitle,
        ),
        const SizedBox(height: DsSpacing.lg),
        SizedBox(
          height: 300,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: demoFallback.length,
            separatorBuilder: (_, __) => const SizedBox(width: DsSpacing.lg),
            itemBuilder: (context, index) {
              final post = demoFallback[index];

              if (post == null) {
                return LuxuryPostCard(
                  image:
                      'https://images.unsplash.com/photo-1524504388940-b1c1722653e1',
                  title: 'Silk Evening Dress',
                  likes: '${(index + 2) * 3}K',
                  comments: '${(index + 1) * 120}',
                );
              }

              final media = post.product.media;
              final imageUrl = media.isNotEmpty ? media.first.url : '';

              return LuxuryPostCard(
                image: imageUrl,
                title: post.product.title,
                likes: '${post.likesCount}K',
                comments: '${post.commentsCount}',
              );
            },
          ),
        ),
      ],
    );
  }
}

