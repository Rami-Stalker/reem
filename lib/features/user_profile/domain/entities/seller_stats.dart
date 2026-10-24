import 'package:equatable/equatable.dart';
import 'package:ohara/core/shared/value_objects/money.dart';

/// Aggregate commercial stats for a seller's storefront.
class SellerStats extends Equatable {
  final int productsCount;

  /// Revenue, **per currency**.
  ///
  /// The server never sums across currencies — a boutique that has sold in
  /// both SYP and USD gets two figures — so this is a list, not a number. It
  /// used to be parsed as `num`, which threw a cast error on the first seller
  /// profile that had ever sold anything, and took the whole screen down with
  /// it: tapping a boutique anywhere in the app landed on «تعذّر تحميل الملف».
  final List<Money> totalSales;

  final int ordersCount;
  final double averageRating;

  const SellerStats({
    this.productsCount = 0,
    this.totalSales = const [],
    this.ordersCount = 0,
    this.averageRating = 0,
  });

  @override
  List<Object?> get props => [
    productsCount,
    totalSales,
    ordersCount,
    averageRating,
  ];
}
