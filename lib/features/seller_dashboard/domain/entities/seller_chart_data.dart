import 'package:equatable/equatable.dart';

/// A single data point on the revenue/sales chart.
class SellerChartPoint extends Equatable {
  const SellerChartPoint({required this.label, required this.value});

  final String label;
  final double value;

  @override
  List<Object?> get props => [label, value];
}

enum ChartPeriod { daily, weekly, monthly, yearly }

extension ChartPeriodX on ChartPeriod {
  String get label => switch (this) {
        ChartPeriod.daily => 'Daily',
        ChartPeriod.weekly => 'Weekly',
        ChartPeriod.monthly => 'Monthly',
        ChartPeriod.yearly => 'Yearly',
      };
}

class SellerChartDataset extends Equatable {
  const SellerChartDataset({
    required this.period,
    required this.revenuePoints,
    required this.ordersPoints,
  });

  final ChartPeriod period;
  final List<SellerChartPoint> revenuePoints;
  final List<SellerChartPoint> ordersPoints;

  @override
  List<Object?> get props => [period, revenuePoints, ordersPoints];
}
