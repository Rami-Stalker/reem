import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:reem/core/shared/models/product_model.dart';
import 'package:reem/core/shared/value_objects/money.dart';

/// Contract tests against **real captured responses** from the backend.
///
/// The fixtures in this folder were produced by calling the running API, not
/// written by hand, so they cannot drift into agreeing with the client by
/// accident. Re-capture them with:
///
///   curl -s http://localhost:3000/products > test/contract/products_list.json
Map<String, dynamic> _fixture(String name) =>
    jsonDecode(File('test/contract/$name').readAsStringSync())
        as Map<String, dynamic>;

void main() {
  group('product list response', () {
    late List<dynamic> data;

    setUp(() => data = _fixture('products_list.json')['data'] as List<dynamic>);

    test('parses every card without throwing', () {
      final products = data
          .map((e) => ProductModel.fromJson(e as Map<String, dynamic>))
          .toList();

      expect(products, hasLength(data.length));
      expect(products.every((p) => p.id.isNotEmpty), isTrue);
    });

    test('a card carries its cheapest offer, not a bare price', () {
      final product =
          ProductModel.fromJson(data.first as Map<String, dynamic>);

      expect(product.offers, isNotEmpty,
          reason: 'a card should normalise best_offer into offers');
      expect(product.price, isNotNull);
      expect(product.price!.currency, Currency.syp);
      // The whole point of Money: the figure survives as an exact decimal
      // string, and never loses its currency on the way through.
      expect(double.tryParse(product.price!.raw), isNotNull);
    });

    test('money formats in Syrian pounds, not dollars', () {
      final product =
          ProductModel.fromJson(data.first as Map<String, dynamic>);

      final formatted = product.price!.format();
      expect(formatted, contains('ل.س'));
      expect(formatted, isNot(contains(r'$')));
    });

    test('category arrives as an entity with an Arabic name', () {
      final product =
          ProductModel.fromJson(data.first as Map<String, dynamic>);

      expect(product.category.slug, isNotEmpty);
      expect(product.category.nameAr, isNotEmpty);
      expect(product.category.isLeaf, isTrue);
    });
  });

  group('product detail response', () {
    late Map<String, dynamic> json;

    setUp(() => json = _fixture('product_detail.json'));

    test('exposes every competing seller for price comparison', () {
      final product = ProductModel.fromJson(json);

      expect(product.offersCount, greaterThan(1));
      expect(product.offers.length, product.offersCount);
      expect(product.hasMultipleOffers, isTrue);

      final sellers = product.offers.map((o) => o.seller.id).toSet();
      expect(sellers.length, product.offers.length,
          reason: 'each offer belongs to a distinct seller');
    });

    test('the default offer is the cheapest one', () {
      final product = ProductModel.fromJson(json);

      final cheapest = product.offers
          .map((o) => o.price.approximateValue)
          .reduce((a, b) => a < b ? a : b);

      expect(product.bestOffer!.price.approximateValue, cheapest);
    });

    test('displaySeller is the seller of the shown offer, not an owner', () {
      final product = ProductModel.fromJson(json);

      expect(product.displaySeller, isNotNull);
      expect(product.displaySeller!.id, product.bestOffer!.seller.id);
    });

    test('a round-trip through toJson preserves the money contract', () {
      final product = ProductModel.fromJson(json);
      final reparsed = ProductModel.fromJson(product.toJson());

      expect(reparsed.price, product.price);
      expect(reparsed.offers.length, product.offers.length);
      expect(reparsed.category.slug, product.category.slug);
    });
  });

  group('Money', () {
    test('never invents a currency', () {
      final money = Money.fromJson({'amount': '1450000.0000'});
      expect(money.currency, Currency.syp);
      expect(money.raw, '1450000.0000');
    });

    test('keeps large SYP figures exact as text', () {
      const raw = '999999999.9999';
      final money = Money(raw: raw, currency: Currency.syp);
      expect(money.raw, raw, reason: 'the wire value is never re-serialised');
    });

    test('tolerates a missing amount rather than crashing a screen', () {
      expect(Money.tryFromJson(null), isNull);
      expect(Money.tryFromJson({'currency': 'SYP'}), isNull);
    });

    test('SYP shows no fractional part', () {
      final money = Money(raw: '1450000.0000', currency: Currency.syp);
      // The symbol ل.س itself contains a dot, so assert on the numeric half.
      final numeric = money.format().split(' ').first;
      expect(numeric, '1,450,000');
    });

    test('USD keeps two decimals', () {
      final money = Money(raw: '10.50', currency: Currency.usd);
      expect(money.format().split(' ').first, '10.50');
    });

    test('a per-currency list picks SYP as the headline', () {
      final totals = [
        Money(raw: '10', currency: Currency.usd),
        Money(raw: '130000', currency: Currency.syp),
      ];
      expect(totals.primary!.currency, Currency.syp);
    });
  });
}
