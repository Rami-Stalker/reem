import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/design_system/design_system.dart';
import '../../../../core/design_system/components/cards/surface_card.dart';
import '../../../../core/design_system/components/snackbars/app_snackbar.dart'
    show DsSnackbar, DsSnackbarType;
import '../../../../core/router/route_paths.dart';
import '../../../../core/shared/wedgets/app/premium_app_bar.dart';
import '../../domain/entities/cart.dart';
import '../providers/cart_providers.dart';

class CartScreen extends ConsumerWidget {
  const CartScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(cartNotifierProvider);
    final notifier = ref.read(cartNotifierProvider.notifier);

    ref.listen(cartNotifierProvider.select((s) => s.error), (_, error) {
      if (error != null) {
        DsSnackbar.show(context, message: error, type: DsSnackbarType.error);
      }
    });

    return ReemScrollPage(
      bottom: state.cart.isEmpty
          ? null
          : _CheckoutBar(
              cart: state.cart,
              onCheckout: () => context.push(RoutePaths.checkout),
            ),
      slivers: [
        const PremiumAppBar(title: 'My Cart', showBack: true),
        if (state.isLoading && state.cart.isEmpty)
          const SliverFillRemaining(
            hasScrollBody: false,
            child: Center(child: CircularProgressIndicator()),
          )
        else if (state.isEmpty)
          const SliverFillRemaining(hasScrollBody: false, child: _EmptyCart())
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(
              DsSpacing.lg,
              DsSpacing.sm,
              DsSpacing.lg,
              140,
            ),
            sliver: SliverList.separated(
              itemCount: state.cart.items.length,
              separatorBuilder: (_, __) => const SizedBox(height: DsSpacing.md),
              itemBuilder: (_, i) {
                final line = state.cart.items[i];
                return _CartLineTile(
                  line: line,
                  isMutating: state.mutatingItemId == line.id,
                  onIncrement: () => notifier.increment(line),
                  onDecrement: () => notifier.decrement(line),
                  onRemove: () => notifier.removeLine(line),
                );
              },
            ),
          ),
      ],
    );
  }
}

class _CartLineTile extends StatelessWidget {
  const _CartLineTile({
    required this.line,
    required this.isMutating,
    required this.onIncrement,
    required this.onDecrement,
    required this.onRemove,
  });

  final CartLine line;
  final bool isMutating;
  final VoidCallback onIncrement;
  final VoidCallback onDecrement;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final colors = context.dsColors;
    return SurfaceCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(DsRadius.md),
            child: SizedBox(
              width: 64,
              height: 64,
              child: line.image != null
                  ? Image.network(line.image!, fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) =>
                          Container(color: colors.surfaceVariant))
                  : Container(color: colors.surfaceVariant),
            ),
          ),
          const SizedBox(width: DsSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  line.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: DsTypography.fontFamily,
                    fontWeight: DsTypography.semiBold,
                    color: colors.onSurface,
                  ),
                ),
                if (line.variantName != null)
                  Text(
                    line.variantName!,
                    style: TextStyle(
                      fontSize: DsTypography.bodySmall,
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                const SizedBox(height: 4),
                Text(
                  '\$${line.lineTotal.toStringAsFixed(2)}',
                  style: TextStyle(
                    fontFamily: DsTypography.fontFamily,
                    fontWeight: DsTypography.bold,
                    color: colors.primary,
                  ),
                ),
                if (!line.inStock)
                  Text(
                    'Out of stock',
                    style: TextStyle(
                      fontSize: DsTypography.bodySmall,
                      color: colors.error,
                    ),
                  ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              IconButton(
                visualDensity: VisualDensity.compact,
                icon: Icon(Icons.delete_outline, color: colors.onSurfaceVariant),
                onPressed: isMutating ? null : onRemove,
              ),
              _QtyStepper(
                quantity: line.quantity,
                busy: isMutating,
                onIncrement: line.canIncrement ? onIncrement : null,
                onDecrement: onDecrement,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _QtyStepper extends StatelessWidget {
  const _QtyStepper({
    required this.quantity,
    required this.busy,
    this.onIncrement,
    this.onDecrement,
  });

  final int quantity;
  final bool busy;
  final VoidCallback? onIncrement;
  final VoidCallback? onDecrement;

  @override
  Widget build(BuildContext context) {
    final colors = context.dsColors;
    return Container(
      decoration: BoxDecoration(
        color: colors.surfaceVariant,
        borderRadius: BorderRadius.circular(DsRadius.full),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _btn(Icons.remove, busy ? null : onDecrement, colors),
          SizedBox(
            width: 28,
            child: Center(
              child: busy
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(
                      '$quantity',
                      style: TextStyle(
                        fontWeight: DsTypography.bold,
                        color: colors.onSurface,
                      ),
                    ),
            ),
          ),
          _btn(Icons.add, busy ? null : onIncrement, colors),
        ],
      ),
    );
  }

  Widget _btn(IconData icon, VoidCallback? onTap, DsColorScheme colors) {
    return IconButton(
      visualDensity: VisualDensity.compact,
      iconSize: 18,
      icon: Icon(icon, color: onTap == null ? colors.disabled : colors.primary),
      onPressed: onTap,
    );
  }
}

class _CheckoutBar extends StatelessWidget {
  const _CheckoutBar({required this.cart, required this.onCheckout});

  final Cart cart;
  final VoidCallback onCheckout;

  @override
  Widget build(BuildContext context) {
    final colors = context.dsColors;
    final disabled = cart.hasOutOfStock;
    return Container(
      padding: EdgeInsets.fromLTRB(
        DsSpacing.lg,
        DsSpacing.md,
        DsSpacing.lg,
        DsSpacing.md + MediaQuery.of(context).padding.bottom,
      ),
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(top: BorderSide(color: colors.border)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Subtotal',
                  style: TextStyle(
                    fontSize: DsTypography.bodySmall,
                    color: colors.onSurfaceVariant,
                  ),
                ),
                Text(
                  '\$${cart.summary.subtotal.toStringAsFixed(2)}',
                  style: TextStyle(
                    fontFamily: DsTypography.fontFamily,
                    fontSize: DsTypography.titleMedium,
                    fontWeight: DsTypography.bold,
                    color: colors.onSurface,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            width: 170,
            child: PrimaryButton(
              label: disabled ? 'Remove out-of-stock' : 'Checkout',
              onPressed: disabled ? null : onCheckout,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyCart extends StatelessWidget {
  const _EmptyCart();

  @override
  Widget build(BuildContext context) {
    final colors = context.dsColors;
    return Padding(
      padding: const EdgeInsets.all(DsSpacing.xl),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.shopping_bag_outlined, size: 56, color: colors.primary),
          const SizedBox(height: DsSpacing.md),
          Text(
            'Your cart is empty',
            style: TextStyle(
              fontFamily: DsTypography.fontFamily,
              fontWeight: DsTypography.bold,
              fontSize: DsTypography.titleMedium,
              color: colors.onSurface,
            ),
          ),
          const SizedBox(height: DsSpacing.xs),
          Text(
            'Browse the shop and add something you love.',
            textAlign: TextAlign.center,
            style: TextStyle(color: colors.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}
