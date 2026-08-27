import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:go_router/go_router.dart';

import 'package:reem/core/design_system/design_system.dart';
import 'package:reem/core/router/route_paths.dart';
import 'package:reem/core/shared/entities/post.dart'
    show CategoryType, CategoryTypeX;
import 'package:reem/core/shared/entities/product.dart';
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

  static const _fallbackTrending = [
    'Summer dresses',
    'Rose perfume',
    'Gift sets',
    'Heels',
    'Handbags',
    'Skincare',
    'Birthday flowers',
    'Bridal',
  ];

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

    final trending = ref
        .watch(trendingSearchesProvider)
        .maybeWhen(
          data: (items) => items.isEmpty ? _fallbackTrending : items,
          orElse: () => _fallbackTrending,
        );

    return Scaffold(
      backgroundColor: CustomerExperience.pearl,
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
                          color: Colors.white.withValues(alpha: .78),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white),
                        ),
                        child: IconButton(
                          tooltip: 'Back',
                          icon: const Icon(
                            Icons.arrow_back_ios_new_rounded,
                            color: CustomerExperience.plum,
                            size: 18,
                          ),
                          onPressed: () => context.pop(),
                        ),
                      ),
                      const SizedBox(width: DsSpacing.xs),
                      Expanded(
                        child: _SearchInput(
                          controller: _controller,
                          hint: 'Search dresses, perfume, gifts…',
                          autofocus: true,
                          onChanged: _onChanged,
                          onSubmitted: _commit,
                          onClear: () => setState(() => _query = ''),
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
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: TextField(
        controller: controller,
        autofocus: autofocus,
        onChanged: onChanged,
        onSubmitted: onSubmitted,
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          hintText: 'Search dresses, perfume, gifts...',
          border: InputBorder.none,
          icon: const Icon(
            Icons.search_rounded,
            color: CustomerExperience.rose,
          ),
          suffixIcon: controller.text.isEmpty
              ? null
              : IconButton(
                  tooltip: 'Clear search',
                  onPressed: onClear,
                  icon: const Icon(
                    Icons.close_rounded,
                    color: CustomerExperience.muted,
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
            title: 'Recent',
            action: 'Clear',
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
        const _Header(title: 'Trending now', eyebrow: 'Popular'),
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
        const _Header(title: 'Browse categories', eyebrow: 'Discover'),
        const SizedBox(height: DsSpacing.sm),
        Wrap(
          spacing: DsSpacing.xs,
          runSpacing: DsSpacing.xs,
          children: [
            for (final category in CategoryType.values)
              DsChip(
                label: category.label,
                onTap: () => onSelect(category.label),
              ),
          ],
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
      onTap: () =>
          context.push('${RoutePaths.productDetails}?id=${product.id}'),
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
    final theme = Theme.of(context);
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
                  style: const TextStyle(
                    color: CustomerExperience.rose,
                    fontSize: DsTypography.labelSmall,
                    fontWeight: DsTypography.bold,
                  ),
                ),
                const SizedBox(height: DsSpacing.xxs),
              ],
              Text(
                title,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: DsTypography.bold,
                  color: CustomerExperience.ink,
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
              style: theme.textTheme.labelLarge?.copyWith(
                color: CustomerExperience.rose,
                fontWeight: DsTypography.semiBold,
              ),
            ),
          ),
      ],
    );
  }
}
