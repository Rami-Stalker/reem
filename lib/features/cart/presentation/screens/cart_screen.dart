import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/design_system/design_system.dart';
import '../../../../core/router/route_paths.dart';
import '../../../auth/presentation/widgets/auth_prompt_sheet.dart';
import '../../domain/entities/cart.dart';
import '../providers/cart_providers.dart';
import '../../../../core/localization/l10n_extension.dart';

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
              onCheckout: () async {
                final ok = await requireAuthenticatedUser(
                  context,
                  ref,
                  title: context.l10n.signInToCheckout,
                  message:
                      context.l10n.guestCartSafe,
                  from: RoutePaths.checkout,
                );
                if (ok && context.mounted) context.push(RoutePaths.checkout);
              },
            ),
      slivers: [
        PremiumAppBar(title: context.l10n.myCart, showBack: true),
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
    return CustomerPanel(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: SizedBox(
              width: 78,
              height: 92,
              child: line.image != null
                  ? Image.network(
                      line.image!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) =>
                          Container(color: CustomerExperience.ivory),
                    )
                  : Container(color: CustomerExperience.ivory),
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
                    fontWeight: DsTypography.bold,
                    color: CustomerExperience.ink,
                  ),
                ),
                if (line.variantName != null)
                  Text(
                    line.variantName!,
                    style: TextStyle(
                      fontSize: DsTypography.bodySmall,
                      color: CustomerExperience.muted,
                    ),
                  ),
                const SizedBox(height: 4),
                Text(
                  line.lineTotal.format(),
                  style: TextStyle(
                    fontFamily: DsTypography.fontFamily,
                    fontWeight: DsTypography.bold,
                    color: CustomerExperience.rose,
                  ),
                ),
                if (!line.inStock)
                  Text(
                    'نفد المخزون',
                    style: TextStyle(
                      fontSize: DsTypography.bodySmall,
                      color: const Color(0xFFB91C1C),
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
                icon: const Icon(
                  Icons.delete_outline,
                  color: CustomerExperience.muted,
                ),
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
        color: CustomerExperience.ivory,
        borderRadius: BorderRadius.circular(DsRadius.full),
        border: Border.all(color: CustomerExperience.champagne),
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
                      style: const TextStyle(
                        fontWeight: DsTypography.bold,
                        color: CustomerExperience.ink,
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
      icon: Icon(
        icon,
        color: onTap == null ? colors.disabled : CustomerExperience.rose,
      ),
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
    final disabled = cart.hasOutOfStock;
    return Container(
      padding: EdgeInsets.fromLTRB(
        DsSpacing.lg,
        DsSpacing.md,
        DsSpacing.lg,
        DsSpacing.md + MediaQuery.of(context).padding.bottom,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .92),
        border: Border(
          top: BorderSide(color: CustomerExperience.champagne.withValues(alpha: .5)),
        ),
        boxShadow: CustomerExperience.softShadow,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.l10n.subtotal,
                  style: TextStyle(
                    fontSize: DsTypography.bodySmall,
                    color: CustomerExperience.muted,
                  ),
                ),
                Text(
                  cart.summary.subtotal?.format() ?? '—',
                  style: TextStyle(
                    fontFamily: DsTypography.fontFamily,
                    fontSize: DsTypography.titleMedium,
                    fontWeight: DsTypography.bold,
                    color: CustomerExperience.ink,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            width: 170,
            child: CustomerPrimaryButton(
              label: disabled ? context.l10n.removeOutOfStock : context.l10n.checkout,
              icon: Icons.lock_rounded,
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
    return Padding(
      padding: const EdgeInsets.all(DsSpacing.xl),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 88,
            height: 88,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: CustomerExperience.signatureGradient,
            ),
            child: const Icon(
              Icons.shopping_bag_outlined,
              size: 42,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: DsSpacing.md),
          Text(
            context.l10n.emptyCart,
            style: TextStyle(
              fontFamily: DsTypography.fontFamily,
              fontWeight: DsTypography.bold,
              fontSize: DsTypography.titleMedium,
              color: CustomerExperience.ink,
            ),
          ),
          const SizedBox(height: DsSpacing.xs),
          Text(
            context.l10n.browseAndAdd,
            textAlign: TextAlign.center,
            style: TextStyle(color: CustomerExperience.muted),
          ),
        ],
      ),
    );
  }
}
