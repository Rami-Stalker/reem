import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../../data/datasources/impl/seller_dashboard_mock_datasource.dart';
import '../../data/datasources/seller_dashboard_datasource.dart';
import '../../data/repositories/seller_dashboard_repository_impl.dart';
import '../../domain/repositories/seller_dashboard_repository.dart';
import '../../domain/usecases/get_seller_dashboard_usecase.dart';
import 'seller_dashboard_notifier.dart';
import 'seller_dashboard_state.dart';

/// Swap this to a remote datasource implementation when the analytics API ships.
final sellerDashboardDataSourceProvider =
    Provider<SellerDashboardDataSource>(
  (_) => const SellerDashboardMockDataSource(),
);

final sellerDashboardRepositoryProvider =
    Provider<SellerDashboardRepository>(
  (ref) => SellerDashboardRepositoryImpl(
    source: ref.watch(sellerDashboardDataSourceProvider),
  ),
);

final getSellerDashboardUseCaseProvider = Provider(
  (ref) => GetSellerDashboardUseCase(
    ref.watch(sellerDashboardRepositoryProvider),
  ),
);

final sellerDashboardNotifierProvider =
    StateNotifierProvider<SellerDashboardNotifier, SellerDashboardState>(
  (ref) => SellerDashboardNotifier(
    getDashboard: ref.watch(getSellerDashboardUseCaseProvider),
  )..load(),
);
