import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import 'package:ohara/core/presentation/providers/core_providers.dart';
import 'package:ohara/features/auth/presentation/providers/auth_provider.dart';
import 'package:ohara/features/cart/data/datasources/cart_remote_datasource.dart';
import 'package:ohara/features/cart/data/datasources/impl/cart_remote_datasource_impl.dart';
import 'package:ohara/features/cart/data/repositories/cart_repository_impl.dart';
import 'package:ohara/features/cart/domain/repositories/cart_repository.dart';
import 'package:ohara/features/cart/domain/usecases/cart_usecases.dart';
import 'package:ohara/features/cart/presentation/providers/cart_notifier.dart';
import 'package:ohara/features/cart/presentation/providers/cart_state.dart';

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
///
/// It reloads whenever the session changes hands. Because it is kept alive it
/// used to load exactly once, as a guest, and then never again: signing in
/// left the notifier holding the visitor's empty cart, so a returning customer
/// opened the app to "your cart is empty" over a cart the server was still
/// keeping for her, and the badge agreed. The server also merges the guest
/// cart into hers at sign-in, so the state on this side is stale twice over.
/// Signing out reloads too, which drops the previous account's lines.
final cartNotifierProvider = StateNotifierProvider<CartNotifier, CartState>((
  ref,
) {
  final notifier = CartNotifier(
    getCart: ref.watch(getCartUseCaseProvider),
    addToCart: ref.watch(addToCartUseCaseProvider),
    updateItem: ref.watch(updateCartItemUseCaseProvider),
    removeItem: ref.watch(removeCartItemUseCaseProvider),
    clearCart: ref.watch(clearCartUseCaseProvider),
  );

  ref.listen<String?>(
    authNotifierProvider.select((auth) => auth.user?.id),
    (previous, next) {
      if (previous == next) return;
      notifier.load();
    },
  );

  return notifier..load();
});

/// Total quantity for cart badges.
final cartCountProvider = Provider<int>(
  (ref) => ref.watch(
    cartNotifierProvider.select((s) => s.cart.summary.totalQuantity),
  ),
);
