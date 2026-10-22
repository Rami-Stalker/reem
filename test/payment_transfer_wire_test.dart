import 'package:flutter_test/flutter_test.dart';
import 'package:reem/features/admin_finance/data/models/pending_transfer_model.dart';
import 'package:reem/features/checkout/data/models/checkout_models.dart';
import 'package:reem/features/checkout/data/models/order_models.dart';

/// The wire shapes behind Q51's transfer flow, as the API sends them.
void main() {
  test('a transfer rail carries the instructions finance set', () {
    final option = PaymentMethodOptionModel.fromJson({
      'method': 'hawala',
      'label': 'حوالة داخلية',
      'requires_online_confirmation': true,
      'rail': 'manual',
      'instructions': 'مكتب الهرم — باسم ريم للتجارة',
    });
    expect(option.instructions, 'مكتب الهرم — باسم ريم للتجارة');

    final cash = PaymentMethodOptionModel.fromJson({
      'method': 'cod',
      'label': 'الدفع عند الاستلام',
      'requires_online_confirmation': false,
      'rail': 'cash',
      'instructions': null,
    });
    expect(cash.instructions, isNull);
  });

  test('a reference finance sent back reaches the payment card', () {
    final payment = OrderPaymentModel.fromJson({
      'id': 'p1',
      'method': 'hawala',
      'status': 'pending',
      'currency': 'SYP',
      'amount': {'amount': '25000.0000', 'currency': 'SYP'},
      'captured_amount': {'amount': '0.0000', 'currency': 'SYP'},
      'refunded_amount': {'amount': '0.0000', 'currency': 'SYP'},
      'rail': 'manual',
      'provider_ref': null,
      'failure_reason': 'الرقم غير موجود لدى المكتب',
    });
    expect(payment.failureReason, 'الرقم غير موجود لدى المكتب');
    expect(payment.isPending, isTrue);
  });

  test('the finance queue reads one waiting transfer', () {
    final transfer = PendingTransferModel.fromJson({
      'id': 'p1',
      'method': 'bank_transfer',
      'currency': 'SYP',
      'amount': {'amount': '25000.0000', 'currency': 'SYP'},
      'provider_ref': 'BNK-8812',
      'order_number': 'REEM-ABC123',
      'customer_name': 'ريم',
      'customer_phone': '+963900000000',
      'expires_at': '2026-10-25T08:00:00.000Z',
      'reference_submitted_at': '2026-10-22T08:00:00.000Z',
    });
    expect(transfer.orderNumber, 'REEM-ABC123');
    expect(transfer.reference, 'BNK-8812');
    expect(transfer.amount.format(), isNotEmpty);
    expect(transfer.expiresAt, isNotNull);
  });
}
