import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import 'package:reem/core/presentation/providers/core_providers.dart';
import 'package:reem/features/profile/data/datasources/impl/profile_remote_datasource_impl.dart';
import 'package:reem/features/profile/data/datasources/profile_remote_datasource.dart';
import 'package:reem/features/profile/data/repositories/profile_repository_impl.dart';
import 'package:reem/features/profile/domain/repositories/profile_repository.dart';
import 'package:reem/features/profile/domain/usecases/create_wishlist_collection_usecase.dart';
import 'package:reem/features/profile/domain/usecases/get_favorites_usecase.dart';
import 'package:reem/features/profile/domain/usecases/get_orders_usecase.dart';
import 'package:reem/features/profile/domain/usecases/get_profile_usecase.dart';
import 'package:reem/features/profile/domain/usecases/get_wishlist_overview_usecase.dart';
import 'package:reem/features/profile/domain/usecases/save_post_usecase.dart';
import 'package:reem/features/profile/domain/usecases/save_seller_usecase.dart';
import 'package:reem/features/profile/domain/usecases/share_wishlist_collection_usecase.dart';
import 'package:reem/features/profile/domain/usecases/toggle_favorite_usecase.dart';
import 'package:reem/features/profile/presentation/providers/profile_notifier.dart';
import 'package:reem/features/profile/presentation/providers/profile_state.dart';

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

final getWishlistOverviewUseCaseProvider = Provider(
  (ref) => GetWishlistOverviewUseCase(ref.watch(profileRepositoryProvider)),
);

final createWishlistCollectionUseCaseProvider = Provider(
  (ref) => CreateWishlistCollectionUseCase(ref.watch(profileRepositoryProvider)),
);

final saveSellerUseCaseProvider = Provider(
  (ref) => SaveSellerUseCase(ref.watch(profileRepositoryProvider)),
);

final savePostUseCaseProvider = Provider(
  (ref) => SavePostUseCase(ref.watch(profileRepositoryProvider)),
);

final shareWishlistCollectionUseCaseProvider = Provider(
  (ref) => ShareWishlistCollectionUseCase(ref.watch(profileRepositoryProvider)),
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

final wishlistNotifierProvider =
    StateNotifierProvider<WishlistNotifier, WishlistState>((ref) {
  return WishlistNotifier(
    getWishlistOverviewUseCase: ref.watch(getWishlistOverviewUseCaseProvider),
    createWishlistCollectionUseCase:
        ref.watch(createWishlistCollectionUseCaseProvider),
    saveSellerUseCase: ref.watch(saveSellerUseCaseProvider),
    savePostUseCase: ref.watch(savePostUseCaseProvider),
    shareWishlistCollectionUseCase:
        ref.watch(shareWishlistCollectionUseCaseProvider),
  );
});

final ordersNotifierProvider =
    StateNotifierProvider<OrdersNotifier, OrdersState>((ref) {
  return OrdersNotifier(
    getOrdersUseCase: ref.watch(getOrdersUseCaseProvider),
  );
});
