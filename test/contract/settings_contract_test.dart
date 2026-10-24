import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ohara/core/shared/value_objects/money.dart';
import 'package:ohara/features/checkout/presentation/providers/applied_coupon_provider.dart';
import 'package:ohara/features/settings/data/models/address_model.dart';
import 'package:ohara/features/settings/data/models/coupon_model.dart';
import 'package:ohara/features/settings/domain/entities/address_draft.dart';
import 'package:ohara/features/settings/domain/entities/coupon_entity.dart';
import 'package:ohara/features/settings/domain/entities/coupon_validation.dart';

/// Contract tests for the settings surface, against the shapes
/// `serializeAddress` and the rewards `serializeCoupon` actually emit.
///
/// Both screens behind these used to render invented data — four hardcoded
/// addresses and four invented coupon codes priced in dollars — so nothing
/// here was ever exercised against a real payload.
List<dynamic> _fixture(String name) =>
    jsonDecode(File('test/contract/$name').readAsStringSync()) as List<dynamic>;

void main() {
  group('address book', () {
    late List<AddressModel> addresses;

    setUp(() {
      addresses = _fixture('addresses.json')
          .map((e) => AddressModel.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    });

    test('an address carries everything a Syrian delivery is priced by', () {
      final home = addresses.first;
      expect(home.governorate, 'دمشق');
      expect(home.district, 'المزة');
      expect(home.isRural, isFalse);
      expect(home.isDefault, isTrue);
      expect(home.deliveryInstructions, 'اتصلي قبل الوصول');
    });

    test('the rural tier survives the round trip', () {
      // Q53 prices the rural tier differently, so losing this flag on the way
      // in quotes a village at a city fee.
      expect(addresses.last.isRural, isTrue);
    });

    test('nulls stay null rather than becoming empty strings', () {
      expect(addresses.last.landmark, isNull);
      expect(addresses.last.deliveryInstructions, isNull);
    });

    test('the summary reads as an address, not as a field dump', () {
      expect(addresses.first.summary, contains('دمشق'));
      expect(addresses.first.summary, contains('المزة'));
      expect(addresses.first.summary, contains('شارع الجلاء'));
    });

    test('a write body sends cleared optional fields as explicit nulls', () {
      // The server's UpdateAddressDto treats an absent key as "leave it
      // alone", so omitting a landmark she has just cleared would keep the
      // old one forever.
      final draft = AddressDraft.from(addresses.first).copyWith(landmark: '');
      final body = AddressModel.bodyFrom(draft);

      expect(body.containsKey('landmark'), isTrue);
      expect(body['landmark'], isNull);
    });

    test('a write body never sends an id', () {
      // The server assigns it; echoing one on create is how a client asks to
      // overwrite a row it does not own.
      final body = AddressModel.bodyFrom(AddressDraft.from(addresses.first));
      expect(body.containsKey('id'), isFalse);
    });

    test('a write body trims what she typed', () {
      final draft = AddressDraft.from(
        addresses.first,
      ).copyWith(governorate: '  دمشق  ', city: ' دمشق ');
      final body = AddressModel.bodyFrom(draft);

      // A governorate with a trailing space matches no delivery zone, so the
      // address would quote nothing and be assignable to no courier.
      expect(body['governorate'], 'دمشق');
      expect(body['city'], 'دمشق');
    });

    test('editing opens with the values already saved', () {
      final draft = AddressDraft.from(addresses.last);
      expect(draft.label, 'بيت أهلي');
      expect(draft.recipientPhone, '0937654321');
      expect(draft.isRural, isTrue);
      expect(draft.isDefault, isFalse);
    });
  });

  group('coupons', () {
    late List<CouponModel> coupons;

    setUp(() {
      coupons = _fixture('coupons.json')
          .map((e) => CouponModel.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    });

    test('a percentage coupon parses as one', () {
      final percent = coupons.first;
      expect(percent.kind, CouponKind.percent);
      expect(percent.discountPercent, 20);
    });

    test('a fixed-amount coupon keeps its amount', () {
      // `amount_off` is a Decimal column and crosses the wire as the string
      // "5000". Reading it with `as num?` returns null, which is how a gift
      // coupon renders as «خصم ٠».
      final fixed = coupons[1];
      expect(fixed.kind, CouponKind.fixed);
      expect(fixed.amountOff, 5000);
    });

    test('a decimal minimum is a number, not a dropped string', () {
      expect(coupons.first.minOrderAmount, 50000);
      expect(coupons[1].minOrderAmount, isNull);
    });

    test('a coupon issued to her alone says so', () {
      expect(coupons.first.isUserSpecific, isFalse);
      expect(coupons[1].isUserSpecific, isTrue);
    });

    test('remaining uses come off the cap', () {
      expect(coupons.first.remainingUses, 88);
      expect(coupons[1].remainingUses, 1);
    });

    test('an exhausted coupon is not offered, however active it says it is', () {
      // The server filters by `is_active` and expiry but not by usage, so a
      // coupon at its cap arrives looking perfectly good and is refused the
      // moment she tries it.
      final spent = coupons.last;
      expect(spent.isActive, isTrue);
      expect(spent.isExpired, isFalse);
      expect(spent.isExhausted, isTrue);
      expect(spent.isRedeemable, isFalse);
    });

    test('an uncapped coupon has no remaining count to show', () {
      final uncapped = CouponModel.fromJson({
        'id': 'e4f5a6b7-c8d9-4e0f-1a2b-3c4d5e6f7081',
        'code': 'OPEN',
        'title': 'بلا سقف',
        'type': 'percentage',
        'discount_percent': 10,
        'max_uses': null,
        'used_count': 40,
        'expires_at': '2026-12-31T20:59:59.000Z',
        'is_active': true,
      });
      expect(uncapped.remainingUses, isNull);
      expect(uncapped.isExhausted, isFalse);
      expect(uncapped.isRedeemable, isTrue);
    });

    test('a validate response names the discount in real money', () {
      // `POST /coupons/validate` answers with `Money.toJSON()`, whose amount
      // is a decimal *string*. The figure shown to her — «وفّرتِ ١٤٬٠٠٠ ل.س» —
      // is this one, and it must be the server's arithmetic, not the client's:
      // the coupon may cap the amount, and a percentage worked out here would
      // disagree with the invoice the order raises.
      final json =
          jsonDecode(
                File('test/contract/coupon_validate.json').readAsStringSync(),
              )
              as Map<String, dynamic>;

      final discount = Money.tryFromJson(json['discount']);
      expect(discount, isNotNull);
      expect(discount!.approximateValue, 14000);
      expect(discount.currency, Currency.syp);
      expect(CouponModel.kindFromWire(json['type']), CouponKind.percent);
    });

    test('an unknown discount type degrades instead of throwing', () {
      final odd = CouponModel.fromJson({
        'id': 'f5a6b7c8-d9e0-4f1a-2b3c-4d5e6f708192',
        'code': 'FUTURE',
        'title': 'نوع جديد',
        'type': 'buy_one_get_one',
        'expires_at': '2026-12-31T20:59:59.000Z',
        'is_active': true,
      });
      expect(odd.kind, CouponKind.unknown);
      expect(odd.title, 'نوع جديد');
    });
  });

  group('applying a coupon to a basket', () {
    Money syp(String amount) => Money(raw: amount, currency: Currency.syp);

    CouponValidation validation(String amount) => CouponValidation(
      code: 'REEM20',
      kind: CouponKind.percent,
      discount: syp(amount),
    );

    late AppliedCouponNotifier notifier;

    setUp(() => notifier = AppliedCouponNotifier());
    tearDown(() => notifier.dispose());

    test('applying remembers the basket it was quoted against', () {
      notifier.apply(validation('14000'), syp('70000'));

      expect(notifier.state?.code, 'REEM20');
      expect(notifier.state?.discount.approximateValue, 14000);
      expect(notifier.state?.subtotal.approximateValue, 70000);
    });

    test('the same basket keeps the coupon', () {
      notifier.apply(validation('14000'), syp('70000'));
      notifier.invalidateForBasket(syp('70000'));

      expect(notifier.state, isNotNull);
    });

    test('a changed basket drops it rather than quoting a stale figure', () {
      // She applied at 70,000 and then removed a line. Keeping «وفّرتِ ١٤٬٠٠٠»
      // on screen would be a promise the order will not keep — and the basket
      // may now fall under the coupon's own minimum.
      notifier.apply(validation('14000'), syp('70000'));
      notifier.invalidateForBasket(syp('40000'));

      expect(notifier.state, isNull);
    });

    test('an emptied basket drops it', () {
      notifier.apply(validation('14000'), syp('70000'));
      notifier.invalidateForBasket(null);

      expect(notifier.state, isNull);
    });

    test('invalidating with nothing applied is harmless', () {
      notifier.invalidateForBasket(syp('40000'));
      expect(notifier.state, isNull);
    });

    test('removing it clears the choice', () {
      notifier.apply(validation('14000'), syp('70000'));
      notifier.clear();
      expect(notifier.state, isNull);
    });
  });
}
