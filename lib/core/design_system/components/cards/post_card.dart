import 'package:flutter/material.dart';
import 'package:reem/core/design_system/components/loaders/ds_skeleton.dart';
import 'package:reem/core/design_system/foundation/theme/extensions/color_extension.dart';
import 'package:reem/core/design_system/foundation/tokens/ds_radius.dart';
import 'package:reem/core/design_system/foundation/tokens/ds_spacing.dart';

/// The content-shaped placeholder a post occupies while the feed loads.
///
/// The card it used to accompany, `DsPostCard`, is gone: the home feed is
/// built on `ReemPostCard`, and a second post card in the design system was
/// only ever a chance for the two to drift apart. The skeleton stays, because
/// it is the shape of the real card and nothing else needs to know that.
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
