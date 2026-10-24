import 'package:ohara/features/returns/domain/entities/return_eligibility.dart';

/// Parses `GET /returns/eligibility/:sellerOrderId`.
abstract final class ReturnEligibilityMapper {
  static ReturnEligibility fromJson(Map<String, dynamic> json) {
    return ReturnEligibility(
      sellerOrderId: json['seller_order_id'] as String? ?? '',
      orderNumber: json['order_number'] as String? ?? '',
      deliveredAt: _date(json['delivered_at']),
      windowClosesAt: _date(json['window_closes_at']),
      extraWindowDays: (json['extra_window_days'] as num?)?.toInt() ?? 0,
      isWindowOpen: json['is_window_open'] as bool? ?? false,
      lines: [
        for (final line
            in (json['lines'] as List? ?? const []).whereType<Map>())
          _line(line.cast<String, dynamic>()),
      ],
    );
  }

  static ReturnEligibilityLine _line(Map<String, dynamic> json) {
    // Two independent verdicts: a made-to-order dress excluded from a
    // change-of-mind return still comes back if it arrived torn.
    final onFault = _verdict(json['on_fault']);
    final changedMind = _verdict(json['change_of_mind']);

    return ReturnEligibilityLine(
      orderItemId: json['order_item_id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      variant: json['variant'] as String?,
      image: json['image'] as String?,
      quantityOrdered: (json['quantity_ordered'] as num?)?.toInt() ?? 0,
      quantityClaimed: (json['quantity_claimed'] as num?)?.toInt() ?? 0,
      quantityReturnable: (json['quantity_returnable'] as num?)?.toInt() ?? 0,
      onFaultAllowed: onFault.$1,
      onFaultBlocker: onFault.$2,
      changeOfMindAllowed: changedMind.$1,
      changeOfMindBlocker: changedMind.$2,
    );
  }

  /// `{ allowed: bool, blocker: string|null }`, defaulting closed — a verdict
  /// the server did not send is not a permission.
  static (bool, String?) _verdict(Object? raw) {
    if (raw is! Map) return (false, null);
    final map = raw.cast<String, dynamic>();
    return (map['allowed'] as bool? ?? false, map['blocker'] as String?);
  }

  static DateTime? _date(Object? raw) =>
      raw is String ? DateTime.tryParse(raw)?.toLocal() : null;
}
