import 'package:flutter/material.dart';
import 'package:reem/core/design_system/design_system.dart';
import 'package:reem/features/visual_search/domain/entities/visual_search_session.dart';

/// The items found in one photograph, as tabs.
///
/// Only shown when the photograph was read as a look with more than one piece
/// in it. A single-garment search has exactly one region and this strip would
/// be a tab bar with one tab — noise dressed as a feature.
///
/// A region the server *guessed* at carries its confidence, visibly. That is
/// the difference between saying "here is the bag" and "this part looked like
/// a separate piece"; the second is what a band split off a full-length
/// photograph actually is, and the label says so rather than the UI implying
/// a detection nobody made.
class VisualRegionStrip extends StatelessWidget {
  const VisualRegionStrip({
    super.key,
    required this.regions,
    required this.selectedId,
    required this.onSelect,
  });

  final List<VisualRegion> regions;
  final String? selectedId;
  final void Function(String regionId) onSelect;

  @override
  Widget build(BuildContext context) {
    if (regions.length < 2) return const SizedBox.shrink();

    final colors = context.dsColors;
    final selected = selectedId ?? regions.first.id;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            DsSpacing.md,
            DsSpacing.md,
            DsSpacing.md,
            DsSpacing.xs,
          ),
          child: Text(
            'شفت أكتر من قطعة بالصورة',
            style: context.dsText.tileTitle,
          ),
        ),
        SizedBox(
          height: 44,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: DsSpacing.md),
            itemCount: regions.length,
            separatorBuilder: (_, _) => const SizedBox(width: DsSpacing.xs),
            itemBuilder: (context, index) {
              final region = regions[index];
              return DsChip(
                label: _labelFor(region),
                selected: region.id == selected,
                count: region.matches.isEmpty ? null : region.matches.length,
                onTap: () => onSelect(region.id),
              );
            },
          ),
        ),
        if (_selectedRegion(selected)?.detector.isInferred ?? false)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              DsSpacing.md,
              DsSpacing.xs,
              DsSpacing.md,
              DsSpacing.xxxs,
            ),
            child: Text(
              'هالقطعة استنتجتها من ترتيب الصورة، مو أكيدة ١٠٠٪.',
              style: Theme.of(
                context,
              ).textTheme.labelSmall?.copyWith(color: colors.onSurfaceVariant),
            ),
          ),
      ],
    );
  }

  VisualRegion? _selectedRegion(String id) {
    for (final region in regions) {
      if (region.id == id) return region;
    }
    return null;
  }

  String _labelFor(VisualRegion region) =>
      region.slotLabel?.isNotEmpty == true ? region.slotLabel! : region.label;
}
