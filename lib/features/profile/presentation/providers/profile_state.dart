import 'package:reem/core/shared/entities/product.dart';
import 'package:reem/core/shared/entities/user.dart';

import 'package:reem/features/profile/domain/entities/order_entity.dart';
import 'package:reem/features/profile/domain/entities/wishlist_entity.dart';

class ProfileState {
  const ProfileState({
    this.user,
    this.isLoading = false,
    this.error,
  });

  final User? user;
  final bool isLoading;
  final String? error;

  ProfileState copyWith({
    User? user,
    bool? isLoading,
    String? error,
    bool clearUser = false,
    bool clearError = false,
  }) {
    return ProfileState(
      user: clearUser ? null : (user ?? this.user),
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class FavoritesState {
  const FavoritesState({
    this.favorites = const [],
    this.isLoading = false,
    this.error,
  });

  final List<Product> favorites;
  final bool isLoading;
  final String? error;

  FavoritesState copyWith({
    List<Product>? favorites,
    bool? isLoading,
    String? error,
    bool clearError = false,
  }) {
    return FavoritesState(
      favorites: favorites ?? this.favorites,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class WishlistState {
  const WishlistState({
    this.overview = const WishlistOverview(),
    this.shareLink,
    this.isLoading = false,
    this.isMutating = false,
    this.error,
  });

  final WishlistOverview overview;
  final WishlistShareLink? shareLink;
  final bool isLoading;
  final bool isMutating;
  final String? error;

  WishlistState copyWith({
    WishlistOverview? overview,
    WishlistShareLink? shareLink,
    bool? isLoading,
    bool? isMutating,
    String? error,
    bool clearError = false,
    bool clearShareLink = false,
  }) {
    return WishlistState(
      overview: overview ?? this.overview,
      shareLink: clearShareLink ? null : (shareLink ?? this.shareLink),
      isLoading: isLoading ?? this.isLoading,
      isMutating: isMutating ?? this.isMutating,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class OrdersState {
  const OrdersState({
    this.orders = const [],
    this.isLoading = false,
    this.error,
  });

  final List<OrderEntity> orders;
  final bool isLoading;
  final String? error;

  OrdersState copyWith({
    List<OrderEntity>? orders,
    bool? isLoading,
    String? error,
    bool clearError = false,
  }) {
    return OrdersState(
      orders: orders ?? this.orders,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
    );
  }
}
