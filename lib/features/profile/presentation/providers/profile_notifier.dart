import 'package:flutter_riverpod/legacy.dart';
import 'package:reem/core/result/result.dart';

import '../../domain/usecases/get_favorites_usecase.dart';
import '../../domain/usecases/get_orders_usecase.dart';
import '../../domain/usecases/get_profile_usecase.dart';
import '../../domain/usecases/toggle_favorite_usecase.dart';
import 'profile_state.dart';

class ProfileNotifier extends StateNotifier<ProfileState> {
  ProfileNotifier({required GetProfileUseCase getProfileUseCase})
      : _getProfile = getProfileUseCase,
        super(const ProfileState());

  final GetProfileUseCase _getProfile;

  Future<void> load() async {
    state = state.copyWith(isLoading: true, clearError: true);
    final result = await _getProfile();
    state = switch (result) {
      Success(:final data) => state.copyWith(isLoading: false, user: data),
      Error(:final failure) =>
        state.copyWith(isLoading: false, error: failure.message),
    };
  }
}

class FavoritesNotifier extends StateNotifier<FavoritesState> {
  FavoritesNotifier({
    required GetFavoritesUseCase getFavoritesUseCase,
    required ToggleFavoriteUseCase toggleFavoriteUseCase,
  })  : _getFavorites = getFavoritesUseCase,
        _toggleFavorite = toggleFavoriteUseCase,
        super(const FavoritesState());

  final GetFavoritesUseCase _getFavorites;
  final ToggleFavoriteUseCase _toggleFavorite;

  Future<void> load() async {
    state = state.copyWith(isLoading: true, clearError: true);
    final result = await _getFavorites();
    state = switch (result) {
      Success(:final data) =>
        state.copyWith(isLoading: false, favorites: data),
      Error(:final failure) =>
        state.copyWith(isLoading: false, error: failure.message),
    };
  }

  Future<void> toggleFavorite(String productId) async {
    final result = await _toggleFavorite(productId);
    if (result is Success) {
      await load();
    }
  }
}

class OrdersNotifier extends StateNotifier<OrdersState> {
  OrdersNotifier({required GetOrdersUseCase getOrdersUseCase})
      : _getOrders = getOrdersUseCase,
        super(const OrdersState());

  final GetOrdersUseCase _getOrders;

  Future<void> load() async {
    state = state.copyWith(isLoading: true, clearError: true);
    final result = await _getOrders();
    state = switch (result) {
      Success(:final data) => state.copyWith(isLoading: false, orders: data),
      Error(:final failure) =>
        state.copyWith(isLoading: false, error: failure.message),
    };
  }
}
