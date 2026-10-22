import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:reem/core/shared/value_objects/money.dart';
import 'package:reem/features/cart/data/models/cart_model.dart';
import 'package:reem/features/checkout/data/models/checkout_models.dart';
import 'package:reem/features/checkout/data/models/order_models.dart';
import 'package:reem/features/checkout/domain/entities/order.dart';
import 'package:reem/features/checkout/presentation/order_labels.dart';
import 'package:reem/l10n/app_localizations_ar.dart';

/// Contract tests for the commerce flow, run against responses captured from a
/// real multi-seller checkout — a basket from two sellers, paid cash on
/// delivery, shipped to Damascus.
Map<String, dynamic> _fixture(String name) =>
    jsonDecode(File('test/contract/$name').readAsStringSync())
        as Map<String, dynamic>;

void main() {
  final ar = AppLocalizationsAr();
  group('cart', () {
    late CartModel cart;

    setUp(() => cart = CartModel.fromJson(_fixture('cart.json')));

    test('every line names the offer it came from, not just a product', () {
      expect(cart.items, isNotEmpty);
      for (final line in cart.items) {
        expect(line.offerId, isNotEmpty,
            reason: 'a line without an offer id cannot be bought');
        expect(line.sellerId, isNotEmpty);
      }
    });

    test('line money parses as Money, never as a silent zero', () {
      // The old parser read `(json['unit_price'] as num?) ?? 0`, so a decimal
      // string became 0 and the cart rendered as free.
      for (final line in cart.items) {
        expect(line.unitPrice.approximateValue, greaterThan(0));
        expect(line.lineTotal.approximateValue, greaterThan(0));
        expect(line.unitPrice.currency, Currency.syp);
      }
    });

    test('a two-seller basket is grouped into two parcels-to-be', () {
      expect(cart.sellerGroups.length, 2);
      expect(cart.willSplit, isTrue);
      expect(cart.summary.sellersCount, cart.sellerGroups.length);
    });

    test('each group subtotal matches its own lines', () {
      for (final group in cart.sellerGroups) {
        final lines = cart.linesFor(group);
        expect(lines, isNotEmpty);

        final sum = lines.fold<double>(
          0,
          (total, line) => total + line.lineTotal.approximateValue,
        );
        expect(group.subtotal!.approximateValue, closeTo(sum, 0.0001));
      }
    });

    test('the summary reports subtotals per currency, not one blended total',
        () {
      expect(cart.summary.subtotalsByCurrency, isNotEmpty);
      expect(cart.summary.subtotal, isNotNull);
      expect(cart.summary.subtotal!.currency, Currency.syp);
    });
  });

  group('placed order', () {
    late OrderDetail order;

    setUp(() {
      final placed = PlacedOrderModel.fromJson(_fixture('placed_order.json'));
      order = placed.order;
    });

    test('one basket became one parent order and two parcels', () {
      expect(order.sellersCount, 2);
      expect(order.sellerOrders.length, 2);
      expect(order.isSplit, isTrue);

      final sellers = order.sellerOrders.map((p) => p.sellerId).toSet();
      expect(sellers.length, 2, reason: 'one parcel per seller');
    });

    test('each parcel carries its own number and status', () {
      for (final parcel in order.sellerOrders) {
        expect(parcel.number, startsWith(order.number));
        expect(parcel.status, isNot(SellerOrderStatus.newOrder));
        expect(ar.customerParcelStatus(parcel.status), isNotEmpty);
      }
    });

    test('the shipping charge splits across parcels without losing a unit', () {
      // The customer pays shipping once (Q65). The server allocates it by
      // largest remainder, so the parts must add back to the parent exactly —
      // this is the invariant that float arithmetic used to break.
      final parts = order.sellerOrders.fold<double>(
        0,
        (total, parcel) => total + parcel.shippingCost.approximateValue,
      );
      expect(parts, closeTo(order.shippingTotal.approximateValue, 0.0001));
    });

    test('the parcel subtotals add up to the order subtotal', () {
      final parts = order.sellerOrders.fold<double>(
        0,
        (total, parcel) => total + parcel.itemsSubtotal.approximateValue,
      );
      expect(parts, closeTo(order.itemsSubtotal.approximateValue, 0.0001));
    });

    test('the exchange rate is frozen onto the order', () {
      expect(order.fxRate, isNotEmpty);
      expect(double.tryParse(order.fxRate), isNotNull);
      expect(order.fxFrozenAt.year, greaterThan(2000));
    });

    test('the grand total is subtotal minus discount plus shipping', () {
      final expected = order.itemsSubtotal.approximateValue -
          order.discountTotal.approximateValue +
          order.shippingTotal.approximateValue;
      // Rounded to the nearest 1000 for SYP (Q48), so allow that step.
      expect(order.grandTotal.approximateValue, closeTo(expected, 1000));
    });

    test('payment carries its method label in Arabic', () {
      expect(order.payment, isNotNull);
      expect(ar.paymentMethodName(order.payment!.method), 'الدفع عند الاستلام');
      expect(order.payment!.amount.currency, Currency.syp);
    });

    test('cancellation is per parcel, not all-or-nothing', () {
      expect(order.isCancellable, isTrue);
      expect(order.cancellableParcels.length, order.sellerOrders.length);
    });

    test('every status renders an Arabic label', () {
      expect(ar.orderStatusLabel(order.status), isNotEmpty);
      for (final parcel in order.sellerOrders) {
        expect(ar.customerParcelStatus(parcel.status), isNotEmpty);
        expect(ar.customerParcelStatus(parcel.status), isNot(contains('_')));
      }
    });

    test('allItems flattens the parcels for a simple list view', () {
      final total = order.sellerOrders
          .fold<int>(0, (count, parcel) => count + parcel.items.length);
      expect(order.allItems.length, total);
      expect(order.allItems.every((item) => item.sellerName.isNotEmpty), isTrue);
    });

    test('an order nobody held carries no assurance block and no flag', () {
      // The captured basket was placed by a customer the trust engine let
      // through, so both must be absent rather than defaulted into something
      // the screen would render.
      final placed = PlacedOrderModel.fromJson(_fixture('placed_order.json'));
      expect(placed.codAssurance, isNull);
      expect(placed.awaitsCodConfirmation, isFalse);
      expect(placed.order.awaitingCodConfirmation, isFalse);
    });
  });

  /// The cash-on-delivery hold, on the wire.
  ///
  /// Written from the serializers rather than captured from a live server, so
  /// it proves the parsers read the shape the backend produces but not that
  /// the two have stayed in step — replace it with a capture the next time a
  /// held order is placed against a running API.
  group('cash-on-delivery assurance', () {
    test('a held order carries the challenge the sheet needs', () {
      final placed = PlacedOrderModel.fromJson({
        'order': _fixture('placed_order.json')['order'],
        'redirect_url': null,
        'requires_online_confirmation': false,
        'cod_assurance': {
          'required': 'order_confirmation',
          'message': 'أرسلنا رمزاً إلى رقم التوصيل للتأكد من الطلب.',
          'otp_request_id': '0f1e2d3c-4b5a-6978-8796-a5b4c3d2e1f0',
          'match_code': '47',
          'masked_destination': '+9639•••••901',
          'expires_at': '2026-09-01T10:30:00.000Z',
          'resend_after': '2026-09-01T10:01:00.000Z',
          'channel': 'whatsapp',
        },
      });

      expect(placed.awaitsCodConfirmation, isTrue);
      final assurance = placed.codAssurance!;
      expect(assurance.required, 'order_confirmation');
      expect(assurance.message, isNotEmpty);
      // The two digits she compares against the message. Losing this to a key
      // typo would silently drop the only defence against a code read out over
      // the phone.
      expect(assurance.matchCode, '47');
      expect(assurance.maskedDestination, isNotNull);
      expect(assurance.expiresAt, isNotNull);
      expect(assurance.dispatchFailed, isFalse);
    });

    test('a challenge that never went out says so, and still holds the order',
        () {
      final placed = PlacedOrderModel.fromJson({
        'order': _fixture('placed_order.json')['order'],
        'requires_online_confirmation': false,
        'cod_assurance': {
          'required': 'order_confirmation',
          'message': 'أرسلنا رمزاً إلى رقم التوصيل للتأكد من الطلب.',
          'dispatch_failed': true,
        },
      });

      expect(placed.awaitsCodConfirmation, isTrue);
      expect(placed.codAssurance!.dispatchFailed, isTrue);
      expect(placed.codAssurance!.matchCode, isNull);
    });

    test('the order detail carries one boolean and never a score', () {
      final detail = OrderDetailModel.fromJson({
        ..._fixture('order_detail.json'),
        'awaiting_cod_confirmation': true,
      });
      expect(detail.awaitingCodConfirmation, isTrue);
    });
  });
}
