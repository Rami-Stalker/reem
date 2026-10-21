import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:reem/core/design_system/design_system.dart';
import 'package:reem/core/platform/app_haptics.dart';
import 'package:reem/core/router/route_paths.dart';
import 'package:reem/features/salons/domain/entities/salon.dart';
import 'package:reem/features/salons/presentation/providers/salons_providers.dart';
import 'package:reem/features/salons/presentation/widgets/salon_card.dart';
import 'package:reem/features/salons/presentation/widgets/salon_filters_sheet.dart';
import 'package:reem/features/salons/presentation/widgets/salon_labels.dart';

/// «الصالونات والجمال» — the directory.
///
/// Open to a guest, exactly as the catalogue is. A woman looking for somewhere
/// to have her hair done is comparing salons before she has any reason to make
/// an account, and a directory behind a sign-in wall is a directory nobody
/// browses. Signing in is asked for at the moment she books, which is the
/// moment it starts to mean something.
class SalonsScreen extends ConsumerStatefulWidget {
  const SalonsScreen({super.key});

  @override
  ConsumerState<SalonsScreen> createState() => _SalonsScreenState();
}

class _SalonsScreenState extends ConsumerState<SalonsScreen> {
  final _scroll = ScrollController();
  final _search = TextEditingController();
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _scroll
      ..removeListener(_onScroll)
      ..dispose();
    _search.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scroll.hasClients) return;
    if (_scroll.position.pixels >= _scroll.position.maxScrollExtent - 400) {
      ref.read(salonDirectoryProvider.notifier).loadMore();
    }
  }

  /// Typing is debounced rather than sent per keystroke: the directory is a
  /// database query and she types faster than it answers.
  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      if (!mounted) return;
      ref.read(salonDirectoryProvider.notifier).search(value.trim());
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    final state = ref.watch(salonDirectoryProvider);

    return Scaffold(
      backgroundColor: c.background,
      appBar: ReemAppBar(
        title: 'الصالونات والجمال',
        actions: [
          DsIconButton(
            icon: Icons.tune_rounded,
            tooltip: 'تصفية',
            variant: DsIconButtonVariant.ghost,
            badgeCount: state.filters.activeCount,
            onPressed: _openFilters,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.read(salonDirectoryProvider.notifier).load(),
        child: CustomScrollView(
          controller: _scroll,
          slivers: [
            SliverToBoxAdapter(child: _searchField(context)),
            if (state.filters.activeCount > 0)
              SliverToBoxAdapter(child: _activeFilters(state.filters)),
            SliverToBoxAdapter(child: _categoryStrip(state.filters)),

            if (state.isLoading)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: Center(child: DsLoadingIndicator()),
              )
            else if (state.error != null)
              SliverFillRemaining(
                hasScrollBody: false,
                child: DsErrorState(
                  message: 'ما قدرنا نجيب الصالونات.',
                  onRetry: () =>
                      ref.read(salonDirectoryProvider.notifier).load(),
                ),
              )
            else if (state.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: DsEmptyState(
                  icon: Icons.content_cut_rounded,
                  title: state.filters.isEmpty
                      ? 'لسّا ما في صالونات'
                      : 'ما في صالون بهالمواصفات',
                  message: state.filters.isEmpty
                      ? 'قريباً بتلاقي هون صالونات ومزيّنات تقدري تحجزي عندهن مباشرة.'
                      : 'جرّبي توسّعي التصفية أو تغيّري المنطقة.',
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(
                  DsSpacing.lg,
                  DsSpacing.sm,
                  DsSpacing.lg,
                  DsSpacing.xxxl,
                ),
                sliver: SliverList.separated(
                  itemCount: state.salons.length + (state.isLoadingMore ? 1 : 0),
                  separatorBuilder: (_, _) =>
                      const SizedBox(height: DsSpacing.md),
                  itemBuilder: (context, index) {
                    if (index >= state.salons.length) {
                      return const Padding(
                        padding: EdgeInsets.all(DsSpacing.lg),
                        child: Center(child: DsLoadingIndicator()),
                      );
                    }
                    final salon = state.salons[index];
                    return SalonCard(
                      salon: salon,
                      onTap: () =>
                          context.push(RoutePaths.salonOf(salon.id)),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _searchField(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        DsSpacing.lg,
        DsSpacing.sm,
        DsSpacing.lg,
        DsSpacing.xs,
      ),
      child: DsInputField(
        controller: _search,
        hint: 'ابحثي عن صالون أو خدمة',
        prefixIcon: const Icon(Icons.search_rounded),
        textInputAction: TextInputAction.search,
        onChanged: _onSearchChanged,
      ),
    );
  }

  /// The categories as a strip, because it is the filter she reaches for most
  /// and burying it in a sheet costs two taps on every visit.
  Widget _categoryStrip(SalonFilters filters) {
    final categories = ref.watch(salonCategoriesProvider);
    return categories.maybeWhen(
      data: (counts) {
        final offered = counts.where((c) => c.servicesCount > 0).toList();
        if (offered.isEmpty) return const SizedBox.shrink();
        return SizedBox(
          height: 44,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: DsSpacing.lg),
            itemCount: offered.length + 1,
            separatorBuilder: (_, _) => const SizedBox(width: DsSpacing.xs),
            itemBuilder: (context, index) {
              if (index == 0) {
                return DsChip(
                  label: 'الكل',
                  selected: filters.category == null,
                  onTap: () => _setCategory(null),
                );
              }
              final entry = offered[index - 1];
              return DsChip(
                label: SalonLabels.category(entry.category),
                selected: filters.category == entry.category,
                onTap: () => _setCategory(entry.category),
              );
            },
          ),
        );
      },
      orElse: () => const SizedBox.shrink(),
    );
  }

  Widget _activeFilters(SalonFilters filters) {
    final chips = <Widget>[
      if (filters.city != null || filters.governorate != null)
        _removable(filters.city ?? filters.governorate!, () {
          _apply(filters.copyWith(clearArea: true));
        }),
      if (filters.minRating != null)
        _removable('${filters.minRating!.toStringAsFixed(1)} ★ فأعلى', () {
          _apply(filters.copyWith(clearRating: true));
        }),
      if (filters.homeServiceOnly)
        _removable('خدمة منزلية', () {
          _apply(filters.copyWith(homeServiceOnly: false));
        }),
      if (filters.minPrice != null || filters.maxPrice != null)
        _removable('حسب السعر', () {
          _apply(filters.copyWith(clearPrice: true));
        }),
    ];
    if (chips.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        DsSpacing.lg,
        DsSpacing.xxs,
        DsSpacing.lg,
        DsSpacing.xs,
      ),
      child: Wrap(spacing: DsSpacing.xs, runSpacing: DsSpacing.xxs, children: chips),
    );
  }

  Widget _removable(String label, VoidCallback onRemove) =>
      DsChip(label: label, selected: true, onDeleted: onRemove);

  void _setCategory(SalonCategory? category) {
    AppHaptics.selection();
    final filters = ref.read(salonDirectoryProvider).filters;
    _apply(
      category == null
          ? filters.copyWith(clearCategory: true)
          : filters.copyWith(category: category),
    );
  }

  void _apply(SalonFilters filters) {
    unawaited(ref.read(salonDirectoryProvider.notifier).applyFilters(filters));
  }

  Future<void> _openFilters() async {
    final current = ref.read(salonDirectoryProvider).filters;
    final next = await showSalonFiltersSheet(context, ref, current);
    if (next != null) _apply(next);
  }
}
