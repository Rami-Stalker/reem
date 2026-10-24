import 'package:ohara/core/shared/value_objects/money.dart';
import 'package:ohara/features/seller_returns/domain/entities/return_request.dart';

/// Parses `/returns/*`.
///
/// Unlike the catalogue endpoints, this module serialises its enums in the
/// Prisma casing (`IN_TRANSIT`, `NOT_AS_DESCRIBED`) rather than lowercasing
/// them. Every `fromWire` here upper-cases before matching, so it reads either
/// way and cannot be broken by that convention being tidied later.
abstract final class ReturnRequestMapper {
  static List<ReturnRequest> listFromJson(List<dynamic> json) => [
    for (final row in json.whereType<Map>())
      fromJson(row.cast<String, dynamic>()),
  ];

  static ReturnRequest fromJson(Map<String, dynamic> json) {
    final parcel = _map(json['order']);

    return ReturnRequest(
      id: json['id'] as String,
      number: json['number'] as String? ?? '',
      status: ReturnStatus.fromWire(json['status'] as String?),
      resolution: ReturnResolution.fromWire(json['resolution'] as String?),
      reason: ReturnReason.fromWire(json['reason'] as String?),
      reasonNote: json['reason_note'] as String?,
      shippingBorneBy: ReturnCostBearer.fromWire(
        json['shipping_borne_by'] as String?,
      ),
      evidence: [
        for (final photo in (json['evidence'] as List? ?? const []))
          if (photo is String) photo,
      ],
      parcel: ReturnParcel(
        orderId: parcel['id'] as String? ?? '',
        orderNumber: parcel['number'] as String? ?? '',
        sellerOrderId: parcel['seller_order_id'] as String? ?? '',
        sellerOrderNumber: parcel['seller_order_number'] as String? ?? '',
        status: parcel['status'] as String?,
      ),
      items: [
        for (final line in (json['items'] as List? ?? const []).whereType<Map>())
          ReturnLine(
            orderItemId: line['order_item_id'] as String? ?? '',
            title: line['title'] as String? ?? '',
            quantity: (line['quantity'] as num?)?.toInt() ?? 0,
            variant: line['variant'] as String?,
            image: line['image'] as String?,
          ),
      ],
      refund: _refund(json['refund']),
      windowClosesAt: _date(json['window_closes_at']),
      decidedAt: _date(json['decided_at']),
      createdAt: _date(json['created_at']) ?? DateTime.now(),
    );
  }

  /// `null` until the goods are back and there is nothing to quote yet.
  static RefundQuote? _refund(dynamic value) {
    if (value is! Map) return null;
    final json = value.cast<String, dynamic>();
    final amount = Money.tryFromJson(json['amount']);
    if (amount == null) return null;

    return RefundQuote(
      amount: amount,
      settled: json['settled'] as bool? ?? false,
      goods: Money.tryFromJson(json['goods']),
      returnShippingFee: Money.tryFromJson(json['return_shipping_fee']),
      borneBy: ReturnCostBearer.fromWire(json['borne_by'] as String?),
      isFullParcel: json['is_full_parcel'] as bool? ?? false,
    );
  }

  static Map<String, dynamic> _map(dynamic value) =>
      value is Map ? value.cast<String, dynamic>() : const {};

  static DateTime? _date(dynamic value) =>
      value is String ? DateTime.tryParse(value)?.toLocal() : null;
}
