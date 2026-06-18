import 'package:equatable/equatable.dart';

class SellerLowStockItem extends Equatable {
  const SellerLowStockItem({
    required this.id,
    required this.title,
    required this.imageUrl,
    required this.stock,
    required this.threshold,
    required this.price,
  });

  final String id;
  final String title;
  final String imageUrl;
  final int stock;
  final int threshold;
  final double price;

  bool get isOutOfStock => stock == 0;
  bool get isCritical => stock <= 3;

  @override
  List<Object?> get props => [id, stock];
}
