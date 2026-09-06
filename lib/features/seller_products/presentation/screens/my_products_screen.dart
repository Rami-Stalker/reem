import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:reem/core/design_system/design_system.dart';
import 'package:reem/core/localization/l10n_extension.dart';
import 'package:reem/core/router/route_paths.dart';
import 'package:reem/features/seller_products/domain/entities/managed_product.dart';
import 'package:reem/features/seller_products/domain/entities/product_status.dart';
import 'package:reem/features/seller_products/presentation/providers/seller_products_providers.dart';
import 'package:reem/features/seller_products/presentation/widgets/managed_product_card.dart';

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
        // l10n-ignore: a record id, matched server-side
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
              separatorBuilder: (_, _) => const SizedBox(height: DsSpacing.md),
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
    final l10n = context.l10n;

    switch (action) {
      case ProductCardAction.edit:
        await context.push(RoutePaths.productForm, extra: product);
      case ProductCardAction.publish:
        await notifier.changeStatus(product.id, ProductStatus.active);
      case ProductCardAction.pause:
        await notifier.changeStatus(product.id, ProductStatus.paused);
      case ProductCardAction.draft:
        await notifier.changeStatus(product.id, ProductStatus.draft);

      case ProductCardAction.restock:
        final delta = await _askForStockDelta(context, product);
        if (delta == null) return;
        if (await notifier.adjustStock(product.id, delta) && context.mounted) {
          DsSnackbar.show(
            context,
            message: l10n.productStockUpdated,
            type: DsSnackbarType.success,
          );
        }

      case ProductCardAction.remove:
        final confirmed = await DsBottomSheet.show<bool>(
          context,
          builder: (sheetContext) => DsSheetScaffold(
            title: l10n.productArchiveQuestion(product.title),
            subtitle: l10n.productArchiveBlurb,
            child: Column(
              children: [
                DsButton(
                  label: l10n.productArchive,
                  variant: DsButtonVariant.danger,
                  icon: Icons.remove_shopping_cart_outlined,
                  onPressed: () => Navigator.of(sheetContext).pop(true),
                ),
                const SizedBox(height: DsSpacing.sm),
                DsButton(
                  label: l10n.cancel,
                  variant: DsButtonVariant.ghost,
                  onPressed: () => Navigator.of(sheetContext).pop(false),
                ),
              ],
            ),
          ),
        );
        if (confirmed != true) return;
        if (await notifier.archive(product.id) && context.mounted) {
          DsSnackbar.show(
            context,
            message: l10n.productArchived,
            type: DsSnackbarType.success,
          );
        }
    }
  }

  /// Asks for a change in stock, not a new total.
  ///
  /// `POST /seller/offers/:id/stock` takes a signed delta so two restocks
  /// arriving at once add up instead of one overwriting the other — and
  /// because a woman unpacking a delivery counts what she put on the shelf,
  /// not what is now on it.
  Future<int?> _askForStockDelta(
    BuildContext context,
    ManagedProduct product,
  ) async {
    final controller = TextEditingController();
    final l10n = context.l10n;

    final delta = await DsBottomSheet.show<int>(
      context,
      builder: (sheetContext) => DsSheetScaffold(
        title: l10n.productRestock,
        subtitle: '${product.title} · ${l10n.sellerStock('${product.stock}')}',
        child: StatefulBuilder(
          builder: (innerContext, setSheetState) {
            final typed = int.tryParse(controller.text.trim()) ?? 0;
            return Column(
              children: [
                DsInputField(
                  controller: controller,
                  label: l10n.productRestockAmount,
                  keyboardType: const TextInputType.numberWithOptions(
                    signed: true,
                  ),
                  autofocus: true,
                  onChanged: (_) => setSheetState(() {}),
                ),
                const SizedBox(height: DsSpacing.sm),
                Text(
                  l10n.sellerStock('${product.stock + typed}'),
                  style: context.dsText.bodySmall.tint(product.stock + typed < 0
                        ? context.atelier.critical
                        : context.atelier.muted),
                ),
                const SizedBox(height: DsSpacing.md),
                DsButton(
                  label: l10n.saveChanges,
                  onPressed: typed == 0 || product.stock + typed < 0
                      ? null
                      : () => Navigator.of(sheetContext).pop(typed),
                ),
              ],
            );
          },
        ),
      ),
    );

    controller.dispose();
    return delta;
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
      labelStyle: active
                ? context.dsText.tab.bold.tint(palette.primary)
                : context.dsText.tab.medium.tint(palette.ink),
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
            style: context.dsText.cardTitle.bold.tint(palette.ink),
          ),
          const SizedBox(height: DsSpacing.xs),
          Text(
            l10n.sellerNoProductsBlurb,
            textAlign: TextAlign.center,
            style: context.dsText.body.tint(palette.muted),
          ),
        ],
      ),
    );
  }
}
