import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/design_system/design_system.dart';
import '../../../../core/router/route_paths.dart';
import '../../domain/entities/managed_product.dart';
import '../../domain/entities/product_status.dart';
import '../providers/seller_products_providers.dart';
import '../widgets/managed_product_card.dart';
import '../../../../core/localization/l10n_extension.dart';

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

    final palette = context.atelier;
    final l10n = context.l10n;

    return ReemScrollPage(
      background: const SellerAtelierBackground(),
      backgroundColor: palette.background,
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'new-product',
        onPressed: () => context.push(RoutePaths.productForm),
        backgroundColor: palette.primary,
        foregroundColor: palette.onPrimary,
        icon: const Icon(Icons.add),
        label: Text(l10n.sellerNewProduct),
      ),
      slivers: [
        PremiumAppBar(title: l10n.myProducts, showBack: true),
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
            title: Text(context.l10n.sellerDeleteProduct),
            content: Text(
              context.l10n.sellerDeleteProductBody(product.title),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text(context.l10n.cancel),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: Text(context.l10n.delete),
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
          _chip(context, context.l10n.all, selected == null, () => onSelect(null)),
          for (final s in ProductStatus.values)
            Padding(
              padding: const EdgeInsetsDirectional.only(start: DsSpacing.sm),
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
    final palette = context.atelier;
    return ChoiceChip(
      label: Text(label),
      selected: active,
      onSelected: (_) => onTap(),
      selectedColor: palette.primarySoft,
      backgroundColor: palette.surface,
      side: BorderSide(color: active ? palette.primary : palette.line),
      labelStyle: TextStyle(
        fontFamily: DsTypography.fontFamily,
        color: active ? palette.primary : palette.ink,
        fontWeight: active ? DsTypography.bold : DsTypography.medium,
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final palette = context.atelier;
    final l10n = context.l10n;
    return Padding(
      padding: const EdgeInsets.all(DsSpacing.xl),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 78,
            height: 78,
            decoration: BoxDecoration(
              color: palette.primarySoft,
              borderRadius: DsRadius.borderXl,
              border: Border.all(color: palette.line),
            ),
            child: Icon(
              Icons.inventory_2_outlined,
              size: 36,
              color: palette.primary,
            ),
          ),
          const SizedBox(height: DsSpacing.md),
          Text(
            l10n.sellerNoProductsYet,
            style: TextStyle(
              fontFamily: DsTypography.fontFamily,
              fontWeight: DsTypography.bold,
              fontSize: DsTypography.titleMedium,
              color: palette.ink,
            ),
          ),
          const SizedBox(height: DsSpacing.xs),
          Text(
            l10n.sellerNoProductsBlurb,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: DsTypography.fontFamily,
              color: palette.muted,
            ),
          ),
        ],
      ),
    );
  }
}
