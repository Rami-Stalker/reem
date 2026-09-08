import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:go_router/go_router.dart';

import 'package:reem/core/design_system/design_system.dart';
import 'package:reem/core/design_system/patterns/product_cues.dart';
import 'package:reem/core/localization/l10n_extension.dart';
import 'package:reem/core/router/route_paths.dart';
import 'package:reem/core/shared/entities/product.dart';
import 'package:reem/features/catalog/domain/entities/category_node.dart';
import 'package:reem/features/catalog/presentation/providers/categories_provider.dart';
import 'package:reem/features/search/domain/entities/search_suggestions.dart';
import 'package:reem/features/search/presentation/providers/search_providers.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _controller = TextEditingController();
  Timer? _debounce;
  String _query = '';
  bool _seededFromRoute = false;

  /// Shown when the server has no trending terms yet. A method rather than
  /// a `const` list, because these are copy and copy is localised.
  static List<String> _fallbackTrending(BuildContext context) {
    final l10n = context.l10n;
    return [
      l10n.searchTrendDresses,
      l10n.searchTrendPerfume,
      l10n.searchTrendGifts,
      l10n.searchTrendHeels,
      l10n.searchTrendBags,
      l10n.searchTrendSkincare,
      l10n.searchTrendFlowers,
      l10n.searchTrendEvening,
    ];
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      if (mounted) setState(() => _query = value.trim());
    });
  }

  void _commit(String value) {
    _debounce?.cancel();
    final term = value.trim();
    setState(() => _query = term);
    if (term.isNotEmpty) {
      ref.read(recentSearchesProvider.notifier).add(term);
    }
  }

  /// Empties the field, not just the results.
  ///
  /// The X used to clear `_query` and leave `_controller.text` alone, so the
  /// word she typed stayed sitting in the box while the page fell back to the
  /// idle view — and because the button only shows while the text is
  /// non-empty, it stayed there too, apparently doing nothing.
  void _clear() {
    _debounce?.cancel();
    _controller.clear();
    setState(() => _query = '');
  }

  void _select(String term) {
    _controller
      ..text = term
      ..selection = TextSelection.collapsed(offset: term.length);
    _commit(term);
  }

  @override
  Widget build(BuildContext context) {
    if (!_seededFromRoute) {
      final routedQuery = GoRouterState.of(context).uri.queryParameters['q'];
      if (routedQuery != null && routedQuery.trim().isNotEmpty) {
        _controller.text = routedQuery.trim();
        _query = routedQuery.trim();
      }
      _seededFromRoute = true;
    }

    final fallback = _fallbackTrending(context);
    final trending = ref.watch(trendingSearchesProvider).maybeWhen(
          data: (items) => items.isEmpty ? fallback : items,
          orElse: () => fallback,
        );

    return Scaffold(
      backgroundColor: context.boutique.surface,
      body: Stack(
        children: [
          const CustomerBackdrop(),
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    DsSpacing.md,
                    DsSpacing.sm,
                    DsSpacing.lg,
                    DsSpacing.sm,
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: DsColors.onMedia.withValues(alpha: .78),
                          shape: BoxShape.circle,
                          border: Border.all(color: DsColors.onMedia),
                        ),
                        child: IconButton(
                          tooltip: MaterialLocalizations.of(context).backButtonTooltip,
                          icon: Icon(
                            DsIcons.back,
                            color: context.dsColors.secondary,
                            size: DsSizes.iconSm,
                          ),
                          onPressed: () => context.pop(),
                        ),
                      ),
                      const SizedBox(width: DsSpacing.xs),
                      Expanded(
                        child: _SearchInput(
                          controller: _controller,
                          hint: context.l10n.searchHint,
                          autofocus: true,
                          onChanged: _onChanged,
                          onSubmitted: _commit,
                          onClear: _clear,
                        ),
                      ),
                      const SizedBox(width: DsSpacing.xs),
                      // Search by image sits beside the field, not inside it:
                      // it is a different way to start a search, not a
                      // decoration on the text one, and a woman holding a
                      // screenshot is looking for a camera rather than reading
                      // a placeholder.
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: DsColors.onMedia.withValues(alpha: .78),
                          shape: BoxShape.circle,
                          border: Border.all(color: DsColors.onMedia),
                        ),
                        child: IconButton(
                          tooltip: context.l10n.visualSearchTitle,
                          icon: Icon(
                            Icons.image_search_rounded,
                            color: context.boutique.primary,
                            size: DsSizes.iconSm,
                          ),
                          onPressed: () =>
                              context.push(RoutePaths.visualSearch),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: _query.isEmpty
                      ? _IdleView(trending: trending, onSelect: _select)
                      : _ResultsView(query: _query, onSelect: _select),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Idle: recent + trending + browse ────────────────────────────────────────

class _SearchInput extends StatelessWidget {
  const _SearchInput({
    required this.controller,
    required this.hint,
    required this.onChanged,
    required this.onSubmitted,
    required this.onClear,
    this.autofocus = false,
  });

  final TextEditingController controller;
  final String hint;
  final bool autofocus;
  final ValueChanged<String> onChanged;
  final ValueChanged<String> onSubmitted;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return CustomerPanel(
      padding: const EdgeInsets.symmetric(horizontal: DsSpacing.md),
      child: TextField(
        controller: controller,
        autofocus: autofocus,
        onChanged: onChanged,
        onSubmitted: onSubmitted,
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          hintText: context.l10n.searchHint,
          border: InputBorder.none,
          icon: Icon(DsIcons.search, color: context.boutique.primary),
          // Rebuilt from the controller rather than from the parent's state:
          // the parent only rebuilds after the 350ms debounce, so the X
          // appeared a third of a second late and — worse — lingered after the
          // field was emptied by hand.
          suffixIcon: ValueListenableBuilder<TextEditingValue>(
            valueListenable: controller,
            builder: (context, value, _) => value.text.isEmpty
                ? const SizedBox.shrink()
                : IconButton(
                    tooltip: context.l10n.searchClear,
                    onPressed: onClear,
                    icon: Icon(DsIcons.close, color: context.boutique.muted),
                  ),
          ),
        ),
      ),
    );
  }
}

class _IdleView extends ConsumerWidget {
  const _IdleView({required this.trending, required this.onSelect});

  final List<String> trending;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recents = ref.watch(recentSearchesProvider);
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        DsSpacing.lg,
        DsSpacing.sm,
        DsSpacing.lg,
        DsSpacing.huge,
      ),
      children: [
        if (recents.isNotEmpty) ...[
          _Header(
            title: context.l10n.searchRecent,
            action: context.l10n.searchClearAll,
            onAction: () => ref.read(recentSearchesProvider.notifier).clear(),
          ),
          const SizedBox(height: DsSpacing.sm),
          Wrap(
            spacing: DsSpacing.xs,
            runSpacing: DsSpacing.xs,
            children: [
              for (final term in recents)
                DsChip(
                  label: term,
                  icon: Icons.history_rounded,
                  onTap: () => onSelect(term),
                  onDeleted: () =>
                      ref.read(recentSearchesProvider.notifier).remove(term),
                ),
            ],
          ),
          const SizedBox(height: DsSpacing.sectionGap),
        ],
        _Header(
          title: context.l10n.searchTrendingNow,
          eyebrow: context.l10n.searchTrendingEyebrow,
        ),
        const SizedBox(height: DsSpacing.sm),
        Wrap(
          spacing: DsSpacing.xs,
          runSpacing: DsSpacing.xs,
          children: [
            for (final term in trending)
              DsChip(
                label: term,
                icon: Icons.trending_up_rounded,
                onTap: () => onSelect(term),
              ),
          ],
        ),
        const SizedBox(height: DsSpacing.sectionGap),
        _Header(
          title: context.l10n.searchBrowseCategories,
          eyebrow: context.l10n.searchDiscoverEyebrow,
        ),
        const SizedBox(height: DsSpacing.sm),
        // The shop's real departments, opened as departments.
        //
        // This row used to be a hardcoded English enum — Clothing, Makeup,
        // Perfumes, Bags … — and each chip ran its own label as a free-text
        // query. The catalogue is written in Arabic, so all nine matched
        // nothing: every chip here opened an empty result page. These come
        // from the category tree the shop actually has, carry its Arabic
        // names, and navigate to the department rather than searching for its
        // name.
        const _DepartmentChips(),
      ],
    );
  }
}

/// The level-one departments, from the catalogue's own tree.
class _DepartmentChips extends ConsumerWidget {
  const _DepartmentChips();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final departments = switch (ref.watch(categoryTreeProvider)) {
      AsyncData(:final value) => [
          for (final root in value)
            ...root.children.isEmpty ? [root] : root.children,
        ],
      _ => const <CategoryNode>[],
    };
    if (departments.isEmpty) return const SizedBox.shrink();

    return Wrap(
      spacing: DsSpacing.xs,
      runSpacing: DsSpacing.xs,
      children: [
        for (final department in departments)
          DsChip(
            label: department.name,
            onTap: () => context.push(
              RoutePaths.categoryOf(department.category.slug),
            ),
          ),
      ],
    );
  }
}

// ── Results ─────────────────────────────────────────────────────────────────

class _ResultsView extends ConsumerWidget {
  const _ResultsView({required this.query, required this.onSelect});

  final String query;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(searchResultsProvider(query));
    final suggestionRail = _SuggestionRail(
      suggestions: ref.watch(searchSuggestionsProvider(query)),
      onSelect: onSelect,
    );
    Widget withSuggestions(Widget child) => Column(
      children: [
        suggestionRail,
        Expanded(child: child),
      ],
    );

    if (state.isLoading) {
      return withSuggestions(
        GridView.builder(
          padding: const EdgeInsets.all(DsSpacing.lg),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: DsSpacing.md,
            crossAxisSpacing: DsSpacing.md,
            childAspectRatio: 0.62,
          ),
          itemCount: 6,
          itemBuilder: (_, _) => const DsProductCardSkeleton(),
        ),
      );
    }

    if (state.hasError) {
      return withSuggestions(
        DsErrorState(
          message: state.error,
          onRetry: () =>
              ref.read(searchResultsProvider(query).notifier).refresh(),
        ),
      );
    }

    if (state.isEmpty) {
      return withSuggestions(
        DsEmptyState.search(
          message:
              'We couldn\'t find anything for "$query".\nTry another search.',
        ),
      );
    }

    return withSuggestions(
      NotificationListener<ScrollNotification>(
        onNotification: (n) {
          if (n.metrics.pixels >= n.metrics.maxScrollExtent - 400) {
            ref.read(searchResultsProvider(query).notifier).loadMore();
          }
          return false;
        },
        child: MasonryGridView.count(
          padding: const EdgeInsets.fromLTRB(
            DsSpacing.lg,
            DsSpacing.xs,
            DsSpacing.lg,
            DsSpacing.huge,
          ),
          crossAxisCount: 2,
          mainAxisSpacing: DsSpacing.md,
          crossAxisSpacing: DsSpacing.md,
          itemCount: state.items.length,
          itemBuilder: (context, index) =>
              _ResultCard(product: state.items[index]),
        ),
      ),
    );
  }
}

class _SuggestionRail extends StatelessWidget {
  const _SuggestionRail({required this.suggestions, required this.onSelect});

  final AsyncValue<SearchSuggestions> suggestions;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    final terms = suggestions.maybeWhen(
      data: (data) => data.combined.take(8).toList(),
      orElse: () => const <String>[],
    );
    if (terms.isEmpty) return const SizedBox.shrink();

    return SizedBox(
      width: double.infinity,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          DsSpacing.lg,
          DsSpacing.xs,
          DsSpacing.lg,
          DsSpacing.sm,
        ),
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (final term in terms) ...[
              DsChip(
                label: term,
                icon: Icons.search_rounded,
                onTap: () => onSelect(term),
              ),
              const SizedBox(width: DsSpacing.xs),
            ],
          ],
        ),
      ),
    );
  }
}

class _ResultCard extends StatelessWidget {
  const _ResultCard({required this.product});

  final Product product;

  @override
  Widget build(BuildContext context) {
    return DsProductCard(
      title: product.title,
      price: product.price?.format() ?? '',
      imageUrl: product.coverUrl,
      blurHash: product.coverBlurHash,
      compareAtPrice:
          product.hasDiscount ? product.compareAtPrice?.format() : null,
      discountPercent: product.hasDiscount ? product.discountPercent : null,
      sellerName: product.displaySeller?.name ?? '',
      rating: product.rating > 0 ? product.rating : null,
      ratingCount: product.reviewsCount > 0 ? product.reviewsCount : null,
      soldOut: !product.inStock,
      cues: product.cues.asBadges,
      onTap: () =>
          context.push(RoutePaths.productDetailsOf(product.id)),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.title,
    this.eyebrow,
    this.action,
    this.onAction,
  });

  final String title;
  final String? eyebrow;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (eyebrow != null) ...[
                Text(
                  eyebrow!.toUpperCase(),
                  style: context.dsText.caption.bold.tint(context.boutique.primary),
                ),
                const SizedBox(height: DsSpacing.xxs),
              ],
              Text(
                title,
                style: context.dsText.sectionTitle.copyWith(
                  fontWeight: DsTypography.bold,
                  color: context.boutique.ink,
                ),
              ),
            ],
          ),
        ),
        if (action != null && onAction != null)
          GestureDetector(
            onTap: onAction,
            child: Text(
              action!,
              style: context.dsText.labelLarge.copyWith(
                color: context.boutique.primary,
                fontWeight: DsTypography.semiBold,
              ),
            ),
          ),
      ],
    );
  }
}
