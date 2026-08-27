import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/design_system/design_system.dart';
import '../../../../core/localization/l10n_extension.dart';
import '../../../../core/router/route_paths.dart';
import '../../domain/entities/order.dart';
import '../providers/checkout_providers.dart';
import '../providers/order_detail_notifier.dart';
import '../widgets/order_status_chip.dart';
import '../../../../core/shared/value_objects/money.dart';

class OrderDetailScreen extends ConsumerWidget {
  const OrderDetailScreen({super.key, required this.orderId});

  final String orderId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(orderDetailNotifierProvider(orderId));
    final notifier = ref.read(orderDetailNotifierProvider(orderId).notifier);
    final order = state.order;

    ref.listen(orderDetailNotifierProvider(orderId).select((s) => s.error),
        (_, error) {
      if (error != null) {
        DsSnackbar.show(context, message: error, type: DsSnackbarType.error);
      }
    });

    return ReemScrollPage(
      slivers: [
        PremiumAppBar(title: order?.number ?? 'Order', showBack: true),
        if (state.isLoading && order == null)
          const SliverFillRemaining(
            hasScrollBody: false,
            child: Center(child: CircularProgressIndicator()),
          )
        else if (order == null)
          const SliverFillRemaining(
            hasScrollBody: false,
            child: Center(child: Text('Order not found')),
          )
        else
          SliverToBoxAdapter(
            child: _Body(order: order, state: state, notifier: notifier),
          ),
      ],
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
    final canConfirmPayment =
        payment != null && payment.isPending && payment.method != 'cod';

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
                  style: TextStyle(
                    fontSize: DsTypography.bodySmall,
                    color: colors.onSurfaceVariant,
                  ),
                ),
            ],
          ),
          const SizedBox(height: DsSpacing.lg),

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
                const SizedBox(height: 4),
                Text(
                  '${order.shipping.addressLine}, ${order.shipping.city}, ${order.shipping.governorate}',
                  style: TextStyle(color: colors.onSurfaceVariant),
                ),
                if (order.shipping.landmark != null)
                  Text('علامة مميزة: ${order.shipping.landmark}',
                      style: TextStyle(color: colors.onSurfaceVariant)),
                if (order.deliveryInstructions != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text('ملاحظة: ${order.deliveryInstructions}',
                        style: TextStyle(color: colors.onSurfaceVariant)),
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
                      style: TextStyle(
                        fontWeight: DsTypography.semiBold,
                        color: colors.onSurface,
                      ),
                    ),
                  ),
                  OrderStatusChip.raw(payment.status),
                ],
              ),
            ),
            if (canConfirmPayment) ...[
              const SizedBox(height: DsSpacing.sm),
              PrimaryButton(
                label: 'تأكيد الدفع',
                isLoading: state.isActing,
                onPressed: state.isActing
                    ? null
                    : () async {
                        final ok = await notifier.verifyPayment();
                        if (ok && context.mounted) {
                          DsSnackbar.show(context,
                              message: 'تم تأكيد الدفع',
                              type: DsSnackbarType.success);
                        }
                      },
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
        title: const Text('Cancel order?'),
        content: const Text('This will cancel the order and restock the items.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Keep'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Cancel order'),
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
          style: TextStyle(
            fontFamily: DsTypography.fontFamily,
            fontWeight: DsTypography.bold,
            fontSize: DsTypography.titleSmall,
            color: context.dsColors.onSurface,
          ),
        ),
      );

  Widget _kv(BuildContext context, String name, String phone) => Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(name,
              style: TextStyle(
                  fontWeight: DsTypography.semiBold,
                  color: context.dsColors.onSurface)),
          Text(phone, style: TextStyle(color: context.dsColors.onSurfaceVariant)),
        ],
      );

  Widget _money(
    BuildContext context,
    String label,
    Money value,
      {bool emphasize = false}) {
    final colors = context.dsColors;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: TextStyle(
                  color: emphasize ? colors.onSurface : colors.onSurfaceVariant,
                  fontWeight:
                      emphasize ? DsTypography.bold : DsTypography.regular)),
          Text(
            value.format(),
            style: TextStyle(
              fontFamily: DsTypography.fontFamily,
              fontWeight: emphasize ? DsTypography.bold : DsTypography.medium,
              color: emphasize ? colors.primary : colors.onSurface,
            ),
          ),
        ],
      ),
    );
  }

  String _date(DateTime d) => '${d.day}/${d.month}/${d.year}';
}

class _ItemRow extends StatelessWidget {
  const _ItemRow({required this.item});
  final OrderItemLine item;

  @override
  Widget build(BuildContext context) {
    final colors = context.dsColors;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(DsRadius.sm),
            child: SizedBox(
              width: 44,
              height: 44,
              child: item.image != null
                  ? Image.network(item.image!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) =>
                          Container(color: colors.surfaceVariant))
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
                    style: TextStyle(color: colors.onSurface)),
                Text(
                  '${item.variantName != null ? '${item.variantName} · ' : ''}x${item.quantity}',
                  style: TextStyle(
                      fontSize: DsTypography.bodySmall,
                      color: colors.onSurfaceVariant),
                ),
              ],
            ),
          ),
          Text(item.lineTotal.format(),
              style: TextStyle(
                  fontWeight: DsTypography.semiBold, color: colors.onSurface)),
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
                      margin: const EdgeInsets.only(top: 4),
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
                            style: TextStyle(
                                fontWeight: DsTypography.semiBold,
                                color: colors.onSurface)),
                        if (events[i].description != null)
                          Text(events[i].description!,
                              style: TextStyle(
                                  fontSize: DsTypography.bodySmall,
                                  color: colors.onSurfaceVariant)),
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

/// One seller's parcel: its own status, its own lines and its own tracking.
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
                  style: TextStyle(
                    fontFamily: DsTypography.fontFamily,
                    fontWeight: DsTypography.semiBold,
                    color: colors.onSurface,
                  ),
                ),
              ),
              OrderStatusChip.parcel(parcel.status),
            ],
          ),
          Text(
            parcel.number,
            style: TextStyle(
              fontSize: DsTypography.bodySmall,
              color: colors.onSurfaceVariant,
            ),
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
                        style: TextStyle(
                          fontSize: DsTypography.bodySmall,
                          fontWeight: DsTypography.semiBold,
                          color: colors.primary,
                        ),
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
              style: TextStyle(
                fontSize: DsTypography.bodySmall,
                color: colors.error,
              ),
            ),
          ],
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
                style: TextStyle(
                  fontSize: DsTypography.bodyMedium,
                  fontWeight: DsTypography.semiBold,
                  color: colors.onSurface,
                ),
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
