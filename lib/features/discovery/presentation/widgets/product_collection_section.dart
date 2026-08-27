import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/design_system/design_system.dart';
import '../../../../core/router/route_paths.dart';
import 'product_card_compact.dart';
import '../providers/collection_notifier.dart';
import '../providers/collection_state.dart';
import '../../../../core/localization/l10n_extension.dart';

/// Reusable horizontal collection rail with independent loading/error state.
/// Drop one per home/category/profile section, each backed by its own provider.
class ProductCollectionSection extends ConsumerWidget {
  const ProductCollectionSection({
    super.key,
    required this.provider,
    required this.title,
    this.onSeeAll,
  });

  final StateNotifierProvider<CollectionNotifier, CollectionState> provider;
  final String title;
  final VoidCallback? onSeeAll;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(provider);
    final colors = context.dsColors;

    // Silently hide a section that legitimately has no products.
    if (state.isEmpty && state.error == null) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            DsSpacing.lg,
            DsSpacing.md,
            DsSpacing.lg,
            DsSpacing.sm,
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontFamily: DsTypography.fontFamily,
                    fontWeight: DsTypography.bold,
                    fontSize: DsTypography.titleMedium,
                    color: colors.onSurface,
                  ),
                ),
              ),
              if (onSeeAll != null)
                GestureDetector(
                  onTap: onSeeAll,
                  child: Text(
                    context.l10n.viewAll,
                    style: TextStyle(
                      color: colors.primary,
                      fontWeight: DsTypography.semiBold,
                    ),
                  ),
                ),
            ],
          ),
        ),
        SizedBox(
          height: 220,
          child: state.isLoading && state.items.isEmpty
              ? const Center(child: CircularProgressIndicator())
              : state.hasError
                  ? Center(
                      child: TextButton(
                        onPressed: () => ref.read(provider.notifier).refresh(),
                        child: Text(context.l10n.retry),
                      ),
                    )
                  : ListView.separated(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(
                        horizontal: DsSpacing.lg,
                      ),
                      itemCount: state.items.length,
                      separatorBuilder: (_, __) =>
                          const SizedBox(width: DsSpacing.md),
                      itemBuilder: (_, i) {
                        final product = state.items[i];
                        return SizedBox(
                          width: 150,
                          child: ProductCardCompact(
                            product: product,
                            onTap: () => context.push(
                              '${RoutePaths.productDetails}?id=${product.id}',
                            ),
                          ),
                        );
                      },
                    ),
        ),
      ],
    );
  }
}
