import 'package:flutter/material.dart';

import 'package:ohara/core/design_system/design_system.dart';
import 'package:ohara/core/localization/l10n_extension.dart';
import 'package:ohara/features/occasions/domain/entities/occasion.dart';
import 'package:ohara/features/salons/presentation/widgets/salon_labels.dart';

/// «ما لبستيه قدّامهم» — shown when the people she named for this day have
/// already seen this outfit, or are about to at another occasion.
///
/// A question, not a verdict: wearing a favourite dress twice is her call.
/// The card says where it was seen and what was the same, and leaves it there.
class OccasionRepeatWarning extends StatelessWidget {
  const OccasionRepeatWarning({super.key, required this.occasion});

  final Occasion occasion;

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    final l10n = context.l10n;

    return SurfaceCard(
      color: c.warningContainer,
      showBorder: false,
      padding: const EdgeInsets.all(DsSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.visibility_rounded,
                size: DsSizes.iconMd,
                color: c.warning,
              ),
              DsGaps.hXs,
              Expanded(
                child: Text(
                  l10n.occasionRepeatTitle(occasion.circle ?? ''),
                  style: context.dsText.bodyStrong.tint(c.onSurface),
                ),
              ),
            ],
          ),
          DsGaps.vXs,
          for (final repeat in occasion.repeats)
            Padding(
              padding: const EdgeInsets.only(top: DsSpacing.xxs),
              child: Text(
                '${repeat.upcoming ? l10n.occasionRepeatPlanned(repeat.title) : l10n.occasionRepeatWorn(repeat.title)}'
                ' · ${SalonLabels.date(l10n, repeat.date)}\n'
                '${repeat.sameLook ? l10n.occasionRepeatSameLook : l10n.occasionRepeatSamePieces(repeat.pieces.map((piece) => piece.title).join(l10n.occasionListSeparator))}',
                style: context.dsText.caption.tint(c.onSurface),
              ),
            ),
          DsGaps.vXs,
          Text(
            l10n.occasionRepeatHint,
            style: context.dsText.caption.tint(c.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}
