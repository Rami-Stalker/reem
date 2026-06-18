import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/design_system/design_system.dart';
import '../../../../core/design_system/components/cards/surface_card.dart';
import '../../../../core/design_system/components/snackbars/app_snackbar.dart'
    show DsSnackbar, DsSnackbarType;
import '../../../../core/shared/wedgets/app/premium_app_bar.dart';
import '../../domain/entities/order.dart';
import '../providers/checkout_providers.dart';
import '../providers/order_detail_notifier.dart';
import '../widgets/order_status_chip.dart';

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
              Text(
                'Delivery: ${humanizeStatus(order.deliveryStatus)}',
                style: TextStyle(
                  fontSize: DsTypography.bodySmall,
                  color: colors.onSurfaceVariant,
                ),
              ),
            ],
          ),
          if (order.estimatedDeliveryAt != null) ...[
            const SizedBox(height: DsSpacing.xs),
            Text(
              'Estimated delivery: ${_date(order.estimatedDeliveryAt!)}',
              style: TextStyle(
                fontSize: DsTypography.bodySmall,
                color: colors.onSurfaceVariant,
              ),
            ),
          ],
          const SizedBox(height: DsSpacing.lg),

          _section(context, 'Items'),
          SurfaceCard(
            child: Column(
              children: [
                for (final item in order.items) _ItemRow(item: item),
              ],
            ),
          ),
          const SizedBox(height: DsSpacing.lg),

          _section(context, 'Delivery address'),
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
                  Text('Landmark: ${order.shipping.landmark}',
                      style: TextStyle(color: colors.onSurfaceVariant)),
                if (order.deliveryInstructions != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text('Note: ${order.deliveryInstructions}',
                        style: TextStyle(color: colors.onSurfaceVariant)),
                  ),
              ],
            ),
          ),
          const SizedBox(height: DsSpacing.lg),

          if (payment != null) ...[
            _section(context, 'Payment'),
            SurfaceCard(
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      humanizeStatus(payment.method),
                      style: TextStyle(
                        fontWeight: DsTypography.semiBold,
                        color: colors.onSurface,
                      ),
                    ),
                  ),
                  OrderStatusChip(status: payment.status),
                ],
              ),
            ),
            if (canConfirmPayment) ...[
              const SizedBox(height: DsSpacing.sm),
              PrimaryButton(
                label: 'Confirm payment',
                isLoading: state.isActing,
                onPressed: state.isActing
                    ? null
                    : () async {
                        final ok = await notifier.verifyPayment();
                        if (ok && context.mounted) {
                          DsSnackbar.show(context,
                              message: 'Payment confirmed',
                              type: DsSnackbarType.success);
                        }
                      },
              ),
            ],
            const SizedBox(height: DsSpacing.lg),
          ],

          _section(context, 'Summary'),
          SurfaceCard(
            child: Column(
              children: [
                _money(context, 'Subtotal', order.subtotal),
                if (order.discount > 0)
                  _money(context, 'Discount', -order.discount),
                _money(context, 'Delivery', order.deliveryFee),
                const Divider(height: DsSpacing.lg),
                _money(context, 'Total', order.total, emphasize: true),
              ],
            ),
          ),
          const SizedBox(height: DsSpacing.lg),

          _section(context, 'Tracking'),
          _Timeline(events: order.timeline),

          if (order.isCancellable) ...[
            const SizedBox(height: DsSpacing.xl),
            SecondaryButton(
              label: 'Cancel order',
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

  Widget _money(BuildContext context, String label, double value,
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
            '\$${value.toStringAsFixed(2)}',
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
          Text('\$${item.lineTotal.toStringAsFixed(2)}',
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
