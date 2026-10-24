import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:ohara/core/design_system/design_system.dart';
import 'package:ohara/core/localization/l10n_extension.dart';
import 'package:ohara/features/salons/domain/entities/salon.dart';
import 'package:ohara/features/salons/presentation/providers/salons_providers.dart';
import 'package:ohara/features/salons/presentation/widgets/salon_labels.dart';

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
  static const _bands = <({double? min, double? max})>[
    (min: null, max: null),
    (min: null, max: 50000),
    (min: 50000, max: 150000),
    (min: 150000, max: 300000),
    (min: 300000, max: null),
  ];

  /// A band's chip text, from its bounds, in the reader's language.
  String _bandLabel(({double? min, double? max}) band) {
    final l10n = context.l10n;
    final amount = NumberFormat.decimalPattern('en');
    final min = band.min;
    final max = band.max;
    if (min == null && max == null) return l10n.salonAnyPrice;
    if (min == null) return l10n.salonPriceUpTo(amount.format(max));
    if (max == null) return l10n.salonPriceOver(amount.format(min));
    return l10n.salonPriceRange(amount.format(min), amount.format(max));
  }

  static const _ratings = <double?>[null, 3, 4, 4.5];

  @override
  Widget build(BuildContext context) {
    final areas = ref.watch(salonAreasProvider);
    final categories = ref.watch(salonCategoriesProvider);

    return DsSheetScaffold(
      title: context.l10n.salonsFilterTitle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          _section(context.l10n.salonService),
          categories.maybeWhen(
            data: (counts) => _wrap([
              _chip(context.l10n.salonAll, _draft.category == null, () {
                setState(() => _draft = _draft.copyWith(clearCategory: true));
              }),
              // Only what the directory can actually answer. Offering a filter
              // that returns nothing is offering a dead end.
              for (final entry in counts.where((c) => c.servicesCount > 0))
                _chip(
                  SalonLabels.category(context.l10n, entry.category),
                  _draft.category == entry.category,
                  () => setState(
                    () => _draft = _draft.copyWith(category: entry.category),
                  ),
                  count: entry.servicesCount,
                ),
            ]),
            orElse: () => const _Loading(),
          ),

          _section(context.l10n.salonEditorArea),
          areas.maybeWhen(
            data: (list) => _wrap([
              _chip(context.l10n.salonAllAreas, _draft.city == null, () {
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

          _section(context.l10n.salonPrice),
          _wrap([
            for (final band in _bands)
              _chip(
                _bandLabel(band),
                _draft.minPrice == band.min && _draft.maxPrice == band.max,
                () => setState(
                  () => _draft = band.min == null && band.max == null
                      ? _draft.copyWith(clearPrice: true)
                      : _draft.copyWith(minPrice: band.min, maxPrice: band.max),
                ),
              ),
          ]),

          _section(context.l10n.salonRating),
          _wrap([
            for (final rating in _ratings)
              _chip(
                rating == null
                    ? context.l10n.salonAnyRating
                    : context.l10n.salonRatingAtLeast(
                        rating.toStringAsFixed(1),
                      ),
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
                  label: context.l10n.salonClearAll,
                  variant: DsButtonVariant.tonal,
                  onPressed: () =>
                      Navigator.of(context).pop(const SalonFilters()),
                ),
              ),
              const SizedBox(width: DsSpacing.sm),
              Expanded(
                flex: 2,
                child: DsButton(
                  label: context.l10n.salonShowResults,
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
      style: context.dsText.labelLarge.semibold.tint(
        context.dsColors.onSurface,
      ),
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
                context.l10n.salonHomeOnly,
                style: context.dsText.tileTitle.semibold.tint(c.onSurface),
              ),
              const SizedBox(height: DsSpacing.xxs),
              Text(
                context.l10n.salonHomeOnlyHint,
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
