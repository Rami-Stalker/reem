// shared/models/product_variant_model.dart

import '../entities/product_variant.dart';

class ProductVariantModel extends ProductVariant {
  const ProductVariantModel({
    required super.id,
    required super.name,
    super.sku,
    super.price,
    super.stock,
    super.sortOrder,
  });

  factory ProductVariantModel.fromJson(Map<String, dynamic> json) {
    return ProductVariantModel(
      id: json['id'] as String,
      name: json['name'] as String,
      sku: json['sku'] as String?,
      price: (json['price'] as num?)?.toDouble(),
      stock: json['stock'] as int? ?? 0,
      sortOrder: json['sort_order'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'sku': sku,
        'price': price,
        'stock': stock,
        'sort_order': sortOrder,
      };
}
