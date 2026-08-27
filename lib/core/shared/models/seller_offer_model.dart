// shared/models/seller_offer_model.dart

import '../entities/seller_offer.dart';
import '../value_objects/money.dart';
import 'product_variant_model.dart';
import 'user_model.dart';

class SellerOfferModel extends SellerOffer {
  const SellerOfferModel({
    required super.id,
    required super.seller,
    required super.price,
    super.compareAtPrice,
    super.wholesalePrice,
    super.wholesaleMinQty,
    super.stock,
    super.minOrderQty,
    super.maxOrderQty,
    super.sku,
    super.handlingDays,
    super.isMadeToOrder,
    super.requiresDeposit,
    super.acceptsReturns,
    super.status,
    super.variants,
  });

  factory SellerOfferModel.fromJson(Map<String, dynamic> json) {
    final currency = Currency.fromWire(json['currency'] as String?);
    return SellerOfferModel(
      id: json['id'] as String,
      seller: UserModel.fromJson(json['seller'] as Map<String, dynamic>),
      price: Money.fromJson(json['price'], fallback: currency),
      compareAtPrice:
          Money.tryFromJson(json['compare_at_price'], fallback: currency),
      wholesalePrice:
          Money.tryFromJson(json['wholesale_price'], fallback: currency),
      wholesaleMinQty: json['wholesale_min_qty'] as int?,
      stock: json['stock'] as int? ?? 0,
      minOrderQty: json['min_order_qty'] as int? ?? 1,
      maxOrderQty: json['max_order_qty'] as int?,
      sku: json['sku'] as String?,
      handlingDays: json['handling_days'] as int? ?? 1,
      isMadeToOrder: json['is_made_to_order'] as bool? ?? false,
      requiresDeposit: json['requires_deposit'] as bool? ?? false,
      acceptsReturns: json['accepts_returns'] as bool? ?? true,
      status: OfferStatus.fromWire(json['status'] as String?),
      variants: (json['variants'] as List? ?? [])
          .map((e) => OfferVariantModel.fromJson(
                e as Map<String, dynamic>,
                fallbackCurrency: currency,
              ))
          .toList(),
    );
  }

  factory SellerOfferModel.fromEntity(SellerOffer offer) => SellerOfferModel(
        id: offer.id,
        seller: offer.seller,
        price: offer.price,
        compareAtPrice: offer.compareAtPrice,
        wholesalePrice: offer.wholesalePrice,
        wholesaleMinQty: offer.wholesaleMinQty,
        stock: offer.stock,
        minOrderQty: offer.minOrderQty,
        maxOrderQty: offer.maxOrderQty,
        sku: offer.sku,
        handlingDays: offer.handlingDays,
        isMadeToOrder: offer.isMadeToOrder,
        requiresDeposit: offer.requiresDeposit,
        acceptsReturns: offer.acceptsReturns,
        status: offer.status,
        variants: offer.variants,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'seller': UserModel.fromEntity(seller).toJson(),
        'currency': price.currency.wire,
        'price': price.toJson(),
        'compare_at_price': compareAtPrice?.toJson(),
        'wholesale_price': wholesalePrice?.toJson(),
        'wholesale_min_qty': wholesaleMinQty,
        'stock': stock,
        'min_order_qty': minOrderQty,
        'max_order_qty': maxOrderQty,
        'sku': sku,
        'handling_days': handlingDays,
        'is_made_to_order': isMadeToOrder,
        'requires_deposit': requiresDeposit,
        'accepts_returns': acceptsReturns,
        'status': status.name,
        'variants': variants
            .map((v) => OfferVariantModel.fromEntity(v).toJson())
            .toList(),
      };
}
