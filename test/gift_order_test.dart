// «إرسال كهدية»: what the app sends for a gift and reads back, and that cash
// at the door is never offered for one.
//
//   flutter test test/gift_order_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:ohara/features/checkout/domain/entities/checkout.dart';
import 'package:ohara/features/checkout/domain/entities/order.dart';

void main() {
  test('a signed gift sends its card, wrapping and signature', () {
    const gift = OrderGift(message: 'كل عام وإنتِ بخير', fromName: 'ريم');
    expect(gift.toJson(), {
      'message': 'كل عام وإنتِ بخير',
      'from_name': 'ريم',
      'anonymous': false,
      'wrap': true,
      'hide_prices': true,
    });
  });

  test('an anonymous gift sends no name', () {
    const gift = OrderGift(message: 'هدية', fromName: null, wrap: false);
    final json = gift.toJson();
    expect(json.containsKey('from_name'), isFalse);
    expect(json['anonymous'], isTrue);
    expect(json['wrap'], isFalse);
  });

  test('the server’s gift reads back, and an ordinary order has none', () {
    final gift = OrderGift.fromJson({
      'message': 'لأحلى أم',
      'from_name': null,
      'anonymous': true,
      'wrap': true,
      'hide_prices': false,
    });
    expect(gift?.isAnonymous, isTrue);
    expect(gift?.hidePrices, isFalse);
    expect(OrderGift.fromJson(null), isNull);
  });

  test('cash at the door is recognised, so a gift never offers it', () {
    const cod = PaymentMethodOption(
      method: 'cod',
      label: 'COD',
      requiresOnlineConfirmation: false,
    );
    const wallet = PaymentMethodOption(
      method: 'platform_wallet',
      label: 'W',
      requiresOnlineConfirmation: false,
    );
    expect(cod.isCashAtDoor, isTrue);
    expect(wallet.isCashAtDoor, isFalse);
  });

  test('a parcel status is spelled the way the server spells it', () {
    expect(SellerOrderStatus.newOrder.wire, 'new');
    expect(SellerOrderStatus.readyToShip.wire, 'ready_to_ship');
    expect(
      SellerOrderStatus.fromWire(SellerOrderStatus.handedToCourier.wire),
      SellerOrderStatus.handedToCourier,
    );
  });
}
