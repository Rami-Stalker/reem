import 'package:reem/core/shared/value_objects/money.dart';
import 'package:reem/features/seller_orders/domain/entities/seller_order.dart';

/// Wire → domain for the seller's queue.
///
/// Every money field arrives as `{amount, currency}` with the amount as a
/// decimal **string**, and is kept that way: SYP totals run into the millions,
/// and a JSON number is free to round one. Nothing here computes a total — the
/// server already did, exactly, and a second opinion on the client is how an
/// app ends up disagreeing with its own invoice.
final class SellerOrderMapper {
  const SellerOrderMapper._();

  static SellerOrderQueue queueFromJson(Map<String, dynamic> json) {
    final rows = (json['data'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(summaryFromJson)
        .toList();

    final counts = <String, int>{};
    final raw = json['counts'];
    if (raw is Map<String, dynamic>) {
      for (final entry in raw.entries) {
        final value = entry.value;
        if (value is num) counts[entry.key] = value.toInt();
      }
    }

    final pagination = json['pagination'];
    final hasMore =
        pagination is Map<String, dynamic> && pagination['has_more'] == true;

    return SellerOrderQueue(orders: rows, counts: counts, hasMore: hasMore);
  }

  static SellerOrderSummary summaryFromJson(Map<String, dynamic> json) {
    final currency = _currencyOf(json['net']);
    return SellerOrderSummary(
      id: json['id'] as String? ?? '',
      number: json['number'] as String? ?? '',
      status: SellerOrderStatus.fromWire(json['status'] as String?),
      fulfilmentMode: FulfilmentMode.fromWire(
        json['fulfilment_mode'] as String?,
      ),
      placedAt: _date(json['placed_at']) ?? DateTime.now(),
      itemsCount: (json['items_count'] as num?)?.toInt() ?? 0,
      net: _money(json['net'], currency),
      commission: _money(json['commission'], currency),
      customer: customerFromJson(json['customer']),
      actions: (json['available_actions'] as List<dynamic>? ?? const [])
          .map((value) => SellerOrderAction.fromWire(value as String?))
          .whereType<SellerOrderAction>()
          .toList(),
      paymentMethod: json['payment_method'] as String?,
      paymentStatus: json['payment_status'] as String?,
      trackingCode: json['tracking_code'] as String?,
      codRisk: codRiskFromJson(json['cod_risk']),
    );
  }

  static SellerOrderCodRisk? codRiskFromJson(Object? value) {
    if (value is! Map<String, dynamic>) return null;
    return SellerOrderCodRisk(
      tier: value['tier'] as String? ?? 'low',
      label: value['label'] as String? ?? '',
      awaitingConfirmation: value['awaiting_confirmation'] as bool? ?? false,
    );
  }

  static SellerOrderDetail detailFromJson(Map<String, dynamic> json) {
    final currency = Currency.fromWire(json['currency'] as String?);
    final shipment = json['shipment'];

    return SellerOrderDetail(
      summary: summaryFromJson(json),
      orderNumber: json['order_number'] as String? ?? '',
      currency: currency,
      itemsSubtotal: _money(json['items_subtotal'], currency),
      discountTotal: _money(json['discount_total'], currency),
      shippingCost: _money(json['shipping_cost'], currency),
      commissionBase: _money(json['commission_base'], currency),
      items: (json['items'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map((item) => lineFromJson(item, currency))
          .toList(),
      escrowReleased: json['escrow_released'] == true,
      escrowReleaseAt: _date(json['escrow_release_at']),
      confirmedAt: _date(json['confirmed_at']),
      shippedAt: _date(json['shipped_at']),
      deliveredAt: _date(json['delivered_at']),
      cancellationReason: json['cancellation_reason'] as String?,
      shipment: shipment is Map<String, dynamic>
          ? SellerParcelShipment(
              trackingCode: shipment['tracking_code'] as String? ?? '',
              status: (shipment['status'] as String? ?? '').toLowerCase(),
              isAssigned: shipment['assigned'] == true,
              carrierName: shipment['carrier'] is Map<String, dynamic>
                  ? (shipment['carrier'] as Map<String, dynamic>)['name']
                        as String?
                  : null,
              carrierTrackingNumber: shipment['carrier'] is Map<String, dynamic>
                  ? (shipment['carrier']
                            as Map<String, dynamic>)['tracking_number']
                        as String?
                  : null,
              carrierError: shipment['carrier'] is Map<String, dynamic>
                  ? (shipment['carrier'] as Map<String, dynamic>)['last_error']
                        as String?
                  : null,
            )
          : null,
    );
  }

  static SellerOrderLine lineFromJson(
    Map<String, dynamic> json,
    Currency fallback,
  ) {
    return SellerOrderLine(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      quantity: (json['quantity'] as num?)?.toInt() ?? 1,
      unitPrice: _money(json['unit_price'], fallback),
      lineTotal: _money(json['line_total'], fallback),
      variant: json['variant'] as String?,
      image: json['image'] as String?,
      customisation: json['customisation'] is Map<String, dynamic>
          ? json['customisation'] as Map<String, dynamic>
          : null,
    );
  }

  static SellerOrderCustomer customerFromJson(dynamic json) {
    if (json is! Map<String, dynamic>) {
      return const SellerOrderCustomer(name: '—', isMasked: true);
    }
    return SellerOrderCustomer(
      name: json['name'] as String? ?? '—',
      isMasked: json['is_masked'] == true,
      phone: json['phone'] as String?,
      governorate: json['governorate'] as String?,
      city: json['city'] as String?,
      district: json['district'] as String?,
      addressLine: json['address_line'] as String?,
      landmark: json['landmark'] as String?,
      deliveryInstructions: json['delivery_instructions'] as String?,
      maskedBecause: json['masked_because'] as String?,
    );
  }

  static Money _money(dynamic json, Currency fallback) =>
      Money.tryFromJson(json, fallback: fallback) ??
      Money(raw: '0', currency: fallback);

  static Currency _currencyOf(dynamic json) => json is Map<String, dynamic>
      ? Currency.fromWire(json['currency'] as String?)
      : Currency.syp;

  static DateTime? _date(dynamic value) =>
      value is String ? DateTime.tryParse(value)?.toLocal() : null;
}
