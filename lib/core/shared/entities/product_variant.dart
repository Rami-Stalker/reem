// shared/entities/product_variant.dart

import 'package:equatable/equatable.dart';

import '../value_objects/money.dart';

/// A canonical option combination of a product — {size: M, colour: red}.
///
/// It carries no price and no stock. Several sellers may list the same product,
/// each with their own price and their own stock per option, so those live on
/// [OfferVariant] instead.
class ProductVariant extends Equatable {
  final String id;
  final String name;

  /// The option axes: size, colour, shade, scent, volume.
  final Map<String, dynamic> attributes;

  /// A different image per option (Q34).
  final String? imageUrl;
  final int sortOrder;

  const ProductVariant({
    required this.id,
    required this.name,
    this.attributes = const {},
    this.imageUrl,
    this.sortOrder = 0,
  });

  /// e.g. `المقاس M · اللون أحمر`
  String get attributesLabel => attributes.entries
      .map((entry) => '${entry.key} ${entry.value}')
      .join(' · ');

  @override
  List<Object?> get props => [id, name, attributes, imageUrl, sortOrder];
}

/// One seller's priced, stocked instance of a [ProductVariant].
///
/// This — not [ProductVariant] — is what goes in the cart, because buying
/// requires knowing *whose* stock is being drawn down.
class OfferVariant extends Equatable {
  final String id;
  final String variantId;
  final String name;
  final Map<String, dynamic> attributes;
  final String? imageUrl;
  final Money price;
  final int stock;
  final String? sku;

  const OfferVariant({
    required this.id,
    required this.variantId,
    required this.name,
    required this.price,
    this.attributes = const {},
    this.imageUrl,
    this.stock = 0,
    this.sku,
  });

  bool get inStock => stock > 0;

  @override
  List<Object?> get props => [
        id,
        variantId,
        name,
        attributes,
        imageUrl,
        price,
        stock,
        sku,
      ];
}
