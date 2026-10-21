import 'package:flutter/material.dart';

import 'package:reem/core/design_system/design_system.dart';
import 'package:reem/core/media/authorized_media_image.dart';
import 'package:reem/core/media/media_variants.dart';
import 'package:reem/features/salons/domain/entities/salon.dart';
import 'package:reem/features/salons/presentation/widgets/salon_labels.dart';

/// One line of the menu: what it is, how long it takes, what it costs, and the
/// one button that matters.
class SalonServiceTile extends StatelessWidget {
  const SalonServiceTile({super.key, required this.service, this.onBook});

  final SalonService service;
  final VoidCallback? onBook;

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;

    return SurfaceCard(
      padding: const EdgeInsets.all(DsSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (service.imageUrl != null && service.imageUrl!.isNotEmpty) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(DsRadius.md),
              child: SizedBox(
                width: 68,
                height: 68,
                child: AuthorizedMediaImage(
                  url: service.imageUrl!,
                  variantWidth: MediaVariants.thumbnail,
                  fallback: ColoredBox(color: c.surfaceVariant),
                ),
              ),
            ),
            const SizedBox(width: DsSpacing.sm),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        service.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: context.dsText.tileTitle.semibold.tint(
                          c.onSurface,
                        ),
                      ),
                    ),
                    // «الباقات» — said on the tile, because a package priced
                    // like a single service otherwise looks like a mistake.
                    if (service.isPackage) ...[
                      const SizedBox(width: DsSpacing.xs),
                      DsBadge(label: 'باقة', tone: DsBadgeTone.accent),
                    ],
                  ],
                ),
                if (service.description != null &&
                    service.description!.isNotEmpty) ...[
                  DsGaps.vXxxs,
                  Text(
                    service.description!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: context.dsText.cardSubtitle.tint(c.onSurfaceVariant),
                  ),
                ],
                DsGaps.vXs,
                Wrap(
                  spacing: DsSpacing.xs,
                  runSpacing: DsSpacing.xxxs,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    _Fact(
                      icon: Icons.schedule_rounded,
                      label: SalonLabels.duration(service.durationMinutes),
                    ),
                    if (service.location.travels)
                      _Fact(
                        icon: Icons.home_outlined,
                        label: SalonLabels.location(service.location),
                      ),
                  ],
                ),
                DsGaps.vXs,
                Row(
                  children: [
                    Text(
                      service.price.format(),
                      style: DsTypography.price(
                        c.price,
                        size: DsTypography.bodyMedium,
                      ),
                    ),
                    // Only when the server says it is genuinely an offer. A
                    // compare-at at or below the asking price is a data error,
                    // not a deal.
                    if (service.hasOffer && service.compareAtPrice != null) ...[
                      const SizedBox(width: DsSpacing.xs),
                      Text(
                        service.compareAtPrice!.format(includeSymbol: false),
                        style: DsTypography.priceStrike(c.onSurfaceVariant),
                      ),
                    ],
                    const Spacer(),
                    if (onBook != null)
                      DsButton(
                        label: 'احجزي',
                        size: DsButtonSize.sm,
                        isExpanded: false,
                        onPressed: onBook,
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Fact extends StatelessWidget {
  const _Fact({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: c.onSurfaceVariant),
        DsGaps.hXxxs,
        Text(label, style: context.dsText.caption.tint(c.onSurfaceVariant)),
      ],
    );
  }
}
