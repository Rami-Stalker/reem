import 'package:equatable/equatable.dart';

import 'package:reem/core/shared/value_objects/money.dart';

/// Q51 — a bank transfer or hawala waiting for finance to match it.
class PendingTransfer extends Equatable {
  const PendingTransfer({
    required this.paymentId,
    required this.orderNumber,
    required this.method,
    required this.amount,
    this.reference,
    this.customerName,
    this.customerPhone,
    this.submittedAt,
    this.expiresAt,
  });

  final String paymentId;
  final String orderNumber;

  /// bank_transfer | hawala
  final String method;
  final Money amount;

  /// What she typed from her receipt; null until she has sent it.
  final String? reference;
  final String? customerName;
  final String? customerPhone;
  final DateTime? submittedAt;

  /// When the order lets its stock go if nobody confirms it.
  final DateTime? expiresAt;

  @override
  List<Object?> get props => [paymentId, reference, expiresAt];
}
