import '../../domain/entities/cart.dart';

class CartLineModel extends CartLine {
  const CartLineModel({
    required super.id,
    required super.productId,
    required super.title,
    super.image,
    required super.productPrice,
    required super.status,
    super.variantId,
    super.variantName,
    required super.quantity,
    required super.unitPrice,
    required super.lineTotal,
    required super.inStock,
    required super.availableStock,
  });

  factory CartLineModel.fromJson(Map<String, dynamic> json) {
    final product = json['product'] as Map<String, dynamic>;
    final variant = json['variant'] as Map<String, dynamic>?;
    return CartLineModel(
      id: json['id'] as String,
      productId: product['id'] as String,
      title: product['title'] as String? ?? '',
      image: product['image'] as String?,
      productPrice: (product['price'] as num?)?.toDouble() ?? 0,
      status: product['status'] as String? ?? 'active',
      variantId: variant?['id'] as String?,
      variantName: variant?['name'] as String?,
      quantity: json['quantity'] as int? ?? 1,
      unitPrice: (json['unit_price'] as num?)?.toDouble() ?? 0,
      lineTotal: (json['line_total'] as num?)?.toDouble() ?? 0,
      inStock: json['in_stock'] as bool? ?? true,
      availableStock: json['available_stock'] as int? ?? 0,
    );
  }
}

class CartSummaryModel extends CartSummary {
  const CartSummaryModel({
    super.subtotal,
    super.discount,
    super.deliveryFee,
    super.total,
    super.itemsCount,
    super.totalQuantity,
  });

  factory CartSummaryModel.fromJson(Map<String, dynamic> json) {
    return CartSummaryModel(
      subtotal: (json['subtotal'] as num?)?.toDouble() ?? 0,
      discount: (json['discount'] as num?)?.toDouble() ?? 0,
      deliveryFee: (json['delivery_fee'] as num?)?.toDouble() ?? 0,
      total: (json['total'] as num?)?.toDouble() ?? 0,
      itemsCount: json['items_count'] as int? ?? 0,
      totalQuantity: json['total_quantity'] as int? ?? 0,
    );
  }
}

class CartModel extends Cart {
  const CartModel({super.items, super.summary});

  factory CartModel.fromJson(Map<String, dynamic> json) {
    return CartModel(
      items: (json['items'] as List? ?? [])
          .map((e) => CartLineModel.fromJson(e as Map<String, dynamic>))
          .toList(),
      summary: CartSummaryModel.fromJson(
        json['summary'] as Map<String, dynamic>? ?? const {},
      ),
    );
  }
}
