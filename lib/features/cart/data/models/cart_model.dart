import 'package:ohara/core/shared/value_objects/money.dart';
import 'package:ohara/features/cart/domain/entities/cart.dart';

class CartLineModel extends CartLine {
  const CartLineModel({
    required super.id,
    required super.offerId,
    required super.sellerId,
    required super.sellerName,
    required super.productId,
    required super.title,
    required super.quantity,
    required super.unitPrice,
    required super.lineTotal,
    required super.inStock,
    required super.availableStock,
    super.sellerImageUrl,
    super.image,
    super.categorySlug,
    super.returnsAllowed,
    super.offerVariantId,
    super.variantName,
    super.minOrderQty,
    super.maxOrderQty,
    super.isMadeToOrder,
    super.handlingDays,
  });

  factory CartLineModel.fromJson(Map<String, dynamic> json) {
    final seller = (json['seller'] as Map?)?.cast<String, dynamic>() ?? const {};
    final product =
        (json['product'] as Map?)?.cast<String, dynamic>() ?? const {};
    final variant = (json['variant'] as Map?)?.cast<String, dynamic>();
    final currency = Currency.fromWire(json['currency'] as String?);

    return CartLineModel(
      id: json['id'] as String,
      offerId: json['offer_id'] as String? ?? '',
      sellerId: seller['id'] as String? ?? '',
      sellerName: seller['name'] as String? ?? '',
      sellerImageUrl: seller['image_url'] as String?,
      productId: product['id'] as String? ?? '',
      title: product['title'] as String? ?? '',
      image: product['image'] as String?,
      categorySlug: product['category_slug'] as String? ?? '',
      returnsAllowed: product['returns_allowed'] as bool? ?? true,
      offerVariantId: variant?['id'] as String?,
      variantName: variant?['name'] as String?,
      quantity: json['quantity'] as int? ?? 1,
      // Money arrives as {amount, currency}. The previous parser read it with
      // `(json['unit_price'] as num?) ?? 0`, which turns a decimal string into
      // a silent zero — an empty-looking cart instead of an error.
      unitPrice: Money.fromJson(json['unit_price'], fallback: currency),
      lineTotal: Money.fromJson(json['line_total'], fallback: currency),
      inStock: json['in_stock'] as bool? ?? true,
      availableStock: json['available_stock'] as int? ?? 0,
      minOrderQty: json['min_order_qty'] as int? ?? 1,
      maxOrderQty: json['max_order_qty'] as int?,
      isMadeToOrder: json['is_made_to_order'] as bool? ?? false,
      handlingDays: json['handling_days'] as int? ?? 1,
    );
  }
}

class CartSellerGroupModel extends CartSellerGroup {
  const CartSellerGroupModel({
    required super.sellerId,
    required super.sellerName,
    super.sellerImageUrl,
    super.itemIds,
    super.itemsCount,
    super.subtotal,
  });

  factory CartSellerGroupModel.fromJson(Map<String, dynamic> json) {
    final seller = (json['seller'] as Map?)?.cast<String, dynamic>() ?? const {};
    return CartSellerGroupModel(
      sellerId: seller['id'] as String? ?? '',
      sellerName: seller['name'] as String? ?? '',
      sellerImageUrl: seller['image_url'] as String?,
      itemIds: (json['item_ids'] as List? ?? []).cast<String>(),
      itemsCount: json['items_count'] as int? ?? 0,
      subtotal: Money.tryFromJson(json['subtotal']),
    );
  }
}

class CartSummaryModel extends CartSummary {
  const CartSummaryModel({
    super.subtotalsByCurrency,
    super.itemsCount,
    super.sellersCount,
    super.totalQuantity,
  });

  factory CartSummaryModel.fromJson(Map<String, dynamic> json) {
    return CartSummaryModel(
      subtotalsByCurrency: moneyListFromJson(json['subtotals_by_currency']),
      itemsCount: json['items_count'] as int? ?? 0,
      sellersCount: json['sellers_count'] as int? ?? 0,
      totalQuantity: json['total_quantity'] as int? ?? 0,
    );
  }
}

class CartModel extends Cart {
  const CartModel({super.items, super.sellerGroups, super.summary});

  factory CartModel.fromJson(Map<String, dynamic> json) {
    return CartModel(
      items: (json['items'] as List? ?? [])
          .map((e) => CartLineModel.fromJson(e as Map<String, dynamic>))
          .toList(),
      sellerGroups: (json['seller_groups'] as List? ?? [])
          .map((e) => CartSellerGroupModel.fromJson(e as Map<String, dynamic>))
          .toList(),
      summary: CartSummaryModel.fromJson(
        (json['summary'] as Map?)?.cast<String, dynamic>() ?? const {},
      ),
    );
  }
}
