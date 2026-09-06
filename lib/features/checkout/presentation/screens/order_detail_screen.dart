import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:reem/core/design_system/design_system.dart';
import 'package:reem/core/localization/l10n_extension.dart';
import 'package:reem/core/media/authorized_media_image.dart';
import 'package:reem/core/media/media_variants.dart';
import 'package:reem/core/router/route_paths.dart';
import 'package:reem/core/shared/value_objects/money.dart';
import 'package:reem/features/chat/domain/entities/chat_start_request.dart';
import 'package:reem/features/chat/presentation/widgets/message_seller_button.dart';
import 'package:reem/features/checkout/domain/entities/checkout.dart';
import 'package:reem/features/checkout/domain/entities/order.dart';
import 'package:reem/features/checkout/presentation/providers/checkout_providers.dart';
import 'package:reem/features/checkout/presentation/providers/order_detail_notifier.dart';
import 'package:reem/features/checkout/presentation/widgets/cod_confirmation_sheet.dart';
import 'package:reem/features/checkout/presentation/widgets/order_status_chip.dart';
import 'package:reem/features/checkout/presentation/widgets/payment_action_card.dart';

/// One order, and what is happening to it.
///
/// **Why it polls.** Tracking is the screen a shopper opens *because* she is
/// waiting: the seller marks a parcel ready, a courier picks it up, the status
/// moves — and the page was a snapshot taken when she opened it, with no pull
/// to refresh either. So it re-reads itself every half minute while the order
/// is still in flight, stops the moment it is delivered or cancelled, and
/// stops whenever the app is in the background so a phone in a pocket is not
/// polling the API all afternoon. Pull-to-refresh is there for the impatient.
class OrderDetailScreen extends ConsumerStatefulWidget {
  const OrderDetailScreen({super.key, required this.orderId});

  final String orderId;

  @override
  ConsumerState<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends ConsumerState<OrderDetailScreen>
    with WidgetsBindingObserver {
  /// Often enough that a shipment notice arrives while she is looking at the
  /// page; rarely enough to be invisible on a metered connection.
  static const Duration _pollEvery = Duration(seconds: 30);

  Timer? _poll;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    _poll?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Back from the background: whatever happened while she was away is
      // exactly what she opened the app to see.
      unawaited(ref.read(orderDetailNotifierProvider(widget.orderId).notifier).load());
    } else {
      _poll?.cancel();
      _poll = null;
    }
  }

  void _syncPolling({required bool inFlight}) {
    if (!inFlight) {
      _poll?.cancel();
      _poll = null;
      return;
    }
    _poll ??= Timer.periodic(_pollEvery, (_) {
      if (!mounted) return;
      unawaited(
        ref.read(orderDetailNotifierProvider(widget.orderId).notifier).load(),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final orderId = widget.orderId;
    final state = ref.watch(orderDetailNotifierProvider(orderId));
    final notifier = ref.read(orderDetailNotifierProvider(orderId).notifier);
    final order = state.order;

    // Arm or disarm after the frame — the timer is a side effect of what the
    // order now says, and build must stay free of them.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _syncPolling(inFlight: order?.status.isInFlight ?? false);
      }
    });

    ref.listen(orderDetailNotifierProvider(orderId).select((s) => s.error),
        (_, error) {
      if (error != null) {
        DsSnackbar.show(context, message: error, type: DsSnackbarType.error);
      }
    });

    return ReemScrollPage(
      onRefresh: notifier.load,
      slivers: [
        PremiumAppBar(
          title: order?.number ?? context.l10n.orderTitle,
          showBack: true,
        ),
        if (state.isLoading && order == null)
          const SliverFillRemaining(
            hasScrollBody: false,
            child: Center(child: CircularProgressIndicator()),
          )
        else if (order == null)
          SliverFillRemaining(
            hasScrollBody: false,
            child: Center(child: Text(context.l10n.orderNotFound)),
          )
        else
          SliverToBoxAdapter(
            child: _Body(order: order, state: state, notifier: notifier),
          ),
      ],
    );
  }
}

/// Tells her the order is waiting, and gives her the one field that ends it.
class _CodConfirmationBanner extends StatelessWidget {
  const _CodConfirmationBanner({required this.orderId, required this.notifier});

  final String orderId;
  final OrderDetailNotifier notifier;

  @override
  Widget build(BuildContext context) {
    final colors = context.dsColors;
    final l10n = context.l10n;

    return SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.sms_outlined, size: 18, color: colors.warning),
              const SizedBox(width: DsSpacing.sm),
              Expanded(
                child: Text(
                  l10n.codAwaitingBanner,
                  style: context.dsText.body.tint(colors.onSurface),
                ),
              ),
            ],
          ),
          const SizedBox(height: DsSpacing.sm),
          PrimaryButton(
            label: l10n.codEnterCode,
            onPressed: () async {
              // The order is already held and its challenge already sent, so
              // there is nothing to re-request here — the sheet opens on a
              // resend if the first message never arrived.
              final confirmed = await showCodConfirmationSheet(
                context,
                orderId: orderId,
                assurance: const CodAssurance(required: 'order_confirmation'),
              );
              if (confirmed) await notifier.load();
            },
          ),
        ],
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.order, required this.state, required this.notifier});

  final OrderDetail order;
  final OrderDetailState state;
  final OrderDetailNotifier notifier;

  @override
  Widget build(BuildContext context) {
    final colors = context.dsColors;
    final payment = order.payment;
    // Whether she still has something to do is the server's answer now — the
    // rail says so. `method != 'cod'` put a confirm button on a wallet payment
    // that had already settled and on a courier-collect one that settles at
    // the door.
    final needsPaymentStep = payment != null && payment.needsCustomerAction;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        DsSpacing.lg,
        DsSpacing.md,
        DsSpacing.lg,
        DsSpacing.xxl,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              OrderStatusChip(status: order.status),
              const SizedBox(width: DsSpacing.sm),
              if (order.isSplit)
                Text(
                  '${order.sellersCount} شحنات من ${order.sellersCount} بائعات',
                  style: context.dsText.bodySmall.tint(colors.onSurfaceVariant),
                ),
            ],
          ),
          const SizedBox(height: DsSpacing.lg),

          // The way back into a held order.
          //
          // Without this the confirmation sheet at checkout would be the only
          // door: dismiss it once — or lose signal on the way — and a placed
          // order sits waiting for a code with nothing on screen saying so, and
          // nowhere to type one.
          if (order.awaitingCodConfirmation) ...[
            _CodConfirmationBanner(orderId: order.id, notifier: notifier),
            const SizedBox(height: DsSpacing.lg),
          ],

          // One card per seller. A basket spanning several sellers becomes
          // several parcels, each tracked, cancelled and returned on its own
          // timeline — so the screen shows them as separate things rather than
          // flattening them into one list of items (Q40/Q89).
          _section(context, 'الشحنات'),
          for (final parcel in order.sellerOrders) ...[
            _ParcelCard(parcel: parcel),
            const SizedBox(height: DsSpacing.sm),
          ],
          const SizedBox(height: DsSpacing.lg),

          _section(context, 'عنوان التوصيل'),
          SurfaceCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _kv(context, order.shipping.recipientName,
                    order.shipping.recipientPhone),
                DsGaps.vXxs,
                Text(
                  '${order.shipping.addressLine}, ${order.shipping.city}, ${order.shipping.governorate}',
                  style: context.dsText.body.tint(colors.onSurfaceVariant),
                ),
                if (order.shipping.landmark != null)
                  Text('علامة مميزة: ${order.shipping.landmark}',
                      style: context.dsText.body.tint(colors.onSurfaceVariant)),
                if (order.privacyMaskEnabled) ...[
                  DsGaps.vXxs,
                  Row(
                    children: [
                      Icon(
                        Icons.visibility_off_outlined,
                        size: DsSizes.iconXs,
                        color: colors.primary,
                      ),
                      DsGaps.hXxs,
                      Expanded(
                        child: Text(
                          context.l10n.orderPrivacyMaskOn,
                          style: context.dsText.caption.tint(colors.primary),
                        ),
                      ),
                    ],
                  ),
                ],
                if (order.deliveryInstructions != null)
                  Padding(
                    padding: const EdgeInsets.only(top: DsSpacing.xxs),
                    child: Text('ملاحظة: ${order.deliveryInstructions}',
                        style: context.dsText.body.tint(colors.onSurfaceVariant)),
                  ),
              ],
            ),
          ),
          const SizedBox(height: DsSpacing.lg),

          if (payment != null) ...[
            _section(context, 'الدفع'),
            SurfaceCard(
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      payment.methodLabel,
                      style: context.dsText.body.semibold.tint(colors.onSurface),
                    ),
                  ),
                  OrderStatusChip.raw(payment.status),
                ],
              ),
            ),
            if (needsPaymentStep) ...[
              const SizedBox(height: DsSpacing.sm),
              PaymentActionCard(
                payment: payment,
                onSettled: notifier.load,
              ),
            ],
            const SizedBox(height: DsSpacing.lg),
          ],

          _section(context, 'الملخّص'),
          SurfaceCard(
            child: Column(
              children: [
                _money(context, 'المجموع الفرعي', order.itemsSubtotal),
                if (!order.discountTotal.isZero)
                  _money(context, 'الخصم', order.discountTotal),
                _money(context, 'التوصيل', order.shippingTotal),
                if (!order.walletApplied.isZero)
                  _money(context, 'من المحفظة', order.walletApplied),
                const Divider(height: DsSpacing.lg),
                _money(context, 'الإجمالي', order.grandTotal, emphasize: true),
              ],
            ),
          ),
          const SizedBox(height: DsSpacing.lg),

          // Q51 — «الاثنين». Tapping through is what issues her invoice; see
          // OrderInvoicesScreen for why that is not done on order placement.
          _InvoicesAction(orderId: order.id),
          const SizedBox(height: DsSpacing.lg),

          _section(context, 'التتبّع'),
          _Timeline(events: order.timeline),

          if (order.isCancellable) ...[
            const SizedBox(height: DsSpacing.xl),
            SecondaryButton(
              label: 'إلغاء الطلب',
              isLoading: state.isActing,
              onPressed: state.isActing
                  ? null
                  : () => _confirmCancel(context, notifier),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _confirmCancel(
    BuildContext context,
    OrderDetailNotifier notifier,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(context.l10n.orderCancelTitle),
        content: Text(context.l10n.orderCancelBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(context.l10n.orderCancelKeep),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(context.l10n.orderCancelConfirm),
          ),
        ],
      ),
    );
    if (confirmed == true) await notifier.cancel();
  }

  Widget _section(BuildContext context, String title) => Padding(
        padding: const EdgeInsets.only(bottom: DsSpacing.sm),
        child: Text(
          title,
          style: context.dsText.tileTitle.bold.tint(context.dsColors.onSurface),
        ),
      );

  Widget _kv(BuildContext context, String name, String phone) => Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(name,
              style: context.dsText.body.semibold.tint(context.dsColors.onSurface)),
          Text(phone, style: context.dsText.body.tint(context.dsColors.onSurfaceVariant)),
        ],
      );

  Widget _money(
    BuildContext context,
    String label,
    Money value,
      {bool emphasize = false}) {
    final colors = context.dsColors;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: DsSpacing.xxs),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: context.dsText.body.tint(emphasize ? colors.onSurface : colors.onSurfaceVariant).copyWith(fontWeight: emphasize ? DsTypography.bold : DsTypography.regular)),
          Text(
            value.format(),
            style: context.dsText.body.tint(emphasize ? colors.primary : colors.onSurface).copyWith(fontWeight: emphasize ? DsTypography.bold : DsTypography.medium),
          ),
        ],
      ),
    );
  }
}

class _ItemRow extends StatelessWidget {
  const _ItemRow({required this.item});
  final OrderItemLine item;

  @override
  Widget build(BuildContext context) {
    final colors = context.dsColors;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: DsSpacing.xs),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(DsRadius.sm),
            child: SizedBox(
              width: 44,
              height: 44,
              child: item.image != null
                  ? AuthorizedMediaImage(
                      url: item.image!,
                      variantWidth: MediaVariants.thumbnail,
                    )
                  : Container(color: colors.surfaceVariant),
            ),
          ),
          const SizedBox(width: DsSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.dsText.body.tint(colors.onSurface)),
                Text(
                  '${item.variantName != null ? '${item.variantName} · ' : ''}x${item.quantity}',
                  style: context.dsText.bodySmall.tint(colors.onSurfaceVariant),
                ),
              ],
            ),
          ),
          Text(item.lineTotal.format(),
              style: context.dsText.body.semibold.tint(colors.onSurface)),
        ],
      ),
    );
  }
}

class _Timeline extends StatelessWidget {
  const _Timeline({required this.events});
  final List<OrderEvent> events;

  @override
  Widget build(BuildContext context) {
    final colors = context.dsColors;
    return SurfaceCard(
      child: Column(
        children: [
          for (var i = 0; i < events.length; i++)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Column(
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      margin: const EdgeInsets.only(top: DsSpacing.xxs),
                      decoration: BoxDecoration(
                        color: colors.primary,
                        shape: BoxShape.circle,
                      ),
                    ),
                    if (i != events.length - 1)
                      Container(width: 2, height: 30, color: colors.border),
                  ],
                ),
                const SizedBox(width: DsSpacing.md),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: DsSpacing.sm),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(events[i].title,
                            style: context.dsText.body.semibold.tint(colors.onSurface)),
                        if (events[i].description != null)
                          Text(events[i].description!,
                              style: context.dsText.bodySmall.tint(colors.onSurfaceVariant)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

/// One seller's parcel: its own status, its own lines, its own tracking, and
/// its own way of reaching the boutique that packed it.
class _ParcelCard extends StatelessWidget {
  const _ParcelCard({required this.parcel});

  final SellerOrder parcel;

  @override
  Widget build(BuildContext context) {
    final colors = context.dsColors;

    return SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  parcel.sellerName,
                  style: context.dsText.body.semibold.tint(colors.onSurface),
                ),
              ),
              OrderStatusChip.parcel(parcel.status),
            ],
          ),
          Text(
            parcel.number,
            style: context.dsText.bodySmall.tint(colors.onSurfaceVariant),
          ),
          const SizedBox(height: DsSpacing.sm),
          for (final item in parcel.items) _ItemRow(item: item),
          if (parcel.shipment != null) ...[
            const Divider(height: DsSpacing.lg),
            // Q64 — «تتبع الشحنة للزبونة». The row already carried the code;
            // making it the way *into* the tracking screen is what turns a
            // number she cannot use into the thing she opens.
            InkWell(
              borderRadius: BorderRadius.circular(DsRadius.sm),
              onTap: () => context.push(
                RoutePaths.shipmentTrackingOf(parcel.shipment!.trackingCode),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: DsSpacing.xxs),
                child: Row(
                  children: [
                    Icon(Icons.local_shipping_outlined,
                        size: 16, color: colors.primary),
                    const SizedBox(width: DsSpacing.xs),
                    Expanded(
                      child: Text(
                        '${context.l10n.trackingCode} ${parcel.shipment!.trackingCode}',
                        style: context.dsText.bodySmall.semibold.tint(colors.primary),
                      ),
                    ),
                    OrderStatusChip.raw(parcel.shipment!.status),
                    Icon(Icons.chevron_left_rounded,
                        size: 18, color: colors.onSurfaceVariant),
                  ],
                ),
              ),
            ),
          ],
          if (parcel.cancellationReason != null) ...[
            const SizedBox(height: DsSpacing.xs),
            Text(
              parcel.cancellationReason!,
              style: context.dsText.bodySmall.tint(colors.error),
            ),
          ],
          const SizedBox(height: DsSpacing.md),
          // Scoped to this parcel, not to the order: a two-seller order has
          // two boutiques to ask, and «أين طلبي؟» only makes sense addressed
          // to the one who is holding it.
          MessageSellerButton(
            label: context.l10n.messageSellerAboutOrder,
            variant: DsButtonVariant.tonal,
            size: DsButtonSize.sm,
            request: ChatStartRequest.order(sellerOrderId: parcel.id),
          ),
        ],
      ),
    );
  }
}

/// The way into the order's documents (Q51).
class _InvoicesAction extends StatelessWidget {
  const _InvoicesAction({required this.orderId});

  final String orderId;

  @override
  Widget build(BuildContext context) {
    final colors = context.dsColors;

    return InkWell(
      borderRadius: BorderRadius.circular(DsRadius.lg),
      onTap: () => context.push(RoutePaths.orderInvoicesOf(orderId)),
      child: Container(
        padding: const EdgeInsets.all(DsSpacing.md),
        decoration: BoxDecoration(
          color: colors.card,
          borderRadius: BorderRadius.circular(DsRadius.lg),
          border: Border.all(color: colors.border.withValues(alpha: 0.5)),
        ),
        child: Row(
          children: [
            Icon(Icons.receipt_long_rounded, size: 20, color: colors.primary),
            const SizedBox(width: DsSpacing.sm),
            Expanded(
              child: Text(
                context.l10n.invoices,
                style: context.dsText.body.semibold.tint(colors.onSurface),
              ),
            ),
            Icon(
              Icons.chevron_left_rounded,
              size: 20,
              color: colors.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }
}
