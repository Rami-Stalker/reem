import 'package:flutter_riverpod/legacy.dart';
import 'package:reem/core/result/result.dart';

import 'package:reem/features/profile/domain/usecases/collection_items_usecase.dart';
import 'package:reem/features/profile/domain/usecases/create_wishlist_collection_usecase.dart';
import 'package:reem/features/profile/domain/usecases/get_favorites_usecase.dart';
import 'package:reem/features/profile/domain/usecases/get_orders_usecase.dart';
import 'package:reem/features/profile/domain/usecases/get_profile_usecase.dart';
import 'package:reem/features/profile/domain/usecases/get_wishlist_overview_usecase.dart';
import 'package:reem/features/profile/domain/usecases/save_post_usecase.dart';
import 'package:reem/features/profile/domain/usecases/save_seller_usecase.dart';
import 'package:reem/features/profile/domain/usecases/share_wishlist_collection_usecase.dart';
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
  })  : _getFavorites = getFavoritesUseCase,
        super(const FavoritesState());

  final GetFavoritesUseCase _getFavorites;

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

  /// Saving a piece goes through `ProductGestures.save`, not here.
  ///
  /// This was `toggleFavorite`, and it was the grid tile's heart. Two things
  /// were wrong with it. It wrote to a different store than the product page
  /// and the post card did, so one product had two hearts that disagreed —
  /// which is what this whole pass exists to fix. And it was a "toggle" that
  /// only ever POSTed: there was no path through it that could *un*-favourite
  /// anything, so a heart filled by mistake stayed filled.
  ///
  /// `ProductGestures.save` sends the explicit POST or DELETE and then reloads
  /// this notifier, so the shelf below is still what it always was.
}

class WishlistNotifier extends StateNotifier<WishlistState> {
  WishlistNotifier({
    required GetWishlistOverviewUseCase getWishlistOverviewUseCase,
    required CreateWishlistCollectionUseCase createWishlistCollectionUseCase,
    required SaveSellerUseCase saveSellerUseCase,
    required SavePostUseCase savePostUseCase,
    required ShareWishlistCollectionUseCase shareWishlistCollectionUseCase,
    required AddToWishlistCollectionUseCase addToWishlistCollectionUseCase,
    required RemoveFromWishlistCollectionUseCase
    removeFromWishlistCollectionUseCase,
  })  : _getWishlistOverview = getWishlistOverviewUseCase,
        _createWishlistCollection = createWishlistCollectionUseCase,
        _saveSeller = saveSellerUseCase,
        _savePost = savePostUseCase,
        _shareWishlistCollection = shareWishlistCollectionUseCase,
        _addToWishlistCollection = addToWishlistCollectionUseCase,
        _removeFromWishlistCollection = removeFromWishlistCollectionUseCase,
        super(const WishlistState());

  final GetWishlistOverviewUseCase _getWishlistOverview;
  final CreateWishlistCollectionUseCase _createWishlistCollection;
  final SaveSellerUseCase _saveSeller;
  final SavePostUseCase _savePost;
  final ShareWishlistCollectionUseCase _shareWishlistCollection;
  final AddToWishlistCollectionUseCase _addToWishlistCollection;
  final RemoveFromWishlistCollectionUseCase _removeFromWishlistCollection;

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

  /// Files an already-saved thing into one of her collections.
  ///
  /// The save itself has already happened — the heart filled, the row exists.
  /// This is the second, optional half: where she wants to keep it. Returns
  /// false and leaves [WishlistState.error] set when the server refused, so
  /// the sheet can put the row back the way it was.
  Future<bool> addToCollection({
    required String collectionId,
    required String type,
    String? productId,
    String? postId,
    String? sellerId,
  }) => _mutateCollection(
    _addToWishlistCollection(
      collectionId: collectionId,
      type: type,
      productId: productId,
      postId: postId,
      sellerId: sellerId,
    ),
  );

  /// Takes it back out. «بدون مجموعة» is this, applied to every collection
  /// that holds it — the item stays saved, it simply stops being filed.
  Future<bool> removeFromCollection({
    required String collectionId,
    required String itemId,
  }) => _mutateCollection(
    _removeFromWishlistCollection(collectionId: collectionId, itemId: itemId),
  );

  Future<bool> _mutateCollection(Future<Result<void>> future) async {
    state = state.copyWith(isMutating: true, clearError: true);
    final result = await future;
    if (!mounted) return false;
    switch (result) {
      case Success():
        state = state.copyWith(isMutating: false);
        await load();
        return true;
      case Error(:final failure):
        state = state.copyWith(isMutating: false, error: failure.message);
        return false;
    }
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
