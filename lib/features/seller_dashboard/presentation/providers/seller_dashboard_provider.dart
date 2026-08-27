import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import 'package:reem/core/presentation/providers/core_providers.dart';
import 'package:reem/features/seller_dashboard/data/datasources/impl/seller_dashboard_remote_datasource.dart';
import 'package:reem/features/seller_dashboard/data/datasources/seller_dashboard_datasource.dart';
import 'package:reem/features/seller_dashboard/data/repositories/seller_dashboard_repository_impl.dart';
import 'package:reem/features/seller_dashboard/domain/repositories/seller_dashboard_repository.dart';
import 'package:reem/features/seller_dashboard/domain/usecases/get_seller_dashboard_usecase.dart';
import 'package:reem/features/seller_dashboard/presentation/providers/seller_dashboard_notifier.dart';
import 'package:reem/features/seller_dashboard/presentation/providers/seller_dashboard_state.dart';

final sellerDashboardDataSourceProvider =
    Provider<SellerDashboardDataSource>(
  (ref) => SellerDashboardRemoteDataSource(ref.watch(dioProvider)),
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
