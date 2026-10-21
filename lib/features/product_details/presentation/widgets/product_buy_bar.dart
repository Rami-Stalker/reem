import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:reem/core/design_system/design_system.dart';
import 'package:reem/core/localization/l10n_extension.dart';
import 'package:reem/core/platform/app_haptics.dart';
import 'package:reem/core/router/route_paths.dart';
import 'package:reem/core/shared/entities/product_variant.dart';
import 'package:reem/core/shared/entities/seller_offer.dart';
import 'package:reem/core/shared/value_objects/money.dart';
import 'package:reem/features/auth/presentation/widgets/auth_prompt_sheet.dart';
import 'package:reem/features/cart/presentation/providers/cart_providers.dart';
import 'package:reem/features/rooms/presentation/widgets/propose_to_room_sheet.dart';

/// The frosted bar pinned to the foot of the product page.
///
/// The bar it replaces showed a fixed `$240` and an "add to cart" button that
/// flipped to a tick for two seconds and put nothing anywhere. This one quotes
/// the selected offer's line total and posts to the real cart, behind the same
/// sign-in gate every other write in the app uses.
class ProductBuyBar extends ConsumerStatefulWidget {
  const ProductBuyBar({
    super.key,
    required this.offer,
    required this.variant,
    required this.quantity,
  });

  final SellerOffer? offer;
  final OfferVariant? variant;
  final int quantity;

  @override
  ConsumerState<ProductBuyBar> createState() => _ProductBuyBarState();
}

class _ProductBuyBarState extends ConsumerState<ProductBuyBar> {
  bool _adding = false;

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
                      buyable ? l10n.total : l10n.productUnavailable,
                      style: text.caption,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (buyable) ...[
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
                  ],
                ),
              ),
              DsGaps.hMd,
              // Reem Rooms, beside the cart rather than instead of it. The two
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
