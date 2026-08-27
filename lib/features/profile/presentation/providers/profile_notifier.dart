import 'package:flutter_riverpod/legacy.dart';
import 'package:reem/core/result/result.dart';

import 'package:reem/features/profile/domain/usecases/create_wishlist_collection_usecase.dart';
import 'package:reem/features/profile/domain/usecases/get_favorites_usecase.dart';
import 'package:reem/features/profile/domain/usecases/get_orders_usecase.dart';
import 'package:reem/features/profile/domain/usecases/get_profile_usecase.dart';
import 'package:reem/features/profile/domain/usecases/get_wishlist_overview_usecase.dart';
import 'package:reem/features/profile/domain/usecases/save_post_usecase.dart';
import 'package:reem/features/profile/domain/usecases/save_seller_usecase.dart';
import 'package:reem/features/profile/domain/usecases/share_wishlist_collection_usecase.dart';
import 'package:reem/features/profile/domain/usecases/toggle_favorite_usecase.dart';
import 'package:reem/features/profile/presentation/providers/profile_state.dart';

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

class WishlistNotifier extends StateNotifier<WishlistState> {
  WishlistNotifier({
    required GetWishlistOverviewUseCase getWishlistOverviewUseCase,
    required CreateWishlistCollectionUseCase createWishlistCollectionUseCase,
    required SaveSellerUseCase saveSellerUseCase,
    required SavePostUseCase savePostUseCase,
    required ShareWishlistCollectionUseCase shareWishlistCollectionUseCase,
  })  : _getWishlistOverview = getWishlistOverviewUseCase,
        _createWishlistCollection = createWishlistCollectionUseCase,
        _saveSeller = saveSellerUseCase,
        _savePost = savePostUseCase,
        _shareWishlistCollection = shareWishlistCollectionUseCase,
        super(const WishlistState());

  final GetWishlistOverviewUseCase _getWishlistOverview;
  final CreateWishlistCollectionUseCase _createWishlistCollection;
  final SaveSellerUseCase _saveSeller;
  final SavePostUseCase _savePost;
  final ShareWishlistCollectionUseCase _shareWishlistCollection;

  Future<void> load() async {
    state = state.copyWith(
      isLoading: true,
      clearError: true,
      clearShareLink: true,
    );
    final result = await _getWishlistOverview();
    state = switch (result) {
      Success(:final data) =>
        state.copyWith(isLoading: false, overview: data),
      Error(:final failure) =>
        state.copyWith(isLoading: false, error: failure.message),
    };
  }

  Future<void> createCollection({
    required String name,
    String? description,
  }) async {
    state = state.copyWith(isMutating: true, clearError: true);
    final result = await _createWishlistCollection(
      name: name,
      description: description,
    );
    state = switch (result) {
      Success() => state.copyWith(isMutating: false),
      Error(:final failure) =>
        state.copyWith(isMutating: false, error: failure.message),
    };
    if (result is Success) await load();
  }

  Future<void> saveSeller(String sellerId) => _runAndReload(_saveSeller(sellerId));

  Future<void> savePost(String postId) => _runAndReload(_savePost(postId));

  Future<void> shareCollection(String collectionId) async {
    state = state.copyWith(isMutating: true, clearError: true);
    final result = await _shareWishlistCollection(collectionId);
    state = switch (result) {
      Success(:final data) =>
        state.copyWith(isMutating: false, shareLink: data),
      Error(:final failure) =>
        state.copyWith(isMutating: false, error: failure.message),
    };
  }

  Future<void> _runAndReload(Future<Result<void>> future) async {
    state = state.copyWith(isMutating: true, clearError: true);
    final result = await future;
    state = switch (result) {
      Success() => state.copyWith(isMutating: false),
      Error(:final failure) =>
        state.copyWith(isMutating: false, error: failure.message),
    };
    if (result is Success) await load();
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
