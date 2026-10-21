import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:reem/core/design_system/design_system.dart';
import 'package:reem/features/salons/domain/entities/salon.dart';
import 'package:reem/features/salons/presentation/providers/salons_providers.dart';
import 'package:reem/features/salons/presentation/widgets/salon_labels.dart';

/// «البحث والتصفية حسب المنطقة، نوع الخدمة، السعر والتقييم».
///
/// Returns the chosen filters, or null when she backs out — so a dismissed
/// sheet changes nothing, which is what a dismissed sheet should do.
Future<SalonFilters?> showSalonFiltersSheet(
  BuildContext context,
  WidgetRef ref,
  SalonFilters current,
) {
  return DsBottomSheet.show<SalonFilters>(
    context,
    builder: (_) => _SalonFiltersSheet(initial: current),
  );
}

class _SalonFiltersSheet extends ConsumerStatefulWidget {
  const _SalonFiltersSheet({required this.initial});

  final SalonFilters initial;

  @override
  ConsumerState<_SalonFiltersSheet> createState() => _SalonFiltersSheetState();
}

class _SalonFiltersSheetState extends ConsumerState<_SalonFiltersSheet> {
  late SalonFilters _draft = widget.initial;

  /// The price bands, in SYP. Fixed bands rather than a slider: a slider needs
  /// a known maximum, and a young directory's most expensive service is not a
  /// number anybody should be shown as "the top of the market".
  static const _bands = <({String label, double? min, double? max})>[
    (label: 'أي سعر', min: null, max: null),
    (label: 'حتى ٥٠٬٠٠٠', min: null, max: 50000),
    (label: '٥٠٬٠٠٠ – ١٥٠٬٠٠٠', min: 50000, max: 150000),
    (label: '١٥٠٬٠٠٠ – ٣٠٠٬٠٠٠', min: 150000, max: 300000),
    (label: 'أكثر من ٣٠٠٬٠٠٠', min: 300000, max: null),
  ];

  static const _ratings = <double?>[null, 3, 4, 4.5];

  @override
  Widget build(BuildContext context) {
    final areas = ref.watch(salonAreasProvider);
    final categories = ref.watch(salonCategoriesProvider);

    return DsSheetScaffold(
      title: 'تصفية الصالونات',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          _section('الخدمة'),
          categories.maybeWhen(
            data: (counts) => _wrap([
              _chip('الكل', _draft.category == null, () {
                setState(() => _draft = _draft.copyWith(clearCategory: true));
              }),
              // Only what the directory can actually answer. Offering a filter
              // that returns nothing is offering a dead end.
              for (final entry in counts.where((c) => c.servicesCount > 0))
                _chip(
                  SalonLabels.category(entry.category),
                  _draft.category == entry.category,
                  () => setState(
                    () => _draft = _draft.copyWith(category: entry.category),
                  ),
                  count: entry.servicesCount,
                ),
            ]),
            orElse: () => const _Loading(),
          ),

          _section('المنطقة'),
          areas.maybeWhen(
            data: (list) => _wrap([
              _chip('كل المناطق', _draft.city == null, () {
                setState(() => _draft = _draft.copyWith(clearArea: true));
              }),
              for (final area in list)
                _chip(
                  area.city,
                  _draft.city == area.city,
                  () => setState(
                    () => _draft = _draft.copyWith(
                      city: area.city,
                      governorate: area.governorate,
                    ),
                  ),
                  count: area.salonsCount,
                ),
            ]),
            orElse: () => const _Loading(),
          ),

          _section('السعر'),
          _wrap([
            for (final band in _bands)
              _chip(
                band.label,
                _draft.minPrice == band.min && _draft.maxPrice == band.max,
                () => setState(
                  () => _draft = band.min == null && band.max == null
                      ? _draft.copyWith(clearPrice: true)
                      : _draft.copyWith(minPrice: band.min, maxPrice: band.max),
                ),
              ),
          ]),

          _section('التقييم'),
          _wrap([
            for (final rating in _ratings)
              _chip(
                rating == null ? 'أي تقييم' : '${rating.toStringAsFixed(1)} ★ فأعلى',
                _draft.minRating == rating,
                () => setState(
                  () => _draft = rating == null
                      ? _draft.copyWith(clearRating: true)
                      : _draft.copyWith(minRating: rating),
                ),
              ),
          ]),

          DsGaps.vMd,
          _HomeServiceToggle(
            value: _draft.homeServiceOnly,
            onChanged: (value) => setState(
              () => _draft = _draft.copyWith(homeServiceOnly: value),
            ),
          ),

          DsGaps.vLg,
          Row(
            children: [
              Expanded(
                child: DsButton(
                  label: 'مسح الكل',
                  variant: DsButtonVariant.tonal,
                  onPressed: () =>
                      Navigator.of(context).pop(const SalonFilters()),
                ),
              ),
              const SizedBox(width: DsSpacing.sm),
              Expanded(
                flex: 2,
                child: DsButton(
                  label: 'اعرضي النتائج',
                  onPressed: () => Navigator.of(context).pop(_draft),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _section(String title) => Padding(
    padding: const EdgeInsets.only(top: DsSpacing.md, bottom: DsSpacing.xs),
    child: Text(
      title,
      style: context.dsText.labelLarge.semibold.tint(context.dsColors.onSurface),
    ),
  );

  Widget _wrap(List<Widget> children) =>
      Wrap(spacing: DsSpacing.xs, runSpacing: DsSpacing.xs, children: children);

  Widget _chip(String label, bool selected, VoidCallback onTap, {int? count}) =>
      DsChip(label: label, selected: selected, count: count, onTap: onTap);
}

class _Loading extends StatelessWidget {
  const _Loading();

  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.symmetric(vertical: DsSpacing.sm),
    child: DsLoadingIndicator(),
  );
}

/// «الخدمات المنزلية فقط».
///
/// Its own row rather than another chip: it is not one value among several but
/// a different question, and for a woman with a small child it is the filter
/// that decides the whole search.
class _HomeServiceToggle extends StatelessWidget {
  const _HomeServiceToggle({required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'الخدمات المنزلية فقط',
                style: context.dsText.tileTitle.semibold.tint(c.onSurface),
              ),
              const SizedBox(height: DsSpacing.xxs),
              Text(
                'صالونات بتجي لعندكِ عالبيت',
                style: context.dsText.cardSubtitle.tint(c.onSurfaceVariant),
              ),
            ],
          ),
        ),
        const SizedBox(width: DsSpacing.sm),
        Switch(
          value: value,
          onChanged: onChanged,
          activeThumbColor: c.onPrimary,
          activeTrackColor: c.primary,
          inactiveThumbColor: c.surface,
          inactiveTrackColor: c.surfaceVariant,
          trackOutlineColor: WidgetStatePropertyAll(c.border),
        ),
      ],
    );
  }
}
