import 'package:equatable/equatable.dart';

/// A single line in the cart (a product, optionally a variant, and a quantity).
class CartLine extends Equatable {
  final String id;
  final String productId;
  final String title;
  final String? image;
  final double productPrice;
  final String status;
  final String? variantId;
  final String? variantName;
  final int quantity;
  final double unitPrice;
  final double lineTotal;
  final bool inStock;
  final int availableStock;

  const CartLine({
    required this.id,
    required this.productId,
    required this.title,
    this.image,
    required this.productPrice,
    required this.status,
    this.variantId,
    this.variantName,
    required this.quantity,
    required this.unitPrice,
    required this.lineTotal,
    required this.inStock,
    required this.availableStock,
  });

  bool get canIncrement => quantity < availableStock;

  @override
  List<Object?> get props => [
        id,
        productId,
        variantId,
        quantity,
        unitPrice,
        lineTotal,
        inStock,
        availableStock,
      ];
}

class CartSummary extends Equatable {
  final double subtotal;
  final double discount;
  final double deliveryFee;
  final double total;
  final int itemsCount;
  final int totalQuantity;

  const CartSummary({
    this.subtotal = 0,
    this.discount = 0,
    this.deliveryFee = 0,
    this.total = 0,
    this.itemsCount = 0,
    this.totalQuantity = 0,
  });

  @override
  List<Object?> get props =>
      [subtotal, discount, deliveryFee, total, itemsCount, totalQuantity];
}

class Cart extends Equatable {
  final List<CartLine> items;
  final CartSummary summary;

  const Cart({this.items = const [], this.summary = const CartSummary()});

  bool get isEmpty => items.isEmpty;
  bool get hasOutOfStock => items.any((i) => !i.inStock);

  @override
  List<Object?> get props => [items, summary];
}
