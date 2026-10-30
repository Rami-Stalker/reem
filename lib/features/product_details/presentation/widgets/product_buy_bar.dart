import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ohara/core/design_system/design_system.dart';
import 'package:ohara/core/localization/l10n_extension.dart';
import 'package:ohara/core/platform/app_haptics.dart';
import 'package:ohara/core/router/route_paths.dart';
import 'package:ohara/core/shared/entities/product.dart';
import 'package:ohara/core/shared/entities/product_variant.dart';
import 'package:ohara/core/shared/entities/seller_offer.dart';
import 'package:ohara/core/shared/value_objects/money.dart';
import 'package:ohara/features/auth/presentation/widgets/auth_prompt_sheet.dart';
import 'package:ohara/features/cart/presentation/providers/cart_providers.dart';
import 'package:ohara/features/chat/domain/entities/chat_message_entity.dart';
import 'package:ohara/features/chat/domain/entities/chat_start_request.dart';
import 'package:ohara/features/chat/presentation/widgets/message_seller_button.dart';
import 'package:ohara/features/product_social/presentation/product_gestures.dart';
import 'package:ohara/features/product_social/presentation/providers/product_social_providers.dart';
import 'package:ohara/features/profile/presentation/providers/profile_provider.dart';
import 'package:ohara/features/rooms/presentation/widgets/propose_to_room_sheet.dart';

/// The frosted bar pinned to the foot of the product page.
///
/// The bar it replaces showed a fixed `$240` and an "add to cart" button that
/// flipped to a tick for two seconds and put nothing anywhere. This one quotes
/// the selected offer's line total and posts to the real cart, behind the same
/// sign-in gate every other write in the app uses.
class ProductBuyBar extends ConsumerStatefulWidget {
  const ProductBuyBar({
    super.key,
    required this.product,
    required this.offer,
    required this.variant,
    required this.quantity,
  });

  final Product product;
  final SellerOffer? offer;
  final OfferVariant? variant;
  final int quantity;

  @override
  ConsumerState<ProductBuyBar> createState() => _ProductBuyBarState();
}

class _ProductBuyBarState extends ConsumerState<ProductBuyBar> {
  bool _adding = false;
  bool _opening = false;

  /// «اسألي المتجر» — the boutique behind the selected offer, with this piece
  /// pinned in the conversation so her question arrives carrying its card.
  /// In the bar rather than only in the seller card far down the page,
  /// because the question usually comes before the scroll does.
  Future<void> _ask() async {
    final seller = widget.offer?.seller;
    if (seller == null || _opening) return;
    setState(() => _opening = true);
    try {
      await openConversation(
        context,
        ref,
        ChatStartRequest.product(
          productId: widget.product.id,
          sellerId: seller.id,
        ),
        about: ChatProductRef.of(widget.product, offer: widget.offer),
      );
    } finally {
      if (mounted) setState(() => _opening = false);
    }
  }

  Money? get _unitPrice => widget.variant?.price ?? widget.offer?.price;

  /// The line total, computed on the raw decimal so the figure shown is the
  /// one the server will charge.
  String? get _lineTotal {
    final unit = _unitPrice;
    if (unit == null) return null;
    final total = unit.approximateValue * widget.quantity;
    return Money(raw: total.toString(), currency: unit.currency).format();
  }

  Future<void> _add() async {
    final offer = widget.offer;
    if (offer == null || _adding) return;

    final ok = await requireAuthenticatedUser(
      context,
      ref,
      title: context.l10n.signInToInteract,
      message: context.l10n.signInToInteractBody,
      from: RoutePaths.productDetails,
    );
    if (!ok || !mounted) return;

    setState(() => _adding = true);
    AppHaptics.confirm();
    final added = await ref
        .read(cartNotifierProvider.notifier)
        .add(
          offerId: offer.id,
          offerVariantId: widget.variant?.id,
          quantity: widget.quantity,
        );
    if (!mounted) return;
    setState(() => _adding = false);

    if (added) {
      AppHaptics.selection();
      DsSnackbar.success(context, context.l10n.addedToBag);
    } else {
      DsSnackbar.error(context, context.l10n.actionDidNotSave);
    }
  }

  /// Propose this piece as an answer to a question in one of her rooms.
  ///
  /// A sheet rather than a direct add, because a room needs to know *which*
  /// question it answers — the distinction that keeps a room from silently
  /// becoming a basket.
  Future<void> _proposeToRoom() async {
    final offer = widget.offer;
    if (offer == null) return;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => ProposeToRoomSheet(
        offerId: offer.id,
        offerVariantId: widget.variant?.id,
      ),
    );
  }

  /// The bar's frosted frame, shared by both of its faces.
  Widget _frame(BuildContext context, Widget child) {
    final colors = context.dsColors;
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: DsBlur.heavy, sigmaY: DsBlur.heavy),
        child: Container(
          padding: EdgeInsets.fromLTRB(
            DsSpacing.lg,
            DsSpacing.md,
            DsSpacing.lg,
            DsSpacing.md + MediaQuery.paddingOf(context).bottom,
          ),
          decoration: BoxDecoration(
            color: colors.surfaceElevated.withValues(alpha: 0.92),
            border: Border(top: BorderSide(color: colors.border)),
            boxShadow: context.softShadow,
          ),
          child: child,
        ),
      ),
    );
  }

  /// Why it cannot be bought, said whole — and what she can do instead.
  ///
  /// This used to be the price's slot: a third of the bar, one line, and an
  /// ellipsis, so «هالقطعة مو متوفرة هلّق» reached her as «هالقطعة مو…» beside
  /// a greyed-out button, and she could not tell what was wrong. The bar now
  /// gives the whole width to the reason, and offers the two things that
  /// still make sense: be told when it is back (her favourites get that
  /// alert), and ask the boutique.
  Widget _unavailable(BuildContext context, SellerOffer? offer) {
    final l10n = context.l10n;
    final colors = context.dsColors;
    final variantOnly = offer != null && offer.isBuyable;
    final (title, body) = switch (offer) {
      null => (l10n.productUnavailableNoSeller, l10n.productUnavailableNoSellerBody),
      _ when variantOnly => (
        l10n.productUnavailableVariant,
        l10n.productUnavailableVariantBody,
      ),
      _ when offer.status == OfferStatus.paused => (
        l10n.productUnavailablePaused,
        l10n.productUnavailablePausedBody,
      ),
      _ => (l10n.productUnavailableSoldOut, l10n.productUnavailableSoldOutBody),
    };
    final saved = ProductGestures.watch(ref, widget.product).isSaved;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.info_outline_rounded,
              size: DsSizes.iconSm,
              color: colors.warningInk,
            ),
            DsGaps.hXs,
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: context.dsText.bodyStrong),
                  DsGaps.vXxxs,
                  Text(
                    body,
                    style: context.dsText.caption.tint(colors.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          ],
        ),
        DsGaps.vSm,
        Row(
          children: [
            if (offer != null) ...[
              IconButton.outlined(
                tooltip: l10n.productAskBoutique,
                onPressed: _opening ? null : _ask,
                icon: _opening
                    ? const SizedBox.square(
                        dimension: DsSizes.iconSm,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.chat_bubble_outline_rounded),
              ),
              DsGaps.hSm,
            ],
            Expanded(
              // A choice of option is hers to change on the page above, so
              // the alert is offered only when the piece itself is gone.
              child: variantOnly
                  ? const SizedBox.shrink()
                  : DsButton(
                      label: saved
                          ? l10n.productNotifyOn
                          : l10n.productNotifyWhenBack,
                      icon: saved
                          ? Icons.notifications_active_rounded
                          : Icons.notifications_none_rounded,
                      variant: saved
                          ? DsButtonVariant.tonal
                          : DsButtonVariant.primary,
                      isLoading: _notifying,
                      onPressed: _notifying ? null : () => _notify(saved),
                    ),
            ),
          ],
        ),
      ],
    );
  }

  bool _notifying = false;

  /// «خبّريني لما ترجع» — kept in her favourites, which is what the
  /// back-in-stock alert is sent to. No collection sheet in the way here:
  /// she asked to be told, not to file it.
  Future<void> _notify(bool saved) async {
    final ok = await requireAuthenticatedUser(
      context,
      ref,
      title: context.l10n.signInToInteract,
      message: context.l10n.signInToInteractBody,
      from: RoutePaths.productDetailsOf(widget.product.id),
    );
    if (!ok || !mounted) return;
    setState(() => _notifying = true);
    final outcome = await ref
        .read(productEngagementProvider.notifier)
        .setSaved(widget.product.id, !saved);
    if (!mounted) return;
    setState(() => _notifying = false);
    final l10n = context.l10n;
    if (outcome == EngagementOutcome.failed) {
      DsSnackbar.error(context, l10n.actionDidNotSave);
      return;
    }
    unawaited(ref.read(favoritesNotifierProvider.notifier).load());
    DsSnackbar.success(
      context,
      saved ? l10n.productNotifyOff : l10n.productNotifyConfirmed,
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.dsColors;
    final text = context.dsText;
    final l10n = context.l10n;

    final offer = widget.offer;
    final buyable =
        offer != null &&
        offer.isBuyable &&
        (widget.variant == null || widget.variant!.inStock);

    if (!buyable) return _frame(context, _unavailable(context, offer));

    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: DsBlur.heavy, sigmaY: DsBlur.heavy),
        child: Container(
          padding: EdgeInsets.fromLTRB(
            DsSpacing.lg,
            DsSpacing.md,
            DsSpacing.lg,
            DsSpacing.md + MediaQuery.paddingOf(context).bottom,
          ),
          decoration: BoxDecoration(
            color: colors.surfaceElevated.withValues(alpha: 0.92),
            border: Border(top: BorderSide(color: colors.border)),
            boxShadow: context.softShadow,
          ),
          // 1:2, not an even split. An even one gave the button exactly half
          // the bar, which is not enough for «أضيفي إلى السلة» or even "Add to
          // cart" beside its icon — the call to action arrived as "Add to …".
          // The figure yields instead, and shrinks rather than truncating,
          // because half a price is worse than a small one; it is also still
          // spelled out in full in the price block further up the page.
          child: Row(
            children: [
              Expanded(
                flex: 1,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      l10n.total,
                      style: text.caption,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    DsGaps.vXxs,
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: AlignmentDirectional.centerStart,
                      child: Text(
                        _lineTotal ?? '—',
                        maxLines: 1,
                        style: text.metric.tint(colors.price),
                      ),
                    ),
                  ],
                ),
              ),
              DsGaps.hXs,
              IconButton(
                tooltip: l10n.productAskBoutique,
                icon: _opening
                    ? const SizedBox.square(
                        dimension: DsSizes.iconSm,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.chat_bubble_outline_rounded),
                onPressed: _opening ? null : _ask,
              ),
              // Ohara Rooms, beside the cart rather than instead of it. The two
              // are different gestures: the cart is "I am taking this", a room
              // is "I am thinking about this" — and a shop that only offers the
              // first forces every considered purchase to pretend to be a
              // decided one.
              IconButton(
                tooltip: context.l10n.productAddToRoom,
                icon: const Icon(Icons.meeting_room_outlined),
                onPressed: buyable ? _proposeToRoom : null,
              ),
              Expanded(
                flex: 2,
                child: PrimaryButton(
                  label: l10n.addToCart,
                  icon: DsIcons.cart,
                  isLoading: _adding,
                  onPressed: buyable ? _add : null,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
