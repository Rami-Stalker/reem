import 'package:equatable/equatable.dart';

/// Aggregate commercial stats for a seller's storefront.
class SellerStats extends Equatable {
  final int productsCount;
  final double totalSales;
  final int ordersCount;
  final double averageRating;

  const SellerStats({
    this.productsCount = 0,
    this.totalSales = 0,
    this.ordersCount = 0,
    this.averageRating = 0,
  });

  @override
  List<Object?> get props =>
      [productsCount, totalSales, ordersCount, averageRating];
}
