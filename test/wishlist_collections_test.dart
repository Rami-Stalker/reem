import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ohara/features/profile/data/models/wishlist_model.dart';

/// The collections tab, as the API actually answers it.
///
/// `price_when_saved` is a decimal column and arrives as a string. The model
/// cast it with `as num?`, which threw, and the whole tab showed "Unexpected
/// error while running repository operation." to every woman with a list.
void main() {
  test('a saved collection parses as the API sends it', () {
    final raw = jsonDecode(
      File('test/fixtures/wishlist_collections.json').readAsStringSync(),
    ) as List;
    final collection = WishlistCollectionModel.fromJson(
      Map<String, dynamic>.from(raw.first as Map),
    );

    expect(collection.items, isNotEmpty);
    expect(collection.items.first.priceWhenSaved, isNotNull);
  });

  test('a numeric saved price still parses', () {
    final item = WishlistItemModel.fromJson({
      'id': 'i1',
      'type': 'product',
      'price_when_saved': 3180,
      'created_at': '2026-08-18T13:05:08.954Z',
    });
    expect(item.priceWhenSaved, 3180);
  });
}
