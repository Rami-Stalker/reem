import 'package:ohara/core/shared/value_objects/money.dart';
import 'package:ohara/features/admin_finance/domain/entities/pending_transfer.dart';

class PendingTransferModel extends PendingTransfer {
  const PendingTransferModel({
    required super.paymentId,
    required super.orderNumber,
    required super.method,
    required super.amount,
    super.reference,
    super.customerName,
    super.customerPhone,
    super.submittedAt,
    super.expiresAt,
  });

  factory PendingTransferModel.fromJson(Map<String, dynamic> json) {
    final currency = Currency.fromWire(json['currency'] as String?);
    DateTime? at(Object? value) =>
        value is String ? DateTime.tryParse(value)?.toLocal() : null;

    return PendingTransferModel(
      paymentId: json['id'] as String,
      orderNumber: json['order_number'] as String? ?? '',
      method: json['method'] as String? ?? '',
      amount: Money.fromJson(json['amount'], fallback: currency),
      reference: json['provider_ref'] as String?,
      customerName: json['customer_name'] as String?,
      customerPhone: json['customer_phone'] as String?,
      submittedAt: at(json['reference_submitted_at']),
      expiresAt: at(json['expires_at']),
    );
  }
}
