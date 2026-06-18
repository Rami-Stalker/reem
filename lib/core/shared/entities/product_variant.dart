// shared/entities/product_variant.dart

import 'package:equatable/equatable.dart';

/// A purchasable variation of a product (size, colour, …). Canonical type
/// shared by the catalogue display models and seller management.
class ProductVariant extends Equatable {
  final String id;
  final String name;
  final String? sku;

  /// Overrides the product price when set; otherwise the base price applies.
  final double? price;
  final int stock;
  final int sortOrder;

  const ProductVariant({
    required this.id,
    required this.name,
    this.sku,
    this.price,
    this.stock = 0,
    this.sortOrder = 0,
  });

  bool get inStock => stock > 0;

  @override
  List<Object?> get props => [id, name, sku, price, stock, sortOrder];
}
