import 'package:flutter/material.dart';
import 'package:reem/core/design_system/design_system.dart';
import 'package:reem/core/localization/l10n_extension.dart';
import 'package:reem/features/closet/domain/entities/closet_gap.dart';
import 'package:reem/l10n/app_localizations.dart';

/// One thing her wardrobe is short of.
///
/// The card shows the headline, the reason, and a way to see the arithmetic.
/// That last part is not decoration: this feature holds a list of a woman's
/// clothes and tells her what to buy, and the least it can do is let her open
/// the reasoning. A recommendation she cannot interrogate is one she has to
/// take on trust.
class ClosetGapCard extends StatelessWidget {
  const ClosetGapCard({
    super.key,
    required this.gap,
    this.onTap,
    this.onDismiss,
    this.compact = false,
  });

  final ClosetGap gap;
  final VoidCallback? onTap;
  final VoidCallback? onDismiss;

  /// The horizontal-rail form used on the closet's front page.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final colors = context.dsColors;

    return SurfaceCard(
      onTap: onTap,
      padding: const EdgeInsets.all(DsSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(_icon(), size: 18, color: colors.primary),
              const SizedBox(width: DsSpacing.xs),
              Expanded(
                child: Text(
                  gap.slotLabel,
                  style: context.dsText.labelStrong.tint(colors.primary),
                ),
              ),
              if (onDismiss != null && !compact)
                InkWell(
                  onTap: onDismiss,
                  borderRadius: BorderRadius.circular(DsRadius.pill),
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: Icon(
                      Icons.close_rounded,
                      size: 16,
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: DsSpacing.xs),
          Text(
            gap.headline,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: context.dsText.cardTitle,
          ),
          DsGaps.vXxxs,
          Text(
            gap.rationale,
            maxLines: compact ? 2 : 3,
            overflow: TextOverflow.ellipsis,
            style: context.dsText.cardSubtitle,
          ),
          if (!compact) ...[
            const SizedBox(height: DsSpacing.sm),
            Wrap(
              spacing: DsSpacing.xs,
              runSpacing: DsSpacing.xs,
              children: [
                // The constraints, shown because they are the promise: a
                // suggestion arriving against this gap will be in these colours
                // and this size, and she can see that before she taps.
                for (final colour in gap.suggestedColours.take(3))
                  DsChip(label: colour.label),
                if (gap.suggestedSize != null)
                  DsChip(
                    label: context.l10n.closetSizeValue(gap.suggestedSize!),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  IconData _icon() => switch (gap.kind) {
        ClosetGapKind.lookSlot => Icons.auto_awesome_rounded,
        ClosetGapKind.occasion => Icons.celebration_rounded,
        ClosetGapKind.coverage => Icons.grid_view_rounded,
        ClosetGapKind.season => Icons.wb_sunny_rounded,
        ClosetGapKind.replacement => Icons.autorenew_rounded,
      };
}

/// The arithmetic behind a gap, as a sheet.
///
/// Renders `components` verbatim. Deliberately unglamorous — it is a receipt,
/// not a feature — and it is the reason the engine stores its breakdown beside
/// every priority it writes.
class GapReasoningSheet extends StatelessWidget {
  const GapReasoningSheet({super.key, required this.gap});

  final ClosetGap gap;

  /// The server's component keys, in her words. A key the app does not know
  /// yet is shown as sent rather than hidden: the sheet exists so every
  /// number can be taken apart, and dropping a row would break that.
  static String _label(AppLocalizations l10n, String key) => switch (key) {
    'base' => l10n.closetReasonBase,
    'nearly_complete' => l10n.closetReasonNearlyComplete,
    'favourite_look' => l10n.closetReasonFavouriteLook,
    'core_slot' => l10n.closetReasonCoreSlot,
    'already_chosen' => l10n.closetReasonAlreadyChosen,
    'season_fit' => l10n.closetReasonSeasonFit,
    'interest' => l10n.closetReasonInterest,
    'anchor_slot' => l10n.closetReasonAnchorSlot,
    'owns_nothing' => l10n.closetReasonOwnsNone,
    'outfit_gain' => l10n.closetReasonOutfitGain,
    'owns_none' => l10n.closetReasonOwnsNone,
    'unlocks_first_outfit' => l10n.closetReasonFirstOutfit,
    'outfits_unlocked' => l10n.closetReasonOutfitsUnlocked,
    'outfits_now' => l10n.closetReasonOutfitsNow,
    'shelved' => l10n.closetReasonShelved,
    'owned_out_of_season' => l10n.closetReasonOutOfSeason,
    'wear' => l10n.closetReasonWear,
    'sole_in_slot' => l10n.closetReasonSoleInSlot,
    'wear_count' => l10n.closetReasonWearCount,
    _ => key,
  };

  @override
  Widget build(BuildContext context) {
    final colors = context.dsColors;
    final entries = gap.components.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Padding(
      padding: const EdgeInsets.all(DsSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            context.l10n.closetWhyWeSuggest,
            style: context.dsText.sectionTitle,
          ),
          const SizedBox(height: DsSpacing.xs),
          Text(gap.rationale, style: context.dsText.bodyMuted),
          const SizedBox(height: DsSpacing.md),
          for (final entry in entries)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _label(context.l10n, entry.key),
                      style: context.dsText.body,
                    ),
                  ),
                  Text(
                    _format(entry.value),
                    style: context.dsText.numeric.tint(colors.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          const Divider(height: DsSpacing.lg),
          Row(
            children: [
              Expanded(
                child: Text(
                  context.l10n.closetPriority,
                  style: context.dsText.labelStrong,
                ),
              ),
              Text(
                gap.priority.toStringAsFixed(0),
                style: context.dsText.metricSmall,
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _format(num value) =>
      value == value.roundToDouble() ? value.toInt().toString() : value.toStringAsFixed(1);
}
