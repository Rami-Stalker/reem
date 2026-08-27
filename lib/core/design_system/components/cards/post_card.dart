import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:reem/core/design_system/components/avatars/ds_avatar.dart';
import 'package:reem/core/design_system/components/buttons/ds_icon_button.dart';
import 'package:reem/core/design_system/components/loaders/ds_skeleton.dart';
import 'package:reem/core/design_system/foundation/motion/animations/scale_animations.dart';
import 'package:reem/core/design_system/foundation/theme/extensions/color_extension.dart';
import 'package:reem/core/design_system/foundation/theme/extensions/shadow_extension.dart';
import 'package:reem/core/design_system/foundation/tokens/ds_constraints.dart';
import 'package:reem/core/design_system/foundation/tokens/ds_radius.dart';
import 'package:reem/core/design_system/foundation/tokens/ds_spacing.dart';
import 'package:reem/core/design_system/foundation/tokens/ds_typography.dart';

/// A premium social post card — author header, media, engagement actions and
/// an optional "shop this" product tag.
class DsPostCard extends StatelessWidget {
  const DsPostCard({
    super.key,
    required this.authorName,
    this.authorAvatarUrl,
    this.subtitle,
    this.isVerified = false,
    this.imageUrl,
    this.mediaAspectRatio = 1,
    this.caption,
    this.likeCount = 0,
    this.commentCount = 0,
    this.isLiked = false,
    this.isSaved = false,
    this.taggedProductLabel,
    this.onTap,
    this.onAuthorTap,
    this.onLike,
    this.onComment,
    this.onShare,
    this.onSave,
    this.onMore,
    this.onProductTap,
  });

  final String authorName;
  final String? authorAvatarUrl;
  final String? subtitle;
  final bool isVerified;
  final String? imageUrl;
  final double mediaAspectRatio;
  final String? caption;
  final int likeCount;
  final int commentCount;
  final bool isLiked;
  final bool isSaved;
  final String? taggedProductLabel;
  final VoidCallback? onTap;
  final VoidCallback? onAuthorTap;
  final VoidCallback? onLike;
  final VoidCallback? onComment;
  final VoidCallback? onShare;
  final VoidCallback? onSave;
  final VoidCallback? onMore;
  final VoidCallback? onProductTap;

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    final theme = Theme.of(context);

    final card = Container(
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: DsRadius.borderCard,
        border: Border.all(color: c.border.withValues(alpha: 0.5)),
        boxShadow: context.shadowSoft,
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(
                DsSpacing.sm, DsSpacing.sm, DsSpacing.xs, DsSpacing.sm),
            child: Row(
              children: [
                DsAvatar(
                  imageUrl: authorAvatarUrl,
                  name: authorName,
                  size: 40,
                  onTap: onAuthorTap,
                ),
                const SizedBox(width: DsSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              authorName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: DsTypography.semiBold,
                              ),
                            ),
                          ),
                          if (isVerified) ...[
                            const SizedBox(width: DsSpacing.xxs),
                            Icon(Icons.verified_rounded,
                                size: 15, color: c.secondary),
                          ],
                        ],
                      ),
                      if (subtitle != null)
                        Text(
                          subtitle!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.labelSmall
                              ?.copyWith(color: c.onSurfaceVariant),
                        ),
                    ],
                  ),
                ),
                if (onMore != null)
                  DsIconButton(
                    icon: Icons.more_horiz_rounded,
                    variant: DsIconButtonVariant.ghost,
                    size: 36,
                    iconSize: DsConstraints.iconMd,
                    onPressed: onMore,
                  ),
              ],
            ),
          ),
          // Media
          if (imageUrl != null && imageUrl!.isNotEmpty)
            _Media(
              imageUrl: imageUrl!,
              aspectRatio: mediaAspectRatio,
              taggedProductLabel: taggedProductLabel,
              onProductTap: onProductTap,
            ),
          // Actions
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: DsSpacing.xs,
              vertical: DsSpacing.xxs,
            ),
            child: Row(
              children: [
                _Action(
                  icon: isLiked
                      ? Icons.favorite_rounded
                      : Icons.favorite_border_rounded,
                  color: isLiked ? c.favorite : c.onSurface,
                  count: likeCount,
                  onTap: onLike,
                ),
                _Action(
                  icon: Icons.mode_comment_outlined,
                  color: c.onSurface,
                  count: commentCount,
                  onTap: onComment,
                ),
                _Action(
                  icon: Icons.send_outlined,
                  color: c.onSurface,
                  onTap: onShare,
                ),
                const Spacer(),
                DsIconButton(
                  icon: isSaved
                      ? Icons.bookmark_rounded
                      : Icons.bookmark_border_rounded,
                  variant: DsIconButtonVariant.ghost,
                  size: 38,
                  color: isSaved ? c.secondary : c.onSurface,
                  onPressed: onSave,
                ),
              ],
            ),
          ),
          // Caption
          if (caption != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  DsSpacing.sm, 0, DsSpacing.sm, DsSpacing.sm),
              child: RichText(
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                text: TextSpan(
                  style: theme.textTheme.bodyMedium,
                  children: [
                    TextSpan(
                      text: '$authorName  ',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: DsTypography.semiBold,
                      ),
                    ),
                    TextSpan(text: caption),
                  ],
                ),
              ),
            ),
        ],
      ),
    );

    if (onTap == null) return card;
    return DsScaleAnimations.tapScale(
        pressedScale: 0.99, onTap: onTap!, child: card);
  }
}

class _Media extends StatelessWidget {
  const _Media({
    required this.imageUrl,
    required this.aspectRatio,
    this.taggedProductLabel,
    this.onProductTap,
  });

  final String imageUrl;
  final double aspectRatio;
  final String? taggedProductLabel;
  final VoidCallback? onProductTap;

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    return AspectRatio(
      aspectRatio: aspectRatio,
      child: Stack(
        fit: StackFit.expand,
        children: [
          CachedNetworkImage(
            imageUrl: imageUrl,
            fit: BoxFit.cover,
            placeholder: (_, _) => ColoredBox(color: c.shimmerBase),
            errorWidget: (_, _, _) => ColoredBox(
              color: c.surfaceVariant,
              child: Icon(Icons.broken_image_outlined,
                  color: c.onSurfaceVariant.withValues(alpha: 0.5)),
            ),
          ),
          if (taggedProductLabel != null)
            Positioned(
              left: DsSpacing.sm,
              bottom: DsSpacing.sm,
              child: GestureDetector(
                onTap: onProductTap,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: DsSpacing.sm,
                    vertical: DsSpacing.xs,
                  ),
                  decoration: BoxDecoration(
                    color: c.glass,
                    borderRadius: DsRadius.borderPill,
                    border: Border.all(color: c.glassBorder),
                    boxShadow: context.shadowXs,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.shopping_bag_outlined,
                          size: 15, color: c.onSurface),
                      const SizedBox(width: DsSpacing.xs),
                      Text(
                        taggedProductLabel!,
                        style: Theme.of(context).textTheme.labelMedium?.copyWith(
                              color: c.onSurface,
                              fontWeight: DsTypography.semiBold,
                            ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _Action extends StatelessWidget {
  const _Action({
    required this.icon,
    required this.color,
    this.count,
    this.onTap,
  });

  final IconData icon;
  final Color color;
  final int? count;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final hasCount = count != null && count! > 0;
    return InkWell(
      onTap: onTap,
      borderRadius: DsRadius.borderPill,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: DsSpacing.xs,
          vertical: DsSpacing.xs,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: DsConstraints.iconMd, color: color),
            if (hasCount) ...[
              const SizedBox(width: DsSpacing.xxs),
              Text(
                _format(count!),
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: context.dsColors.onSurface,
                      fontWeight: DsTypography.medium,
                    ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  static String _format(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
    return '$n';
  }
}

/// Loading placeholder matching [DsPostCard].
class DsPostCardSkeleton extends StatelessWidget {
  const DsPostCardSkeleton({super.key, this.mediaAspectRatio = 1});

  final double mediaAspectRatio;

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    return Container(
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: DsRadius.borderCard,
        border: Border.all(color: c.border.withValues(alpha: 0.5)),
      ),
      clipBehavior: Clip.antiAlias,
      child: DsShimmer(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(DsSpacing.sm),
              child: Row(
                children: const [
                  DsSkeleton.circle(size: 40),
                  SizedBox(width: DsSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        DsSkeleton.line(width: 120),
                        SizedBox(height: DsSpacing.xs),
                        DsSkeleton.line(width: 80),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            AspectRatio(
              aspectRatio: mediaAspectRatio,
              child: const DsSkeleton(height: double.infinity, borderRadius: 0),
            ),
            const Padding(
              padding: EdgeInsets.all(DsSpacing.sm),
              child: DsSkeleton.line(width: 160),
            ),
          ],
        ),
      ),
    );
  }
}
