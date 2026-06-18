import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/design_system/design_system.dart';
import '../../../../core/router/route_paths.dart';
import '../../../../core/shared/entities/post.dart';
import '../../../../core/shared/entities/product.dart';
import '../../../social_posts/presentation/providers/social_posts_providers.dart';
import '../../../social_posts/presentation/widgets/comment_sheet.dart';

/// The hero of the home feed: a product presented as a polished social post —
/// author header, immersive shoppable media, double-tap-to-love, engagement
/// bar, caption and comments. Built entirely on the design system.
class FeedPostCard extends ConsumerStatefulWidget {
  const FeedPostCard({super.key, required this.post});

  final Post post;

  @override
  ConsumerState<FeedPostCard> createState() => _FeedPostCardState();
}

class _FeedPostCardState extends ConsumerState<FeedPostCard>
    with TickerProviderStateMixin {
  late bool _liked = widget.post.isLiked;
  late bool _saved = widget.post.isSaved;
  late int _likes = widget.post.likesCount;

  late final AnimationController _burst = AnimationController(
    vsync: this,
    duration: DsMotion.slow,
  );

  @override
  void dispose() {
    _burst.dispose();
    super.dispose();
  }

  Post get post => widget.post;

  void _toggleLike({bool fromDoubleTap = false}) {
    final willLike = fromDoubleTap ? true : !_liked;
    if (willLike == _liked && !fromDoubleTap) return;
    setState(() {
      if (willLike != _liked) _likes += willLike ? 1 : -1;
      _liked = willLike;
    });
    if (fromDoubleTap) {
      _burst.forward(from: 0);
    }
    ref.read(toggleLikeUseCaseProvider).call(post.id);
  }

  void _toggleSave() {
    setState(() => _saved = !_saved);
    ref.read(toggleSaveUseCaseProvider).call(post.id);
  }

  void _openProduct() =>
      context.push('${RoutePaths.productDetails}?id=${post.product.id}');

  void _openComments() => showCommentSheet(context, post.id);

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    return Container(
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
          _Header(post: post, onProduct: _openProduct),
          _Media(
            post: post,
            liked: _liked,
            burst: _burst,
            onTap: _openProduct,
            onDoubleTap: () => _toggleLike(fromDoubleTap: true),
          ),
          _ActionBar(
            liked: _liked,
            saved: _saved,
            commentsCount: post.commentsCount,
            sharesCount: post.sharesCount,
            onLike: _toggleLike,
            onComment: _openComments,
            onSave: _toggleSave,
            onShare: () => ref.read(sharePostUseCaseProvider).call(post.id),
          ),
          _Caption(
            post: post,
            likes: _likes,
            onComments: _openComments,
          ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.post, required this.onProduct});

  final Post post;
  final VoidCallback onProduct;

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    final theme = Theme.of(context);
    final author = post.product.seller;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
          DsSpacing.sm, DsSpacing.sm, DsSpacing.xs, DsSpacing.sm),
      child: Row(
        children: [
          DsAvatar(
            imageUrl: author.imageUrl,
            name: author.name,
            size: 42,
            hasRing: true,
            ringSeen: true,
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
                        author.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleSmall
                            ?.copyWith(fontWeight: DsTypography.semiBold),
                      ),
                    ),
                    if (author.isVerified) ...[
                      const SizedBox(width: DsSpacing.xxs),
                      Icon(Icons.verified_rounded,
                          size: 15, color: c.secondary),
                    ],
                  ],
                ),
                Text(
                  'in ${post.category.label} · ${_timeAgo(post.createdAt)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelSmall
                      ?.copyWith(color: c.onSurfaceVariant),
                ),
              ],
            ),
          ),
          DsIconButton(
            icon: Icons.more_horiz_rounded,
            variant: DsIconButtonVariant.ghost,
            size: 36,
            onPressed: onProduct,
          ),
        ],
      ),
    );
  }
}

class _Media extends StatelessWidget {
  const _Media({
    required this.post,
    required this.liked,
    required this.burst,
    required this.onTap,
    required this.onDoubleTap,
  });

  final Post post;
  final bool liked;
  final AnimationController burst;
  final VoidCallback onTap;
  final VoidCallback onDoubleTap;

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    final product = post.product;
    final imageUrl = post.cover?.displayUrl ?? '';

    return GestureDetector(
      onTap: onTap,
      onDoubleTap: onDoubleTap,
      child: AspectRatio(
        aspectRatio: 4 / 5,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (imageUrl.isNotEmpty)
              CachedNetworkImage(
                imageUrl: imageUrl,
                fit: BoxFit.cover,
                placeholder: (_, _) => ColoredBox(color: c.shimmerBase),
                errorWidget: (_, _, _) => ColoredBox(
                  color: c.surfaceVariant,
                  child: Icon(Icons.image_outlined,
                      color: c.onSurfaceVariant.withValues(alpha: 0.5)),
                ),
              )
            else
              ColoredBox(color: c.surfaceVariant),

            // Bottom scrim for legible shop pill.
            DecoratedBox(
              decoration: BoxDecoration(gradient: context.imageScrim),
            ),

            // Discount badge.
            if (product.hasDiscount)
              Positioned(
                top: DsSpacing.sm,
                left: DsSpacing.sm,
                child: DsDiscountBadge(percentOff: product.discountPercent),
              ),

            // Shoppable price pill.
            Positioned(
              left: DsSpacing.sm,
              right: DsSpacing.sm,
              bottom: DsSpacing.sm,
              child: _ShopPill(product: product, onTap: onTap),
            ),

            // Double-tap heart burst.
            Center(
              child: _HeartBurst(controller: burst),
            ),
          ],
        ),
      ),
    );
  }
}

class _ShopPill extends StatelessWidget {
  const _ShopPill({required this.product, required this.onTap});

  final Product product;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.fromLTRB(
            DsSpacing.xs, DsSpacing.xs, DsSpacing.xxs, DsSpacing.xs),
        decoration: BoxDecoration(
          color: c.surface.withValues(alpha: 0.92),
          borderRadius: DsRadius.borderPill,
          boxShadow: context.shadowXs,
        ),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                gradient: context.primaryGradient,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.shopping_bag_outlined,
                  size: 18, color: c.onPrimary),
            ),
            const SizedBox(width: DsSpacing.xs),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    product.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: c.onSurface,
                      fontWeight: DsTypography.semiBold,
                    ),
                  ),
                  Row(
                    children: [
                      Text(
                        '\$${product.price.toStringAsFixed(0)}',
                        style: DsTypography.price(c.price,
                            size: DsTypography.labelLarge),
                      ),
                      if (product.hasDiscount) ...[
                        const SizedBox(width: DsSpacing.xxs),
                        Text(
                          '\$${product.oldPrice!.toStringAsFixed(0)}',
                          style: DsTypography.priceStrike(c.onSurfaceVariant),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: DsSpacing.xs),
              child: Icon(Icons.arrow_forward_ios_rounded,
                  size: 13, color: c.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeartBurst extends StatelessWidget {
  const _HeartBurst({required this.controller});

  final AnimationController controller;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        if (controller.value == 0) return const SizedBox.shrink();
        final scale = Curves.easeOutBack.transform(
          (controller.value * 1.6).clamp(0.0, 1.0),
        );
        final opacity = 1 - Curves.easeIn.transform(
          ((controller.value - 0.5) * 2).clamp(0.0, 1.0),
        );
        return Opacity(
          opacity: opacity,
          child: Transform.scale(
            scale: 0.6 + scale * 0.6,
            child: Icon(
              Icons.favorite_rounded,
              size: 96,
              color: Colors.white.withValues(alpha: 0.92),
              shadows: const [Shadow(blurRadius: 24, color: Colors.black38)],
            ),
          ),
        );
      },
    );
  }
}

class _ActionBar extends StatelessWidget {
  const _ActionBar({
    required this.liked,
    required this.saved,
    required this.commentsCount,
    required this.sharesCount,
    required this.onLike,
    required this.onComment,
    required this.onSave,
    required this.onShare,
  });

  final bool liked;
  final bool saved;
  final int commentsCount;
  final int sharesCount;
  final void Function({bool fromDoubleTap}) onLike;
  final VoidCallback onComment;
  final VoidCallback onSave;
  final VoidCallback onShare;

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    return Padding(
      padding: const EdgeInsets.symmetric(
          horizontal: DsSpacing.xs, vertical: DsSpacing.xxs),
      child: Row(
        children: [
          _ActionButton(
            icon: liked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
            color: liked ? c.favorite : c.onSurface,
            onTap: () => onLike(),
            animate: true,
            active: liked,
          ),
          _ActionButton(
            icon: Icons.mode_comment_outlined,
            color: c.onSurface,
            label: commentsCount > 0 ? _count(commentsCount) : null,
            onTap: onComment,
          ),
          _ActionButton(
            icon: Icons.send_outlined,
            color: c.onSurface,
            label: sharesCount > 0 ? _count(sharesCount) : null,
            onTap: onShare,
          ),
          const Spacer(),
          _ActionButton(
            icon: saved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
            color: saved ? c.secondary : c.onSurface,
            onTap: onSave,
            animate: true,
            active: saved,
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.color,
    required this.onTap,
    this.label,
    this.animate = false,
    this.active = false,
  });

  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final String? label;
  final bool animate;
  final bool active;

  @override
  Widget build(BuildContext context) {
    Widget iconWidget = Icon(icon, size: DsConstraints.iconMd, color: color);
    if (animate) {
      iconWidget = AnimatedScale(
        scale: active ? 1.12 : 1,
        duration: DsMotion.fast,
        curve: DsMotion.softSpring,
        child: iconWidget,
      );
    }
    return InkResponse(
      onTap: onTap,
      radius: 26,
      child: Padding(
        padding: const EdgeInsets.all(DsSpacing.xs),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            iconWidget,
            if (label != null) ...[
              const SizedBox(width: DsSpacing.xxs),
              Text(
                label!,
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
}

class _Caption extends StatelessWidget {
  const _Caption({
    required this.post,
    required this.likes,
    required this.onComments,
  });

  final Post post;
  final int likes;
  final VoidCallback onComments;

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          DsSpacing.sm, DsSpacing.xxs, DsSpacing.sm, DsSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (likes > 0)
            Text(
              '${_count(likes)} ${likes == 1 ? 'like' : 'likes'}',
              style: theme.textTheme.labelLarge
                  ?.copyWith(fontWeight: DsTypography.semiBold),
            ),
          if (post.caption.isNotEmpty) ...[
            const SizedBox(height: DsSpacing.xxs),
            RichText(
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              text: TextSpan(
                style: theme.textTheme.bodyMedium,
                children: [
                  TextSpan(
                    text: '${post.product.seller.name}  ',
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(fontWeight: DsTypography.semiBold),
                  ),
                  TextSpan(text: post.caption),
                ],
              ),
            ),
          ],
          if (post.commentsCount > 0) ...[
            const SizedBox(height: DsSpacing.xs),
            GestureDetector(
              onTap: onComments,
              child: Text(
                'View all ${_count(post.commentsCount)} comments',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: c.onSurfaceVariant),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

String _timeAgo(DateTime date) {
  final diff = DateTime.now().difference(date);
  if (diff.inMinutes < 1) return 'now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m';
  if (diff.inHours < 24) return '${diff.inHours}h';
  if (diff.inDays < 7) return '${diff.inDays}d';
  return '${(diff.inDays / 7).floor()}w';
}

String _count(int n) {
  if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
  if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
  return '$n';
}
