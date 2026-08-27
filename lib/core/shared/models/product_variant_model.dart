// shared/models/product_variant_model.dart

import '../entities/product_variant.dart';
import '../value_objects/money.dart';

class ProductVariantModel extends ProductVariant {
  const ProductVariantModel({
    required super.id,
    required super.name,
    super.attributes,
    super.imageUrl,
    super.sortOrder,
  });

  factory ProductVariantModel.fromJson(Map<String, dynamic> json) {
    return ProductVariantModel(
      id: json['id'] as String,
      name: json['name'] as String? ?? '',
      attributes: (json['attributes'] as Map?)?.cast<String, dynamic>() ?? {},
      imageUrl: json['image_url'] as String?,
      sortOrder: json['sort_order'] as int? ?? 0,
    );
  }

  factory ProductVariantModel.fromEntity(ProductVariant variant) =>
      ProductVariantModel(
        id: variant.id,
        name: variant.name,
        attributes: variant.attributes,
        imageUrl: variant.imageUrl,
        sortOrder: variant.sortOrder,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'attributes': attributes,
        'image_url': imageUrl,
        'sort_order': sortOrder,
      };
}

class OfferVariantModel extends OfferVariant {
  const OfferVariantModel({
    required super.id,
    required super.variantId,
    required super.name,
    required super.price,
    super.attributes,
    super.imageUrl,
    super.stock,
    super.sku,
  });

  factory OfferVariantModel.fromJson(
    Map<String, dynamic> json, {
    Currency fallbackCurrency = Currency.syp,
  }) {
    return OfferVariantModel(
      id: json['id'] as String,
      variantId: json['variant_id'] as String? ?? json['id'] as String,
      name: json['name'] as String? ?? '',
      price: Money.fromJson(json['price'], fallback: fallbackCurrency),
      attributes: (json['attributes'] as Map?)?.cast<String, dynamic>() ?? {},
      imageUrl: json['image_url'] as String?,
      stock: json['stock'] as int? ?? 0,
      sku: json['sku'] as String?,
    );
  }

  factory OfferVariantModel.fromEntity(OfferVariant variant) =>
      OfferVariantModel(
        id: variant.id,
        variantId: variant.variantId,
        name: variant.name,
        price: variant.price,
        attributes: variant.attributes,
        imageUrl: variant.imageUrl,
        stock: variant.stock,
        sku: variant.sku,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'variant_id': variantId,
        'name': name,
        'price': price.toJson(),
        'attributes': attributes,
        'image_url': imageUrl,
        'stock': stock,
        'sku': sku,
      };
}
