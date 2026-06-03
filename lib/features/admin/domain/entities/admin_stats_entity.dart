import 'package:equatable/equatable.dart';

class AdminStatsEntity extends Equatable {
  const AdminStatsEntity({
    required this.totalSales,
    required this.totalOrders,
    required this.activeUsers,
    required this.conversionRate,
    this.salesTrend,
    this.ordersTrend,
    this.usersTrend,
    this.conversionTrend,
  });

  final double totalSales;
  final int totalOrders;
  final int activeUsers;
  final double conversionRate;
  final String? salesTrend;
  final String? ordersTrend;
  final String? usersTrend;
  final String? conversionTrend;

  @override
  List<Object?> get props => [
        totalSales,
        totalOrders,
        activeUsers,
        conversionRate,
        salesTrend,
        ordersTrend,
        usersTrend,
        conversionTrend,
      ];
}
