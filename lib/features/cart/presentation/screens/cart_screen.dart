import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:reem/core/design_system/design_system.dart';
import 'package:reem/core/localization/l10n_extension.dart';
import 'package:reem/core/media/authorized_media_image.dart';
import 'package:reem/core/media/media_variants.dart';
import 'package:reem/core/router/route_paths.dart';
import 'package:reem/features/auth/presentation/widgets/auth_prompt_sheet.dart';
import 'package:reem/features/cart/domain/entities/cart.dart';
import 'package:reem/features/cart/presentation/providers/cart_providers.dart';

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
                  message: context.l10n.guestCartSafe,
                  from: RoutePaths.checkout,
                );
                if (ok && context.mounted) {
                  unawaited(context.push(RoutePaths.checkout));
                }
              },
            ),
      slivers: [
        PremiumAppBar(title: context.l10n.myCart, showBack: true),
        if (state.isLoading && state.cart.isEmpty)
          const SliverFillRemaining(
            hasScrollBody: false,
            child: DsLoadingIndicator(),
          )
        else if (state.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: DsEmptyState.cart(
              message: context.l10n.browseAndAdd,
              onAction: () => context.go(RoutePaths.home),
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(
              DsSpacing.lg,
              DsSpacing.sm,
              DsSpacing.lg,
              // Clears the checkout bar pinned to the bottom of the page.
              DsSizes.bottomSafeGap + DsSpacing.xxl,
            ),
            sliver: SliverList.separated(
              itemCount: state.cart.items.length,
              separatorBuilder: (_, _) => DsGaps.vMd,
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
    final text = context.dsText;

    return CustomerPanel(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: DsRadius.borderImage,
            child: SizedBox(
              width: DsSizes.thumbMd,
              height: DsSizes.thumbMd / DsSizes.aspectPortrait,
              child: line.image != null
                  ? AuthorizedMediaImage(
                      url: line.image!,
                      variantWidth: MediaVariants.thumbnail,
                    )
                  : ColoredBox(color: colors.surfaceVariant),
            ),
          ),
          DsGaps.hMd,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  line.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: text.cardTitle.bold,
                ),
                if (line.variantName != null)
                  Text(line.variantName!, style: text.cardSubtitle),
                DsGaps.vXxs,
                Text(line.lineTotal.format(), style: text.price),
                if (!line.inStock)
                  Text(
                    context.l10n.outOfStock,
                    style: text.caption.bold.tint(colors.error),
                  ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              IconButton(
                visualDensity: VisualDensity.compact,
                tooltip: context.l10n.removeFromCart,
                icon: Icon(
                  DsIcons.delete,
                  size: DsSizes.iconSm,
                  color: colors.onSurfaceVariant,
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
        color: colors.surfaceVariant,
        borderRadius: DsRadius.borderFull,
        border: Border.all(color: colors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _StepperButton(
            icon: Icons.remove_rounded,
            tooltip: 'إنقاص الكمية',
            onTap: busy ? null : onDecrement,
          ),
          SizedBox(
            width: DsSizes.iconLg,
            child: Center(
              child: busy
                  ? DsLoadingIndicator.inline(color: colors.primary)
                  : Text(
                      '$quantity',
                      style: context.dsText.labelStrong.tabular,
                    ),
            ),
          ),
          _StepperButton(
            icon: Icons.add_rounded,
            tooltip: 'زيادة الكمية',
            onTap: busy ? null : onIncrement,
          ),
        ],
      ),
    );
  }
}

class _StepperButton extends StatelessWidget {
  const _StepperButton({
    required this.icon,
    required this.onTap,
    required this.tooltip,
  });

  final IconData icon;
  final VoidCallback? onTap;

  /// Required, not optional. A plus and a minus are indistinguishable to a
  /// screen reader — both announce as "button" — and a required parameter is
  /// the only version of this rule that survives the next stepper somebody
  /// adds.
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    final colors = context.dsColors;
    return IconButton(
      tooltip: tooltip,
      visualDensity: VisualDensity.compact,
      iconSize: DsSizes.iconXs,
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
    final text = context.dsText;
    final disabled = cart.hasOutOfStock;

    return Container(
      padding: EdgeInsets.fromLTRB(
        DsSpacing.lg,
        DsSpacing.md,
        DsSpacing.lg,
        DsSpacing.md + MediaQuery.paddingOf(context).bottom,
      ),
      decoration: BoxDecoration(
        // Reads from the theme: a fixed white bar was the one part of the cart
        // that stayed bright when the rest of the page went aubergine.
        color: colors.surfaceElevated.withValues(alpha: 0.94),
        border: Border(top: BorderSide(color: colors.border)),
        boxShadow: context.boutique.shadow,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              // Without this the bar swallowed the page. `Scaffold` lays a
              // bottom bar out under *loose* height constraints, a `Row` gives
              // its children the same loose height, and a `Column` that is
              // free to be tall takes all of it — so this bar became the full
              // screen: its translucent background veiled the cart behind it,
              // "Subtotal" sat in the top-left corner and "Checkout" floated
              // in the middle of the page.
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(context.l10n.subtotal, style: text.caption),
                Text(
                  cart.summary.subtotal?.format() ?? '—',
                  style: text.cardTitle.bold.tabular,
                ),
              ],
            ),
          ),
          DsGaps.hMd,
          Expanded(
            child: CustomerPrimaryButton(
              label: disabled
                  ? context.l10n.removeOutOfStock
                  : context.l10n.checkout,
              icon: Icons.lock_rounded,
              onPressed: disabled ? null : onCheckout,
            ),
          ),
        ],
      ),
    );
  }
}
