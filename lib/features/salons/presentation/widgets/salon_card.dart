import 'package:flutter/material.dart';

import 'package:reem/core/design_system/design_system.dart';
import 'package:reem/core/media/authorized_media_image.dart';
import 'package:reem/core/media/media_variants.dart';
import 'package:reem/features/salons/domain/entities/salon.dart';

/// One salon in the directory.
///
/// What a woman choosing a salon actually scans, in the order she scans it:
/// the photograph, the name, where it is, what it costs to start with, and
/// whether anyone has been. Everything else waits for the page.
class SalonCard extends StatelessWidget {
  const SalonCard({super.key, required this.salon, this.onTap});

  final Salon salon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
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
            _Cover(salon: salon),
            Padding(
              padding: const EdgeInsets.all(DsSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    salon.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.dsText.cardTitle.tint(c.onSurface),
                  ),
                  DsGaps.vXxxs,
                  Row(
                    children: [
                      Icon(
                        Icons.place_outlined,
                        size: 14,
                        color: c.onSurfaceVariant,
                      ),
                      const SizedBox(width: DsSpacing.xxxs),
                      Expanded(
                        child: Text(
                          salon.area,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: context.dsText.caption.tint(c.onSurfaceVariant),
                        ),
                      ),
                    ],
                  ),
                  DsGaps.vXs,
                  Row(
                    children: [
                      if (salon.priceFrom != null) ...[
                        Text(
                          'من ${salon.priceFrom!.format()}',
                          style: DsTypography.price(
                            c.price,
                            size: DsTypography.bodySmall,
                          ),
                        ),
                        const Spacer(),
                      ] else
                        const Spacer(),
                      // A salon nobody has reviewed says so, rather than
                      // showing a hollow 0.0 that reads as a bad rating.
                      if (salon.hasBeenReviewed)
                        _Rating(salon: salon)
                      else
                        Text(
                          'جديد',
                          style: context.dsText.caption.semibold.tint(c.primary),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Rating extends StatelessWidget {
  const _Rating({required this.salon});

  final Salon salon;

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.star_rounded, size: 15, color: c.warning),
        DsGaps.hXxxs,
        Text(
          salon.rating.toStringAsFixed(1),
          style: context.dsText.caption.semibold.tint(c.onSurface),
        ),
        DsGaps.hXxxs,
        Text(
          '(${salon.reviewsCount})',
          style: context.dsText.micro.tint(c.onSurfaceVariant),
        ),
      ],
    );
  }
}

class _Cover extends StatelessWidget {
  const _Cover({required this.salon});

  final Salon salon;

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    final url = salon.coverUrl ?? salon.logoUrl;

    return AspectRatio(
      aspectRatio: 16 / 10,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (url != null && url.isNotEmpty)
            AuthorizedMediaImage(
              url: url,
              variantWidth: MediaVariants.thumbnail,
              fallback: ColoredBox(color: c.surfaceVariant),
            )
          else
            DecoratedBox(
              decoration: BoxDecoration(gradient: context.primaryGradient),
              child: Center(
                child: Icon(
                  Icons.content_cut_rounded,
                  size: 32,
                  color: c.onPrimary.withValues(alpha: 0.85),
                ),
              ),
            ),

          // «تأتي إلى منزلكِ» is the one fact worth putting on the photograph:
          // for a woman with a small child it decides the whole choice.
          if (salon.homeService)
            PositionedDirectional(
              top: DsSpacing.xs,
              start: DsSpacing.xs,
              child: DsBadge(
                label: 'خدمة منزلية',
                tone: DsBadgeTone.primary,
              ),
            ),
          if (salon.isFeatured)
            PositionedDirectional(
              top: DsSpacing.xs,
              end: DsSpacing.xs,
              child: DsBadge(label: 'مختار', tone: DsBadgeTone.accent),
            ),
        ],
      ),
    );
  }
}
