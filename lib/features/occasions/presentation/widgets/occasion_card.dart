import 'package:flutter/material.dart';

import 'package:reem/core/design_system/design_system.dart';
import 'package:reem/core/localization/l10n_extension.dart';
import 'package:reem/features/occasions/domain/entities/occasion.dart';
import 'package:reem/features/occasions/presentation/widgets/occasion_labels.dart';

/// One occasion, on her calendar.
///
/// The countdown is the first thing read, because it is the question she
/// opened the page with. Under it, how ready she is and the one thing to do
/// next — never the whole checklist, which is the detail page's job.
class OccasionCard extends StatelessWidget {
  const OccasionCard({super.key, required this.occasion, this.onTap});

  final Occasion occasion;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    final l10n = context.l10n;

    return SurfaceCard(
      onTap: onTap,
      semanticLabel: occasion.title,
      padding: const EdgeInsets.all(DsSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              OccasionKindMark(kind: occasion.kind, muted: occasion.isPast),
              DsGaps.hSm,
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      occasion.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.dsText.tileTitle.semibold.tint(
                        c.onSurface,
                      ),
                    ),
                    DsGaps.vXxxs,
                    Text(
                      OccasionLabels.when(l10n, occasion),
                      style: context.dsText.caption.tint(c.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              DsGaps.hXs,
              DsBadge(
                label: OccasionLabels.countdown(l10n, occasion.daysLeft),
                tone: OccasionLabels.countdownTone(occasion),
              ),
            ],
          ),
          if (!occasion.isPast && occasion.totalCount > 0) ...[
            DsGaps.vSm,
            DsMeter(
              value: occasion.progress,
              color: occasion.isReady ? c.success : c.primary,
              semanticLabel: l10n.occasionProgress(
                occasion.doneCount,
                occasion.totalCount,
              ),
            ),
            DsGaps.vXs,
            Row(
              children: [
                Expanded(
                  child: Text(
                    OccasionLabels.nextUp(l10n, occasion),
                    style: context.dsText.caption.tint(
                      occasion.isReady ? c.success : c.onSurface,
                    ),
                  ),
                ),
                Text(
                  l10n.occasionProgress(
                    occasion.doneCount,
                    occasion.totalCount,
                  ),
                  style: context.dsText.micro.tint(c.onSurfaceVariant),
                ),
              ],
            ),
          ],
          if (occasion.isPast && occasion.look != null) ...[
            DsGaps.vXs,
            Row(
              children: [
                Icon(
                  Icons.checkroom_rounded,
                  size: 14,
                  color: c.onSurfaceVariant,
                ),
                DsGaps.hXxs,
                Expanded(
                  child: Text(
                    l10n.occasionWore(occasion.look!.title),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.dsText.caption.tint(c.onSurfaceVariant),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// The kind of day, as a round mark.
class OccasionKindMark extends StatelessWidget {
  const OccasionKindMark({
    super.key,
    required this.kind,
    this.muted = false,
    this.large = false,
  });

  final OccasionKind kind;
  final bool muted;
  final bool large;

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    final size = large ? DsSizes.avatarLg : DsSizes.avatarMd;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: muted ? c.surfaceVariant : c.primaryContainer,
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Icon(
        OccasionLabels.icon(kind),
        size: large ? DsSizes.iconLg : DsSizes.iconMd,
        color: muted ? c.onSurfaceVariant : c.onPrimaryContainer,
      ),
    );
  }
}
