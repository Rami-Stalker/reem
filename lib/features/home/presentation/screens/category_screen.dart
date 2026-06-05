import 'package:flutter/material.dart';
import 'package:reem/core/design_system/design_system.dart';
import 'package:reem/core/localization/l10n_extension.dart';
import 'package:reem/features/home/data/datasources/dummy_data.dart';
import 'package:reem/features/home/presentation/widgets/coupons_strip.dart';
import 'package:reem/features/home/presentation/widgets/home_header.dart';
import 'package:reem/features/home/presentation/widgets/social_feed_post.dart';

class CategoryScreen extends StatelessWidget {
  final String category;
  const CategoryScreen({super.key, required this.category});

  @override
  Widget build(BuildContext context) {
    final List products = posts
        .where((p) => p.category.name.toLowerCase() == category.toLowerCase())
        .toList();
    final l10n = context.l10n;
    return ReemScrollPage(
      slivers: [
        PremiumAppBar(title: l10n.appTitle),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(
            DsSpacing.lg,
            DsSpacing.sm,
            DsSpacing.lg,
            120,
          ),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              const HomeHeader(),
              const SizedBox(height: DsSpacing.xl),
              const CouponsStrip(),
              const SizedBox(height: DsSpacing.xxl),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ReemSectionHeader(
                    title: '$category For You',
                    subtitle: 'Shop what she’s wearing',
                  ),
                  const SizedBox(height: DsSpacing.lg),
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: products.length,
                    separatorBuilder: (_, _) =>
                        const SizedBox(height: DsSpacing.xl),
                    itemBuilder: (context, index) {
                      final post = products[index];
                      final productMedia = post.product.media;
                      final imageUrl = productMedia.isNotEmpty
                          ? productMedia.first.url
                          : '';

                      return SocialFeedPost(
                        authorName: post.author.name,
                        authorAvatar: post.author.imageUrl ?? '',
                        imageUrl: imageUrl,
                        caption: post.caption,
                        likes: '${post.likesCount}K',
                        comments: '${post.commentsCount}',
                        productName: post.product.title,
                        productPrice:
                            '\$${post.product.price.toStringAsFixed(0)}',
                        timeAgo:
                            post.createdAt.isAfter(
                              DateTime.now().subtract(const Duration(hours: 2)),
                            )
                            ? 'Just now'
                            : '',
                        postId: post.id,
                      );
                    },
                  ),
                ],
              ),
            ]),
          ),
        ),
      ],
    );
  }
}
