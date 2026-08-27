import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import 'package:reem/core/presentation/providers/core_providers.dart';
import 'package:reem/features/cart/data/datasources/cart_remote_datasource.dart';
import 'package:reem/features/cart/data/datasources/impl/cart_remote_datasource_impl.dart';
import 'package:reem/features/cart/data/repositories/cart_repository_impl.dart';
import 'package:reem/features/cart/domain/repositories/cart_repository.dart';
import 'package:reem/features/cart/domain/usecases/cart_usecases.dart';
import 'package:reem/features/cart/presentation/providers/cart_notifier.dart';
import 'package:reem/features/cart/presentation/providers/cart_state.dart';

final cartRemoteDataSourceProvider = Provider<CartRemoteDataSource>(
  (ref) => CartRemoteDataSourceImpl(ref.watch(dioProvider)),
);

final cartRepositoryProvider = Provider<CartRepository>(
  (ref) => CartRepositoryImpl(ref.watch(cartRemoteDataSourceProvider)),
);

final getCartUseCaseProvider =
    Provider((ref) => GetCartUseCase(ref.watch(cartRepositoryProvider)));
final addToCartUseCaseProvider =
    Provider((ref) => AddToCartUseCase(ref.watch(cartRepositoryProvider)));
final updateCartItemUseCaseProvider =
    Provider((ref) => UpdateCartItemUseCase(ref.watch(cartRepositoryProvider)));
final removeCartItemUseCaseProvider =
    Provider((ref) => RemoveCartItemUseCase(ref.watch(cartRepositoryProvider)));
final clearCartUseCaseProvider =
    Provider((ref) => ClearCartUseCase(ref.watch(cartRepositoryProvider)));

/// App-wide cart (kept alive so the bottom-bar badge stays in sync).
final cartNotifierProvider =
    StateNotifierProvider<CartNotifier, CartState>((ref) {
  return CartNotifier(
    getCart: ref.watch(getCartUseCaseProvider),
    addToCart: ref.watch(addToCartUseCaseProvider),
    updateItem: ref.watch(updateCartItemUseCaseProvider),
    removeItem: ref.watch(removeCartItemUseCaseProvider),
    clearCart: ref.watch(clearCartUseCaseProvider),
  )..load();
});

/// Total quantity for cart badges.
final cartCountProvider = Provider<int>(
  (ref) => ref.watch(
    cartNotifierProvider.select((s) => s.cart.summary.totalQuantity),
  ),
);
