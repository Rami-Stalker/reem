import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:ohara/core/design_system/design_system.dart';
import 'package:ohara/core/localization/l10n_extension.dart';
import 'package:ohara/core/media/authorized_media_image.dart';
import 'package:ohara/core/media/media_variants.dart';
import 'package:ohara/core/router/route_paths.dart';
import 'package:ohara/core/shared/value_objects/money.dart';
import 'package:ohara/features/auth/presentation/widgets/auth_prompt_sheet.dart';
import 'package:ohara/features/cart/domain/entities/cart.dart';
import 'package:ohara/features/cart/presentation/providers/cart_providers.dart';

/// Her basket, as the bags she is carrying.
///
/// One bag per boutique, because that is how the order will be fulfilled —
/// each boutique becomes its own parcel (Q40/Q65) — and because it is how a
/// street of shops is actually walked: a bag from each. Each bag carries the
/// boutique's name on a tag and its pieces inside; the total rides on a
/// ticket that floats over the foot of the page.
class CartScreen extends ConsumerWidget {
  const CartScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final state = ref.watch(cartNotifierProvider);
    final notifier = ref.read(cartNotifierProvider.notifier);
    final cart = state.cart;

    ref.listen(cartNotifierProvider.select((s) => s.error), (_, error) {
      if (error != null) {
        DsSnackbar.show(context, message: error, type: DsSnackbarType.error);
      }
    });

    /// Removes a line and says whether it is gone, so a swipe only completes
    /// when the server agreed.
    Future<bool> remove(CartLine line) async {
      await notifier.removeLine(line);
      return !ref
          .read(cartNotifierProvider)
          .cart
          .items
          .any((item) => item.id == line.id);
    }

    final bags = _bagsOf(cart);

    return OharaScrollPage(
      bottom: cart.isEmpty
          ? null
          : _TotalTicket(
              cart: cart,
              onCheckout: () async {
                final ok = await requireAuthenticatedUser(
                  context,
                  ref,
                  title: l10n.signInToCheckout,
                  message: l10n.guestCartSafe,
                  from: RoutePaths.checkout,
                );
                if (ok && context.mounted) {
                  unawaited(context.push(RoutePaths.checkout));
                }
              },
            ),
      slivers: [
        PremiumAppBar(
          title: l10n.myCart,
          subtitle: cart.isEmpty
              ? null
              : '${l10n.itemsCount(cart.summary.totalQuantity)} · '
                    '${l10n.cartBoutiquesCount(bags.length)}',
          showBack: true,
        ),
        if (state.isLoading && cart.isEmpty)
          const SliverFillRemaining(
            hasScrollBody: false,
            child: DsLoadingIndicator(),
          )
        else if (state.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: DsEmptyState.cart(
              message: l10n.browseAndAdd,
              onAction: () => context.go(RoutePaths.home),
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(
              DsSpacing.lg,
              DsSpacing.md,
              DsSpacing.lg,
              // Clears the ticket floating over the foot of the page.
              DsSizes.bottomSafeGap + DsSpacing.huge,
            ),
            sliver: SliverList.separated(
              itemCount: bags.length,
              separatorBuilder: (_, _) => DsGaps.vXl,
              itemBuilder: (_, i) {
                final bag = bags[i];
                return BoutiqueBag(
                      name: bag.name,
                      avatar: DsAvatar(
                        imageUrl: bag.imageUrl,
                        name: bag.name,
                        size: DsSizes.avatarSm,
                      ),
                      // The count and the bag's subtotal share the line under
                      // the name, so a long boutique name keeps its whole row.
                      caption: [
                        l10n.itemsCount(
                          bag.lines.fold(0, (sum, line) => sum + line.quantity),
                        ),
                        ?bag.subtotal?.format(),
                      ].join(' · '),
                      child: Column(
                        children: [
                          for (var j = 0; j < bag.lines.length; j++) ...[
                            if (j > 0) const DashedRule(),
                            _CartLineTile(
                              key: ValueKey(bag.lines[j].id),
                              line: bag.lines[j],
                              isMutating:
                                  state.mutatingItemId == bag.lines[j].id,
                              onIncrement: () =>
                                  notifier.increment(bag.lines[j]),
                              onDecrement: () =>
                                  notifier.decrement(bag.lines[j]),
                              onRemove: () => remove(bag.lines[j]),
                            ),
                          ],
                        ],
                      ),
                    )
                    .animate()
                    .fadeIn(delay: (90 * i).ms, duration: DsMotion.slow)
                    .slideY(
                      begin: 0.08,
                      end: 0,
                      delay: (90 * i).ms,
                      duration: DsMotion.slower,
                      curve: DsMotion.gentle,
                    );
              },
            ),
          ),
      ],
    );
  }

  /// The basket split by boutique, in the order the server grouped it. A line
  /// the groups do not mention still gets a bag of its own seller's — the
  /// lines carry their boutique, so nothing can fall out of the basket.
  static List<_Bag> _bagsOf(Cart cart) {
    final byId = {for (final line in cart.items) line.id: line};
    final placed = <String>{};
    final bags = <_Bag>[];
    for (final group in cart.sellerGroups) {
      final lines = [
        for (final id in group.itemIds)
          if (byId[id] != null) byId[id]!,
      ];
      if (lines.isEmpty) continue;
      placed.addAll(lines.map((line) => line.id));
      bags.add(
        _Bag(
          name: group.sellerName,
          imageUrl: group.sellerImageUrl,
          subtotal: group.subtotal,
          lines: lines,
        ),
      );
    }
    final rest = <String, List<CartLine>>{};
    for (final line in cart.items) {
      if (!placed.contains(line.id)) {
        rest.putIfAbsent(line.sellerId, () => []).add(line);
      }
    }
    for (final lines in rest.values) {
      bags.add(
        _Bag(
          name: lines.first.sellerName,
          imageUrl: lines.first.sellerImageUrl,
          subtotal: null,
          lines: lines,
        ),
      );
    }
    return bags;
  }
}

class _Bag {
  const _Bag({
    required this.name,
    required this.imageUrl,
    required this.subtotal,
    required this.lines,
  });

  final String name;
  final String? imageUrl;
  final Money? subtotal;
  final List<CartLine> lines;
}

/// One piece in a bag. Swipe it away, or use the button — the button stays,
/// because a swipe is invisible to a screen reader and to anyone who has not
/// been told it is there.
class _CartLineTile extends StatelessWidget {
  const _CartLineTile({
    super.key,
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
  final Future<bool> Function() onRemove;

  @override
  Widget build(BuildContext context) {
    final colors = context.dsColors;
    final text = context.dsText;
    final l10n = context.l10n;

    final row = Padding(
      padding: const EdgeInsets.symmetric(vertical: DsSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ArchFrame(
            width: DsSizes.thumbMd,
            dimmed: !line.inStock,
            child: line.image != null
                ? AuthorizedMediaImage(
                    url: line.image!,
                    variantWidth: MediaVariants.thumbnail,
                  )
                : ColoredBox(color: colors.surfaceVariant),
          ),
          DsGaps.hMd,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  line.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: text.cardTitle.bold,
                ),
                if (line.variantName != null) ...[
                  DsGaps.vXxs,
                  _VariantChip(label: line.variantName!),
                ],
                DsGaps.vXs,
                Text(line.lineTotal.format(), style: text.price.tabular),
                if (!line.inStock) ...[
                  DsGaps.vXxs,
                  Row(
                    children: [
                      Icon(
                        Icons.error_outline_rounded,
                        size: DsSizes.iconXs,
                        color: colors.error,
                      ),
                      DsGaps.hXxs,
                      Text(
                        l10n.outOfStock,
                        style: text.caption.bold.tint(colors.error),
                      ),
                    ],
                  ),
                ],
                DsGaps.vSm,
                Row(
                  children: [
                    _QtyStepper(
                      quantity: line.quantity,
                      busy: isMutating,
                      onIncrement: line.canIncrement ? onIncrement : null,
                      onDecrement: onDecrement,
                    ),
                    const Spacer(),
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      tooltip: l10n.removeFromCart,
                      icon: Icon(
                        DsIcons.delete,
                        size: DsSizes.iconSm,
                        color: colors.onSurfaceVariant,
                      ),
                      onPressed: isMutating ? null : onRemove,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );

    return Dismissible(
      key: ValueKey('dismiss-${line.id}'),
      direction: isMutating
          ? DismissDirection.none
          : DismissDirection.endToStart,
      confirmDismiss: (_) => onRemove(),
      background: Container(
        alignment: AlignmentDirectional.centerEnd,
        padding: const EdgeInsets.symmetric(horizontal: DsSpacing.lg),
        decoration: BoxDecoration(
          borderRadius: DsRadius.borderLg,
          gradient: LinearGradient(
            begin: AlignmentDirectional.centerStart,
            end: AlignmentDirectional.centerEnd,
            colors: [
              colors.errorContainer.withValues(alpha: 0),
              colors.errorContainer,
            ],
          ),
        ),
        child: Icon(DsIcons.delete, color: colors.error),
      ),
      child: row,
    );
  }
}

class _VariantChip extends StatelessWidget {
  const _VariantChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = context.dsColors;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: DsSpacing.xs,
        vertical: DsSpacing.xxxs,
      ),
      decoration: BoxDecoration(
        borderRadius: DsRadius.borderPill,
        color: colors.secondaryContainer.withValues(alpha: 0.7),
      ),
      child: Text(
        label,
        style: context.dsText.caption.tint(colors.onSecondaryContainer),
      ),
    );
  }
}

/// A capsule stepper: the count in the middle on a lit bead.
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
      padding: const EdgeInsets.all(DsSpacing.xxxs),
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
            tooltip: context.l10n.decreaseQuantity,
            onTap: busy ? null : onDecrement,
          ),
          Container(
            width: DsSizes.iconLg,
            height: DsSizes.iconLg,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: context.primaryGradient,
            ),
            child: busy
                ? DsLoadingIndicator.inline(color: DsColors.onMedia)
                : AnimatedSwitcher(
                    duration: DsMotion.normal,
                    transitionBuilder: (child, animation) =>
                        ScaleTransition(scale: animation, child: child),
                    child: Text(
                      '$quantity',
                      key: ValueKey(quantity),
                      style: context.dsText.labelStrong.tabular.tint(
                        DsColors.onMedia,
                      ),
                    ),
                  ),
          ),
          _StepperButton(
            icon: Icons.add_rounded,
            tooltip: context.l10n.increaseQuantity,
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

/// The total on a floating ticket, with the way to the till.
class _TotalTicket extends StatelessWidget {
  const _TotalTicket({required this.cart, required this.onCheckout});

  final Cart cart;
  final VoidCallback onCheckout;

  @override
  Widget build(BuildContext context) {
    final text = context.dsText;
    final disabled = cart.hasOutOfStock;

    return TicketBar(
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              // A `Scaffold` lays a bottom bar out under loose height
              // constraints; without this the column took the whole screen.
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(context.l10n.subtotal, style: text.caption),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: AlignmentDirectional.centerStart,
                  child: Text(
                    cart.summary.subtotal?.format() ?? '—',
                    style: text.sectionTitle.bold.tabular,
                  ),
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
