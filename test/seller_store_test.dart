// The seller's store pages: where she is paid (Sham Cash or Visa only), her
// monthly report, and the words her activity log uses.
//
//   flutter test test/seller_store_test.dart
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ohara/features/seller_earnings/data/models/seller_earnings_model.dart';
import 'package:ohara/features/seller_earnings/domain/entities/seller_earnings.dart';
import 'package:ohara/features/seller_earnings/presentation/screens/seller_payout_settings_screen.dart';
import 'package:ohara/features/seller_store/data/models/seller_store_models.dart';
import 'package:ohara/features/seller_store/presentation/screens/store_activity_screen.dart';
import 'package:ohara/l10n/app_localizations_ar.dart';

final _l10n = AppLocalizationsAr();

void main() {
  group('where she is paid', () {
    test('a Visa number must be Visa and pass its checksum', () {
      expect(isValidVisa('4111111111111111'), isTrue);
      expect(isValidVisa('4111111111111112'), isFalse, reason: 'checksum');
      expect(isValidVisa('5555555555554444'), isFalse, reason: 'Mastercard');
      expect(isValidVisa('4111'), isFalse);
    });

    test('a Sham Cash wallet is a 09 phone, in any spelling, or a code', () {
      expect(isValidShamCash('0933118204'), isTrue);
      expect(isValidShamCash('+963 933 118 204'), isTrue);
      expect(isValidShamCash('SC12345'), isTrue);
      expect(isValidShamCash('12'), isFalse);
    });

    test('the card number groups in fours as she types', () {
      const formatter = CardNumberFormatter();
      final value = formatter.formatEditUpdate(
        TextEditingValue.empty,
        const TextEditingValue(text: '4111111111111111'),
      );
      expect(value.text, '4111 1111 1111 1111');
    });

    test('availability says when nowhere is set to be paid', () {
      final availability = SellerEarningsModel.availabilityFromJson({
        'currency': 'SYP',
        'claimable': {'amount': '0', 'currency': 'SYP'},
        'can_request': false,
        'blocked_by': 'no_payout_account',
        'payout_account': null,
      });
      expect(availability.blockedBy, PayoutBlocker.noPayoutAccount);
      expect(availability.payoutAccount, isNull);
    });

    test('the saved account comes back masked', () {
      final account = SellerEarningsModel.accountFromJson({
        'method': 'visa',
        'holder_name': 'ريم',
        'masked': '•••• 1111',
      });
      expect(account?.method, PayoutMethod.visa);
      expect(account?.masked, '•••• 1111');
    });
  });

  test('the monthly report reads every month and the totals', () {
    final report = SellerEarningsModel.reportFromJson({
      'currency': 'SYP',
      'months': [
        {
          'month': '2026-11',
          'orders': 2,
          'gross': {'amount': '12000', 'currency': 'SYP'},
          'commission': {'amount': '1000', 'currency': 'SYP'},
          'platform_fees': {'amount': '0', 'currency': 'SYP'},
          'net': {'amount': '11000', 'currency': 'SYP'},
          'reversed_orders': 0,
          'reversed': {'amount': '0', 'currency': 'SYP'},
          'paid_out': {'amount': '5000', 'currency': 'SYP'},
        },
        {'month': '2026-10', 'orders': 0},
      ],
      'totals': {
        'orders': 2,
        'net': {'amount': '11000', 'currency': 'SYP'},
      },
    });
    expect(report.months.first.month, DateTime(2026, 11));
    expect(report.months.first.net.approximateValue, 11000);
    expect(report.months.last.isEmpty, isTrue);
    expect(report.totals.orders, 2);
    expect(report.isEmpty, isFalse);
  });

  group('the activity log', () {
    test('names what was done', () {
      expect(
        describeActivity(_l10n, 'POST /seller/orders/:id/confirm').$1,
        _l10n.actOrderConfirm,
      );
      expect(
        describeActivity(_l10n, 'PUT /finance/seller/payout-account').$1,
        _l10n.actPayoutAccount,
      );
      expect(describeActivity(_l10n, 'login').$1, _l10n.actLogin);
      expect(
        describeActivity(_l10n, 'PATCH /something/new').$1,
        _l10n.actGeneric,
      );
    });

    test('a sign-in is a success whatever case the server used', () {
      final page = SellerStoreMapper.activity({
        'data': [
          {'id': '1', 'action': 'login', 'outcome': 'success'},
          {'id': '2', 'action': 'login', 'outcome': 'FAILED_403'},
        ],
      });
      expect(page.entries.map((e) => e.succeeded), [true, false]);
      expect(page.nextBefore, isNull);
    });
  });
}
