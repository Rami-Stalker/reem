import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../foundation/motion/animations/scale_animations.dart';
import '../../foundation/theme/extensions/color_extension.dart';
import '../../foundation/theme/extensions/gradient_extension.dart';
import '../../foundation/tokens/ds_radius.dart';
import '../../foundation/tokens/ds_spacing.dart';
import '../../foundation/tokens/ds_typography.dart';
import '../avatars/ds_avatar.dart';
import '../loaders/ds_skeleton.dart';

/// A circular story bubble (avatar + gradient ring + label) for story rails.
class DsStoryCard extends StatelessWidget {
  const DsStoryCard({
    super.key,
    required this.label,
    this.imageUrl,
    this.seen = false,
    this.onTap,
    this.size = 64,
    this.width = 76,
  });

  final String label;
  final String? imageUrl;
  final bool seen;
  final VoidCallback? onTap;
  final double size;
  final double width;

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    final content = SizedBox(
      width: width,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DsAvatar(
            imageUrl: imageUrl,
            name: label,
            size: size,
            hasRing: true,
            ringSeen: seen,
          ),
          const SizedBox(height: DsSpacing.xs),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: seen ? c.onSurfaceVariant : c.onSurface,
                  fontWeight: seen ? DsTypography.regular : DsTypography.medium,
                ),
          ),
        ],
      ),
    );

    if (onTap == null) return content;
    return DsScaleAnimations.tapScale(onTap: onTap!, child: content);
  }
}

/// "Your story" entry with a + affordance.
class DsStoryAddCard extends StatelessWidget {
  const DsStoryAddCard({
    super.key,
    required this.label,
    this.imageUrl,
    this.onTap,
    this.size = 64,
    this.width = 76,
  });

  final String label;
  final String? imageUrl;
  final VoidCallback? onTap;
  final double size;
  final double width;

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    final content = SizedBox(
      width: width,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              DsAvatar(imageUrl: imageUrl, name: label, size: size),
              Positioned(
                right: -2,
                bottom: -2,
                child: Container(
                  width: size * 0.34,
                  height: size * 0.34,
                  decoration: BoxDecoration(
                    gradient: context.primaryGradient,
                    shape: BoxShape.circle,
                    border: Border.all(color: c.surface, width: 2),
                  ),
                  child: Icon(Icons.add_rounded,
                      size: size * 0.2, color: c.onPrimary),
                ),
              ),
            ],
          ),
          const SizedBox(height: DsSpacing.xs),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: Theme.of(context)
                .textTheme
                .labelSmall
                ?.copyWith(color: c.onSurface, fontWeight: DsTypography.medium),
          ),
        ],
      ),
    );

    if (onTap == null) return content;
    return DsScaleAnimations.tapScale(onTap: onTap!, child: content);
  }
}

/// A tall image story-preview tile (richer story rails / discover).
class DsStoryTile extends StatelessWidget {
  const DsStoryTile({
    super.key,
    required this.authorName,
    this.imageUrl,
    this.authorAvatarUrl,
    this.seen = false,
    this.onTap,
    this.width = 112,
    this.aspectRatio = 3 / 4,
  });

  final String authorName;
  final String? imageUrl;
  final String? authorAvatarUrl;
  final bool seen;
  final VoidCallback? onTap;
  final double width;
  final double aspectRatio;

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    final tile = SizedBox(
      width: width,
      child: AspectRatio(
        aspectRatio: aspectRatio,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: DsRadius.borderXl,
            border: Border.all(
              color: seen ? c.border : c.primary,
              width: seen ? 1 : 2.5,
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (imageUrl != null && imageUrl!.isNotEmpty)
                CachedNetworkImage(
                  imageUrl: imageUrl!,
                  fit: BoxFit.cover,
                  placeholder: (_, _) => ColoredBox(color: c.shimmerBase),
                  errorWidget: (_, _, _) =>
                      ColoredBox(color: c.surfaceVariant),
                )
              else
                ColoredBox(color: c.surfaceVariant),
              DecoratedBox(
                decoration: BoxDecoration(gradient: context.imageScrim),
              ),
              Positioned(
                left: DsSpacing.xs,
                bottom: DsSpacing.xs,
                right: DsSpacing.xs,
                child: Row(
                  children: [
                    DsAvatar(
                      imageUrl: authorAvatarUrl,
                      name: authorName,
                      size: 26,
                    ),
                    const SizedBox(width: DsSpacing.xs),
                    Expanded(
                      child: Text(
                        authorName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: DsTypography.labelSmall,
                          fontWeight: DsTypography.semiBold,
                          shadows: const [
                            Shadow(blurRadius: 4, color: Colors.black54),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (onTap == null) return tile;
    return DsScaleAnimations.tapScale(
        pressedScale: 0.97, onTap: onTap!, child: tile);
  }
}

/// Loading placeholder for a story bubble.
class DsStoryCardSkeleton extends StatelessWidget {
  const DsStoryCardSkeleton({super.key, this.size = 64, this.width = 76});

  final double size;
  final double width;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: DsShimmer(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DsSkeleton.circle(size: size),
            const SizedBox(height: DsSpacing.xs),
            const DsSkeleton.line(width: 48),
          ],
        ),
      ),
    );
  }
}
