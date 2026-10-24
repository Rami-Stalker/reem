import 'package:ohara/core/shared/value_objects/money.dart';
import 'package:ohara/features/user_profile/domain/entities/seller_stats.dart';

class SellerStatsModel extends SellerStats {
  const SellerStatsModel({
    super.productsCount,
    super.totalSales,
    super.ordersCount,
    super.averageRating,
  });

  /// `total_sales` arrives as the server's per-currency roll-up —
  /// `[{"amount": "1450000.0000", "currency": "SYP"}]` — and
  /// [moneyListFromJson] also absorbs the single object or bare number a
  /// future endpoint might send instead of throwing on the shape.
  factory SellerStatsModel.fromJson(Map<String, dynamic> json) {
    return SellerStatsModel(
      productsCount: json['products_count'] as int? ?? 0,
      totalSales: moneyListFromJson(json['total_sales']),
      ordersCount: json['orders_count'] as int? ?? 0,
      averageRating: (json['average_rating'] as num?)?.toDouble() ?? 0,
    );
  }
}
