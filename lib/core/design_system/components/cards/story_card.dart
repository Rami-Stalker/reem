import 'package:flutter/material.dart';
import 'package:reem/core/design_system/components/avatars/ds_avatar.dart';
import 'package:reem/core/design_system/components/loaders/ds_skeleton.dart';
import 'package:reem/core/design_system/foundation/motion/animations/scale_animations.dart';
import 'package:reem/core/design_system/foundation/theme/extensions/color_extension.dart';
import 'package:reem/core/design_system/foundation/theme/extensions/typography_extension.dart';
import 'package:reem/core/design_system/foundation/tokens/ds_gaps.dart';
import 'package:reem/core/design_system/foundation/tokens/ds_sizes.dart';
import 'package:reem/core/design_system/foundation/tokens/ds_spacing.dart';

/// A circular story bubble (avatar + gradient ring + label) for story rails.
class DsStoryCard extends StatelessWidget {
  const DsStoryCard({
    super.key,
    required this.label,
    this.imageUrl,
    this.seen = false,
    this.isVerified = false,
    this.onTap,
    this.size = 64,
    this.width = 76,
  });

  final String label;
  final String? imageUrl;
  final bool seen;

  /// Shows a verified tick beside the label — a boutique rail needs to say
  /// which shops the platform has vetted.
  final bool isVerified;
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
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: seen
                      ? context.dsText.caption
                      : context.dsText.caption.medium.tint(c.onSurface),
                ),
              ),
              if (isVerified) ...[
                DsGaps.hXxxs,
                Icon(
                  Icons.verified_rounded,
                  size: DsSizes.iconXxs,
                  color: c.secondary,
                ),
              ],
            ],
          ),
        ],
      ),
    );

    if (onTap == null) return content;
    return DsScaleAnimations.tapScale(onTap: onTap!, child: content);
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
