import 'package:equatable/equatable.dart';

import 'package:reem/features/seller_dashboard/domain/entities/seller_analytics.dart';
import 'package:reem/features/seller_dashboard/domain/entities/seller_chart_data.dart';
import 'package:reem/features/seller_dashboard/domain/entities/seller_dashboard_data.dart';

import 'package:reem/features/seller_dashboard/presentation/providers/seller_dashboard_message.dart';

class SellerDashboardState extends Equatable {
  const SellerDashboardState({
    this.data,
    this.isLoading = false,
    this.error,
    this.selectedRevenuePeriod = RevenuePeriod.today,
    this.selectedChartPeriod = ChartPeriod.weekly,
  });

  final SellerDashboardData? data;
  final bool isLoading;
  /// Named, not spelled out — the screen resolves it in her locale.
  final SellerDashboardMessage? error;
  final RevenuePeriod selectedRevenuePeriod;
  final ChartPeriod selectedChartPeriod;

  bool get isInitialLoading => isLoading && data == null;
  bool get hasData => data != null;

  SellerDashboardState copyWith({
    SellerDashboardData? data,
    bool? isLoading,
    SellerDashboardMessage? error,
    RevenuePeriod? selectedRevenuePeriod,
    ChartPeriod? selectedChartPeriod,
  }) {
    return SellerDashboardState(
      data: data ?? this.data,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      selectedRevenuePeriod:
          selectedRevenuePeriod ?? this.selectedRevenuePeriod,
      selectedChartPeriod: selectedChartPeriod ?? this.selectedChartPeriod,
    );
  }

  @override
  List<Object?> get props => [
        data,
        isLoading,
        error,
        selectedRevenuePeriod,
        selectedChartPeriod,
      ];
}
