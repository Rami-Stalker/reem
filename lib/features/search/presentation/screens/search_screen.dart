import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/design_system/design_system.dart';
import '../../../../core/router/route_paths.dart';
import '../../../../core/shared/entities/post.dart';
import '../../../../core/shared/entities/product.dart';
import '../providers/search_providers.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _controller = TextEditingController();
  Timer? _debounce;
  String _query = '';

  static const _trending = [
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
    final c = context.dsColors;
    return Scaffold(
      backgroundColor: c.background,
      body: Stack(
        children: [
          const FeminineMeshBackground(),
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                      DsSpacing.md, DsSpacing.sm, DsSpacing.lg, DsSpacing.sm),
                  child: Row(
                    children: [
                      DsIconButton(
                        icon: Icons.arrow_back_ios_new_rounded,
                        variant: DsIconButtonVariant.ghost,
                        iconSize: 20,
                        onPressed: () => context.pop(),
                      ),
                      const SizedBox(width: DsSpacing.xs),
                      Expanded(
                        child: DsSearchBar(
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
                      ? _IdleView(
                          trending: _trending,
                          onSelect: _select,
                        )
                      : _ResultsView(query: _query),
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

class _IdleView extends ConsumerWidget {
  const _IdleView({required this.trending, required this.onSelect});

  final List<String> trending;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recents = ref.watch(recentSearchesProvider);
    return ListView(
      padding: const EdgeInsets.fromLTRB(
          DsSpacing.lg, DsSpacing.sm, DsSpacing.lg, DsSpacing.huge),
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
  const _ResultsView({required this.query});

  final String query;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(searchResultsProvider(query));

    if (state.isLoading) {
      return GridView.builder(
        padding: const EdgeInsets.all(DsSpacing.lg),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: DsSpacing.md,
          crossAxisSpacing: DsSpacing.md,
          childAspectRatio: 0.62,
        ),
        itemCount: 6,
        itemBuilder: (_, _) => const DsProductCardSkeleton(),
      );
    }

    if (state.hasError) {
      return DsErrorState(
        message: state.error,
        onRetry: () =>
            ref.read(searchResultsProvider(query).notifier).refresh(),
      );
    }

    if (state.isEmpty) {
      return DsEmptyState.search(
        message: 'We couldn\'t find anything for “$query”.\nTry another search.',
      );
    }

    return NotificationListener<ScrollNotification>(
      onNotification: (n) {
        if (n.metrics.pixels >= n.metrics.maxScrollExtent - 400) {
          ref.read(searchResultsProvider(query).notifier).loadMore();
        }
        return false;
      },
      child: MasonryGridView.count(
        padding: const EdgeInsets.fromLTRB(
            DsSpacing.lg, DsSpacing.xs, DsSpacing.lg, DsSpacing.huge),
        crossAxisCount: 2,
        mainAxisSpacing: DsSpacing.md,
        crossAxisSpacing: DsSpacing.md,
        itemCount: state.items.length,
        itemBuilder: (context, index) =>
            _ResultCard(product: state.items[index]),
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
      price: '\$${product.price.toStringAsFixed(0)}',
      imageUrl: product.coverUrl,
      compareAtPrice: product.hasDiscount
          ? '\$${product.oldPrice!.toStringAsFixed(0)}'
          : null,
      discountPercent: product.hasDiscount ? product.discountPercent : null,
      sellerName: product.seller.name,
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
    final c = context.dsColors;
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (eyebrow != null) ...[
                Text(eyebrow!.toUpperCase(),
                    style: DsTypography.overline(c.primary)),
                const SizedBox(height: DsSpacing.xxs),
              ],
              Text(title,
                  style: theme.textTheme.titleLarge
                      ?.copyWith(fontWeight: DsTypography.bold)),
            ],
          ),
        ),
        if (action != null && onAction != null)
          GestureDetector(
            onTap: onAction,
            child: Text(action!,
                style: theme.textTheme.labelLarge?.copyWith(
                    color: c.primary, fontWeight: DsTypography.semiBold)),
          ),
      ],
    );
  }
}
