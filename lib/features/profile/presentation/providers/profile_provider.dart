import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../../../../core/providers/core_providers.dart';
import '../../data/datasources/impl/profile_remote_datasource_impl.dart';
import '../../data/datasources/profile_remote_datasource.dart';
import '../../data/repositories/profile_repository_impl.dart';
import '../../domain/repositories/profile_repository.dart';
import '../../domain/usecases/get_favorites_usecase.dart';
import '../../domain/usecases/get_orders_usecase.dart';
import '../../domain/usecases/get_profile_usecase.dart';
import '../../domain/usecases/toggle_favorite_usecase.dart';
import 'profile_notifier.dart';
import 'profile_state.dart';

final profileRemoteDataSourceProvider = Provider<ProfileRemoteDataSource>(
  (ref) => ProfileRemoteDataSourceImpl(ref.watch(dioProvider)),
);

final profileRepositoryProvider = Provider<ProfileRepository>(
  (ref) => ProfileRepositoryImpl(
    remote: ref.watch(profileRemoteDataSourceProvider),
  ),
);

final getProfileUseCaseProvider = Provider(
  (ref) => GetProfileUseCase(ref.watch(profileRepositoryProvider)),
);

final getFavoritesUseCaseProvider = Provider(
  (ref) => GetFavoritesUseCase(ref.watch(profileRepositoryProvider)),
);

final getOrdersUseCaseProvider = Provider(
  (ref) => GetOrdersUseCase(ref.watch(profileRepositoryProvider)),
);

final toggleFavoriteUseCaseProvider = Provider(
  (ref) => ToggleFavoriteUseCase(ref.watch(profileRepositoryProvider)),
);

final profileNotifierProvider =
    StateNotifierProvider<ProfileNotifier, ProfileState>((ref) {
  return ProfileNotifier(
    getProfileUseCase: ref.watch(getProfileUseCaseProvider),
  );
});

final favoritesNotifierProvider =
    StateNotifierProvider<FavoritesNotifier, FavoritesState>((ref) {
  return FavoritesNotifier(
    getFavoritesUseCase: ref.watch(getFavoritesUseCaseProvider),
    toggleFavoriteUseCase: ref.watch(toggleFavoriteUseCaseProvider),
  );
});

final ordersNotifierProvider =
    StateNotifierProvider<OrdersNotifier, OrdersState>((ref) {
  return OrdersNotifier(
    getOrdersUseCase: ref.watch(getOrdersUseCaseProvider),
  );
});
