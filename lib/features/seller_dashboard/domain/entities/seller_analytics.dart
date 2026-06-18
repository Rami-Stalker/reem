import 'package:equatable/equatable.dart';

/// A period's revenue snapshot with trend vs. the prior period.
class SellerRevenueData extends Equatable {
  const SellerRevenueData({
    required this.today,
    required this.thisWeek,
    required this.thisMonth,
    required this.thisYear,
    required this.todayTrend,
    required this.weekTrend,
    required this.monthTrend,
    required this.yearTrend,
    required this.totalProfit,
    required this.profitMargin,
    required this.totalOrders,
  });

  final double today;
  final double thisWeek;
  final double thisMonth;
  final double thisYear;

  /// Percentage change vs. prior period (+/-). E.g. 12.4 means +12.4%.
  final double todayTrend;
  final double weekTrend;
  final double monthTrend;
  final double yearTrend;

  final double totalProfit;
  final double profitMargin;
  final int totalOrders;

  @override
  List<Object?> get props => [today, thisWeek, thisMonth, thisYear, totalProfit];
}

enum RevenuePeriod { today, week, month, year }

extension RevenuePeriodX on RevenuePeriod {
  String get label => switch (this) {
        RevenuePeriod.today => 'Today',
        RevenuePeriod.week => 'Week',
        RevenuePeriod.month => 'Month',
        RevenuePeriod.year => 'Year',
      };
}
