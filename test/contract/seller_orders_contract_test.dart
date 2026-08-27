import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:reem/core/shared/value_objects/money.dart';
import 'package:reem/features/seller_orders/data/models/seller_order_models.dart';
import 'package:reem/features/seller_orders/domain/entities/seller_order.dart';
import 'package:reem/features/seller_orders/presentation/seller_order_labels.dart';
import 'package:reem/l10n/app_localizations.dart';
import 'package:reem/l10n/app_localizations_ar.dart';

/// Contract tests for the seller's order queue, against the shape
/// `SellerOrdersService` serialises.
///
/// The queue is the screen a seller runs her shop from, and almost everything
/// that can go wrong with it is a parsing problem that looks like a design
/// problem: money read as zero renders a free order, a missed `is_masked`
/// renders a privacy leak as a blank field, and an unknown action renders a
/// button the server will refuse.
Map<String, dynamic> _fixture(String name) =>
    jsonDecode(File('test/contract/$name').readAsStringSync())
        as Map<String, dynamic>;

void main() {
  group('the queue', () {
    late SellerOrderQueue queue;

    setUp(
      () => queue = SellerOrderMapper.queueFromJson(
        _fixture('seller_order_queue.json'),
      ),
    );

    test('counts come from the shop, not from the loaded page', () {
      // Two rows on the page, six parcels behind the badges. A badge computed
      // from `orders.length` would drop as she scrolled.
      expect(queue.orders.length, 2);
      expect(queue.countFor(SellerQueueTab.newOrders), 3);
      expect(queue.countFor(SellerQueueTab.completed), 27);
      expect(queue.countFor(SellerQueueTab.shipping), 0);
    });

    test('the attention count is the work waiting on her', () {
      // new + preparing + returns — the three piles nobody else can clear.
      expect(queue.needsAttention, 3 + 1 + 1);
    });

    test('money parses as Money, never as a silent zero', () {
      for (final order in queue.orders) {
        expect(order.net.approximateValue, greaterThan(0));
        expect(order.commission.approximateValue, greaterThan(0));
        expect(order.net.currency, Currency.syp);
      }
    });

    test('an unknown action is dropped, not rendered', () {
      // The fixture carries a "teleport" the client has never heard of. A
      // future server action must not become a button this build cannot run.
      final selfShipped = queue.orders[1];
      expect(selfShipped.actions, [
        SellerOrderAction.handOver,
        SellerOrderAction.cancel,
      ]);
    });

    test('the primary action is never the destructive one', () {
      // The card leads with the move that advances the sale; cancelling is
      // always the quiet one beside it, never the button under her thumb.
      final selfShipped = queue.orders[1];
      expect(selfShipped.primaryAction, SellerOrderAction.handOver);
      expect(queue.orders.first.primaryAction, SellerOrderAction.confirm);
    });

    test('a courier parcel hides the customer and says why', () {
      final courierParcel = queue.orders.first;
      final customer = courierParcel.customer;

      expect(customer.isMasked, isTrue);
      expect(customer.phone, isNull);
      expect(customer.addressLine, isNull);
      expect(customer.hasAddress, isFalse);

      // Q57 still gives her the governorate — she has to pack for a distance.
      expect(customer.governorate, 'دمشق');
      // …and an explanation, so a blank address does not read as a bug.
      expect(customer.maskedBecause, isNotNull);
      expect(customer.maskedBecause, contains('المندوب'));
    });

    test('a self-shipped parcel gives her the door she has to reach', () {
      final own = queue.orders[1];
      expect(own.fulfilmentMode.isSelfCarried, isTrue);
      expect(own.customer.isMasked, isFalse);
      expect(own.customer.phone, '+963900111222');
      expect(own.customer.hasAddress, isTrue);
      expect(own.customer.addressSummary, contains('شارع النيل'));
    });

    test('cash on delivery is distinguishable from an already-paid parcel', () {
      expect(queue.orders.first.isCashOnDelivery, isTrue);
      expect(queue.orders.first.isPaid, isFalse);
      expect(queue.orders[1].isCashOnDelivery, isFalse);
      expect(queue.orders[1].isPaid, isTrue);
    });
  });

  group('one parcel', () {
    late SellerOrderDetail order;

    setUp(
      () => order = SellerOrderMapper.detailFromJson(
        _fixture('seller_order_detail.json'),
      ),
    );

    test('the lines are what she has to pack', () {
      expect(order.items.length, 2);
      expect(order.items.first.quantity, 2);
      expect(order.items.first.variant, 'مقاس M');
      for (final item in order.items) {
        expect(item.lineTotal.approximateValue, greaterThan(0));
      }
    });

    test('a made-to-order instruction survives the wire', () {
      // Q30 — losing this is the difference between the right parcel and a
      // returned one.
      final scarf = order.items.last;
      expect(scarf.customisation, isNotNull);
      expect(scarf.customisation!['التطريز'], 'ر.د');
    });

    test('the lines add up to the subtotal', () {
      final sum = order.items.fold<double>(
        0,
        (total, item) => total + item.lineTotal.approximateValue,
      );
      expect(sum, closeTo(order.itemsSubtotal.approximateValue, 0.0001));
    });

    test('her net plus the commission is the base it was charged on', () {
      // Not "subtotal minus discount": a platform-funded coupon (Q49 P2)
      // leaves the base at the full price, because the seller sold at full
      // price and the platform paid the difference. Asserting against what the
      // customer handed over would make this test demand that she absorb every
      // promotion the platform runs.
      final split =
          order.summary.net.approximateValue +
          order.summary.commission.approximateValue;
      expect(split, closeTo(order.commissionBase.approximateValue, 0.0001));
    });

    test('the escrow clock is read from delivery, not from payment', () {
      expect(order.deliveredAt, isNotNull);
      expect(order.escrowReleaseAt, isNotNull);
      expect(order.escrowReleased, isFalse);

      final days = order.escrowReleaseAt!
          .difference(order.deliveredAt!)
          .inDays;
      expect(days, 7, reason: 'Q56 counts seven days from receipt');
    });

    test('the journey timestamps arrive in order', () {
      expect(order.confirmedAt!.isAfter(order.summary.placedAt), isTrue);
      expect(order.shippedAt!.isAfter(order.confirmedAt!), isTrue);
      expect(order.deliveredAt!.isAfter(order.shippedAt!), isTrue);
    });

    test('a delivered parcel offers her nothing more to do', () {
      expect(order.actions, isEmpty);
      expect(order.summary.primaryAction, isNull);
    });

    test('the shipment carries its tracking code and courier state', () {
      expect(order.shipment, isNotNull);
      expect(order.shipment!.trackingCode, startsWith('REM-'));
      expect(order.shipment!.isAssigned, isTrue);
    });
  });

  group('wording', () {
    // The words themselves live in the ARB bundles and are guarded by
    // `test/localization_test.dart` — including the rule that every Arabic
    // string addresses a woman (Q69 P2). What belongs here is the mapping:
    // every state, action and tab must resolve to *something*, because a
    // missing case would render an empty chip rather than fail a build.
    late AppLocalizations ar;

    setUp(() => ar = AppLocalizationsAr());

    test('every state, action and tab has wording', () {
      for (final status in SellerOrderStatus.values) {
        expect(ar.parcelStatus(status), isNotEmpty);
      }
      for (final action in SellerOrderAction.values) {
        expect(ar.parcelAction(action), isNotEmpty);
        expect(ar.parcelActionDone(action), isNotEmpty);
      }
      for (final tab in SellerQueueTab.values) {
        expect(ar.queueTab(tab), isNotEmpty);
        expect(ar.queueEmptyTitle(tab), isNotEmpty);
        expect(ar.queueEmptyBody(tab), isNotEmpty);
      }
      for (final mode in FulfilmentMode.values) {
        expect(ar.fulfilmentMode(mode), isNotEmpty);
      }
    });

    test('the seller reads her own words, not the customer’s', () {
      // The same state, spoken by two different people. «ألغيتِ الطلب» is true
      // for the woman who cancelled and wrong for the woman reading her queue.
      expect(
        ar.parcelStatus(SellerOrderStatus.cancelledByCustomer),
        isNot(SellerOrderStatus.cancelledByCustomer.label),
      );
      expect(
        ar.parcelStatus(SellerOrderStatus.cancelledByCustomer),
        'ألغته الزبونة',
      );
    });

    test('pressing a button and having pressed it read differently', () {
      // "قبول الطلب" is a request; "قبلتِ الطلب" is a fact. Confirming with
      // the button's own label is how an app makes a woman press it twice.
      expect(
        ar.parcelActionDone(SellerOrderAction.confirm),
        isNot(ar.parcelAction(SellerOrderAction.confirm)),
      );
    });
  });
}
