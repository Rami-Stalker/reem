import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/design_system/design_system.dart';
import '../../../../core/design_system/components/snackbars/app_snackbar.dart'
    show DsSnackbar, DsSnackbarType;
import '../../../../core/router/route_paths.dart';
import '../../../../core/shared/wedgets/app/premium_app_bar.dart';
import '../../domain/entities/managed_product.dart';
import '../../domain/entities/product_status.dart';
import '../providers/seller_products_providers.dart';
import '../widgets/managed_product_card.dart';

class MyProductsScreen extends ConsumerWidget {
  const MyProductsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(myProductsNotifierProvider);
    final notifier = ref.read(myProductsNotifierProvider.notifier);

    ref.listen(myProductsNotifierProvider.select((s) => s.error), (_, error) {
      if (error != null) {
        DsSnackbar.show(context, message: error, type: DsSnackbarType.error);
      }
    });

    return ReemScrollPage(
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'new-product',
        onPressed: () => context.push(RoutePaths.productForm),
        icon: const Icon(Icons.add),
        label: const Text('New product'),
      ),
      slivers: [
        const PremiumAppBar(title: 'My Products', showBack: true),
        SliverToBoxAdapter(
          child: _FilterBar(
            selected: state.statusFilter,
            onSelect: notifier.setFilter,
          ),
        ),
        if (state.isLoading && state.products.isEmpty)
          const SliverFillRemaining(
            hasScrollBody: false,
            child: Center(child: CircularProgressIndicator()),
          )
        else if (state.isEmpty)
          const SliverFillRemaining(hasScrollBody: false, child: _EmptyState())
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(
              DsSpacing.lg,
              DsSpacing.sm,
              DsSpacing.lg,
              120,
            ),
            sliver: SliverList.separated(
              itemCount: state.products.length,
              separatorBuilder: (_, __) => const SizedBox(height: DsSpacing.md),
              itemBuilder: (_, i) {
                final product = state.products[i];
                return ManagedProductCard(
                  product: product,
                  isMutating: state.mutatingId == product.id,
                  onAction: (action) =>
                      _handleAction(context, ref, product, action),
                );
              },
            ),
          ),
      ],
    );
  }

  Future<void> _handleAction(
    BuildContext context,
    WidgetRef ref,
    ManagedProduct product,
    ProductCardAction action,
  ) async {
    final notifier = ref.read(myProductsNotifierProvider.notifier);
    switch (action) {
      case ProductCardAction.edit:
        context.push(RoutePaths.productForm, extra: product);
      case ProductCardAction.activate:
        notifier.changeStatus(product.id, ProductStatus.active);
      case ProductCardAction.draft:
        notifier.changeStatus(product.id, ProductStatus.draft);
      case ProductCardAction.archive:
        notifier.changeStatus(product.id, ProductStatus.archived);
      case ProductCardAction.delete:
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Delete product?'),
            content: Text('“${product.title}” will be permanently removed.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Delete'),
              ),
            ],
          ),
        );
        if (confirmed == true) notifier.delete(product.id);
    }
  }
}

class _FilterBar extends StatelessWidget {
  const _FilterBar({required this.selected, required this.onSelect});

  final ProductStatus? selected;
  final ValueChanged<ProductStatus?> onSelect;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(
        horizontal: DsSpacing.lg,
        vertical: DsSpacing.sm,
      ),
      child: Row(
        children: [
          _chip(context, 'All', selected == null, () => onSelect(null)),
          for (final s in ProductStatus.values)
            Padding(
              padding: const EdgeInsets.only(left: DsSpacing.sm),
              child: _chip(context, s.label, selected == s, () => onSelect(s)),
            ),
        ],
      ),
    );
  }

  Widget _chip(
    BuildContext context,
    String label,
    bool active,
    VoidCallback onTap,
  ) {
    final colors = context.dsColors;
    return ChoiceChip(
      label: Text(label),
      selected: active,
      onSelected: (_) => onTap(),
      selectedColor: colors.primary.withValues(alpha: 0.16),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final colors = context.dsColors;
    return Padding(
      padding: const EdgeInsets.all(DsSpacing.xl),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.inventory_2_outlined, size: 48, color: colors.primary),
          const SizedBox(height: DsSpacing.md),
          Text(
            'No products yet',
            style: TextStyle(
              fontFamily: DsTypography.fontFamily,
              fontWeight: DsTypography.bold,
              fontSize: DsTypography.titleMedium,
              color: colors.onSurface,
            ),
          ),
          const SizedBox(height: DsSpacing.xs),
          Text(
            'Tap “New product” to publish your first listing.',
            textAlign: TextAlign.center,
            style: TextStyle(color: colors.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}
