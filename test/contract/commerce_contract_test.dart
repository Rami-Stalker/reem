import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:reem/core/shared/value_objects/money.dart';
import 'package:reem/features/cart/data/models/cart_model.dart';
import 'package:reem/features/checkout/data/models/checkout_models.dart';
import 'package:reem/features/checkout/data/models/order_models.dart';
import 'package:reem/features/checkout/domain/entities/order.dart';

/// Contract tests for the commerce flow, run against responses captured from a
/// real multi-seller checkout — a basket from two sellers, paid cash on
/// delivery, shipped to Damascus.
Map<String, dynamic> _fixture(String name) =>
    jsonDecode(File('test/contract/$name').readAsStringSync())
        as Map<String, dynamic>;

void main() {
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
        expect(parcel.status.label, isNotEmpty);
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
      expect(order.payment!.methodLabel, 'الدفع عند الاستلام');
      expect(order.payment!.amount.currency, Currency.syp);
    });

    test('cancellation is per parcel, not all-or-nothing', () {
      expect(order.isCancellable, isTrue);
      expect(order.cancellableParcels.length, order.sellerOrders.length);
    });

    test('every status renders an Arabic label', () {
      expect(order.status.label, isNotEmpty);
      for (final parcel in order.sellerOrders) {
        expect(parcel.status.label, isNotEmpty);
        expect(parcel.status.label, isNot(contains('_')));
      }
    });

    test('allItems flattens the parcels for a simple list view', () {
      final total = order.sellerOrders
          .fold<int>(0, (count, parcel) => count + parcel.items.length);
      expect(order.allItems.length, total);
      expect(order.allItems.every((item) => item.sellerName.isNotEmpty), isTrue);
    });
  });
}
