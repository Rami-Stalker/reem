import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/design_system/design_system.dart';
import '../../../../core/router/route_names.dart';
import '../../../../core/shared/wedgets/buttons/animated_like_button.dart';

/// Full-width social commerce post — shop + interact like Instagram.
class SocialFeedPost extends StatelessWidget {
  const SocialFeedPost({
    super.key,
    required this.authorName,
    required this.authorAvatar,
    required this.imageUrl,
    required this.caption,
    required this.likes,
    required this.comments,
    this.productName,
    this.productPrice,
    this.timeAgo = '2h ago',
  });

  final String authorName;
  final String authorAvatar;
  final String imageUrl;
  final String caption;
  final String likes;
  final String comments;
  final String? productName;
  final String? productPrice;
  final String timeAgo;

  @override
  Widget build(BuildContext context) {
    final colors = context.dsColors;
    return DsGlassCard(
      padding: EdgeInsets.zero,
      borderRadius: DsRadius.xxxl,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              DsSpacing.md, DsSpacing.md, DsSpacing.md, DsSpacing.sm,
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundImage: NetworkImage(authorAvatar),
                ),
                const SizedBox(width: DsSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        authorName,
                        style: TextStyle(
                          fontWeight: DsTypography.semiBold,
                          color: colors.onSurface,
                        ),
                      ),
                      Text(
                        timeAgo,
                        style: TextStyle(
                          fontSize: DsTypography.labelSmall,
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.more_horiz_rounded, color: colors.onSurfaceVariant),
              ],
            ),
          ),
          GestureDetector(
            onTap: () => context.pushNamed(RouteNames.productDetails),
            child: Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(0),
                  ),
                  child: AspectRatio(
                    aspectRatio: 1,
                    child: Image.network(imageUrl, fit: BoxFit.cover),
                  ),
                ),
                if (productName != null)
                  Positioned(
                    left: DsSpacing.md,
                    bottom: DsSpacing.md,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: DsSpacing.md,
                        vertical: DsSpacing.xs,
                      ),
                      decoration: BoxDecoration(
                        gradient: DsGradients.primarySoft,
                        borderRadius: DsRadius.borderFull,
                        boxShadow: context.softShadow,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.shopping_bag_rounded,
                              size: 16, color: colors.onPrimary),
                          const SizedBox(width: 6),
                          Text(
                            productPrice != null
                                ? '$productName · $productPrice'
                                : productName!,
                            style: TextStyle(
                              color: colors.onPrimary,
                              fontWeight: DsTypography.semiBold,
                              fontSize: DsTypography.labelMedium,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(DsSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const AnimatedLikeButton(),
                    const SizedBox(width: DsSpacing.md),
                    Icon(Icons.chat_bubble_outline_rounded,
                        color: colors.onSurface),
                    const SizedBox(width: 4),
                    Text(comments, style: TextStyle(color: colors.onSurface)),
                    const Spacer(),
                    Icon(Icons.bookmark_border_rounded, color: colors.onSurface),
                    const SizedBox(width: DsSpacing.md),
                    Icon(Icons.share_rounded, color: colors.primary),
                  ],
                ),
                const SizedBox(height: DsSpacing.sm),
                Text(
                  '$likes likes',
                  style: TextStyle(
                    fontWeight: DsTypography.semiBold,
                    color: colors.onSurface,
                  ),
                ),
                const SizedBox(height: 4),
                Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: '$authorName ',
                        style: TextStyle(fontWeight: DsTypography.semiBold),
                      ),
                      TextSpan(text: caption),
                    ],
                  ),
                  style: TextStyle(
                    color: colors.onSurface,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 500.ms).slideY(begin: 0.06);
  }
}
