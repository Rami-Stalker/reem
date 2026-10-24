import 'package:ohara/core/shared/value_objects/money.dart';
import 'package:ohara/features/invoices/domain/entities/invoice.dart';

/// Wire → domain. Every figure stays a [Money]; none passes through `double`.
class InvoiceModel extends Invoice {
  const InvoiceModel({
    required super.id,
    required super.number,
    required super.kind,
    required super.issuedAt,
    required super.orderNumber,
    required super.currency,
    required super.itemsSubtotal,
    required super.discountTotal,
    required super.shippingTotal,
    required super.grandTotal,
    super.sellerOrderNumber,
    super.placedAt,
    super.recipient,
    super.couponCode,
    super.commissionAmount,
    super.sellerNet,
    super.lines,
  });

  factory InvoiceModel.fromJson(Map<String, dynamic> json) {
    final currency = Currency.fromWire(json['currency'] as String?);
    final totals = json['totals'] as Map<String, dynamic>? ?? const {};
    Money at(String key) => Money.fromJson(totals[key], fallback: currency);

    return InvoiceModel(
      id: json['id'] as String? ?? '',
      number: json['number'] as String? ?? '',
      kind: InvoiceKind.fromWire(json['kind'] as String?),
      issuedAt: _date(json['issued_at']) ?? DateTime.now(),
      orderNumber: json['order_number'] as String? ?? '',
      sellerOrderNumber: json['seller_order_number'] as String?,
      placedAt: _date(json['placed_at']),
      couponCode: json['coupon_code'] as String?,
      currency: currency,
      itemsSubtotal: at('items_subtotal'),
      discountTotal: at('discount_total'),
      shippingTotal: at('shipping_total'),
      grandTotal: at('grand_total'),
      // Null on the customer's copy, by design.
      commissionAmount: totals['commission_amount'] == null
          ? null
          : Money.fromJson(totals['commission_amount'], fallback: currency),
      sellerNet: totals['seller_net'] == null
          ? null
          : Money.fromJson(totals['seller_net'], fallback: currency),
      recipient: json['billed_to'] is Map<String, dynamic>
          ? _recipient(json['billed_to'] as Map<String, dynamic>)
          : null,
      lines: (json['lines'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map((row) => _line(row, currency))
          .toList(growable: false),
    );
  }

  static InvoiceRecipient _recipient(Map<String, dynamic> json) {
    return InvoiceRecipient(
      name: json['name'] as String? ?? '',
      phone: json['phone'] as String? ?? '',
      governorate: json['governorate'] as String? ?? '',
      city: json['city'] as String? ?? '',
      addressLine: json['address_line'] as String? ?? '',
    );
  }

  static InvoiceLine _line(Map<String, dynamic> json, Currency currency) {
    return InvoiceLine(
      title: json['title'] as String? ?? '',
      variant: json['variant'] as String?,
      seller: json['seller'] as String?,
      quantity: json['quantity'] as int? ?? 1,
      unitPrice: Money.fromJson(json['unit_price'], fallback: currency),
      unitDiscount: Money.fromJson(json['unit_discount'], fallback: currency),
      lineTotal: Money.fromJson(json['line_total'], fallback: currency),
    );
  }

  static DateTime? _date(dynamic value) =>
      value is String ? DateTime.tryParse(value) : null;
}

/// The list rows raised against one order.
class InvoiceSummaryModel extends InvoiceSummary {
  const InvoiceSummaryModel({
    required super.id,
    required super.number,
    required super.kind,
    required super.issuedAt,
    required super.grandTotal,
  });

  factory InvoiceSummaryModel.fromJson(Map<String, dynamic> json) {
    final currency = Currency.fromWire(json['currency'] as String?);
    return InvoiceSummaryModel(
      id: json['id'] as String? ?? '',
      number: json['number'] as String? ?? '',
      kind: InvoiceKind.fromWire(json['kind'] as String?),
      issuedAt:
          DateTime.tryParse(json['issuedAt'] as String? ?? '') ??
          DateTime.tryParse(json['issued_at'] as String? ?? '') ??
          DateTime.now(),
      grandTotal: Money.fromJson(
        json['grandTotal'] ?? json['grand_total'],
        fallback: currency,
      ),
    );
  }
}
