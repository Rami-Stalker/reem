import 'package:equatable/equatable.dart';

class SellerTopProduct extends Equatable {
  const SellerTopProduct({
    required this.id,
    required this.title,
    required this.imageUrl,
    required this.revenue,
    required this.unitsSold,
    required this.rating,
    required this.reviewsCount,
    required this.stock,
    this.revenueChange,
  });

  final String id;
  final String title;
  final String imageUrl;
  final double revenue;
  final int unitsSold;
  final double rating;
  final int reviewsCount;
  final int stock;

  /// Percentage change vs. prior period.
  final double? revenueChange;

  bool get isLowStock => stock > 0 && stock <= 10;
  bool get isOutOfStock => stock == 0;

  @override
  List<Object?> get props => [id, revenue, unitsSold];
}
