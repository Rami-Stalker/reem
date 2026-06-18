import '../../domain/entities/seller_stats.dart';

class SellerStatsModel extends SellerStats {
  const SellerStatsModel({
    super.productsCount,
    super.totalSales,
    super.ordersCount,
    super.averageRating,
  });

  factory SellerStatsModel.fromJson(Map<String, dynamic> json) {
    return SellerStatsModel(
      productsCount: json['products_count'] as int? ?? 0,
      totalSales: (json['total_sales'] as num?)?.toDouble() ?? 0,
      ordersCount: json['orders_count'] as int? ?? 0,
      averageRating: (json['average_rating'] as num?)?.toDouble() ?? 0,
    );
  }
}
