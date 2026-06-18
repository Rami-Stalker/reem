import 'package:flutter_riverpod/legacy.dart';

import '../../domain/entities/seller_analytics.dart';
import '../../domain/entities/seller_chart_data.dart';
import '../../domain/usecases/get_seller_dashboard_usecase.dart';
import 'seller_dashboard_state.dart';

class SellerDashboardNotifier
    extends StateNotifier<SellerDashboardState> {
  SellerDashboardNotifier({required this.getDashboard})
      : super(const SellerDashboardState());

  final GetSellerDashboardUseCase getDashboard;

  Future<void> load() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final data = await getDashboard();
      state = state.copyWith(data: data, isLoading: false);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Could not load dashboard. Pull down to refresh.',
      );
    }
  }

  Future<void> refresh() => load();

  void setRevenuePeriod(RevenuePeriod period) {
    state = state.copyWith(selectedRevenuePeriod: period);
  }

  void setChartPeriod(ChartPeriod period) {
    state = state.copyWith(selectedChartPeriod: period);
  }
}
