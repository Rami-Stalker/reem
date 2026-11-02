import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ohara/core/base/repository_handler.dart';
import 'package:ohara/core/presentation/providers/core_providers.dart';
import 'package:ohara/core/result/result.dart';
import 'package:ohara/features/seller_products/domain/entities/managed_product.dart';
import 'package:ohara/features/seller_products/presentation/providers/seller_products_providers.dart';
import 'package:ohara/features/seller_store/data/datasources/seller_store_remote_datasource.dart';
import 'package:ohara/features/seller_store/domain/entities/seller_store.dart';

final sellerStoreApiProvider = Provider<SellerStoreRemoteDataSource>(
  (ref) => SellerStoreRemoteDataSource(ref.watch(dioProvider)),
);

final class _Guard with RepositoryHandler {
  const _Guard();
}

/// Runs a call and turns any failure into the sentence to show her.
Future<T> storeCall<T>(Future<T> Function() call) async =>
    switch (await const _Guard().guard(call)) {
      Success(:final data) => data,
      Error(:final failure) => throw failure.message,
    };

final storePoliciesProvider = FutureProvider.autoDispose<StorePolicies>(
  (ref) => storeCall(ref.watch(sellerStoreApiProvider).policies),
);

final shippingSettingsProvider = FutureProvider.autoDispose<ShippingSettings>(
  (ref) => storeCall(ref.watch(sellerStoreApiProvider).shipping),
);

final storeTeamProvider = FutureProvider.autoDispose<List<StoreTeamMember>>(
  (ref) => storeCall(ref.watch(sellerStoreApiProvider).team),
);

final storeMembershipsProvider =
    FutureProvider.autoDispose<List<StoreMembership>>(
      (ref) => storeCall(ref.watch(sellerStoreApiProvider).memberships),
    );

final sellerCouponsProvider = FutureProvider.autoDispose<List<SellerCoupon>>(
  (ref) => storeCall(ref.watch(sellerStoreApiProvider).coupons),
);

/// Her listings, for choosing a piece to put on sale.
final saleCandidatesProvider = FutureProvider.autoDispose<List<ManagedProduct>>((
  ref,
) async {
  final result = await ref
      .watch(sellerProductsRepositoryProvider)
      .getMyProducts(limit: 50);
  return switch (result) {
    Success(:final data) => data.items,
    Error(:final failure) => throw failure.message,
  };
});

/// A shop's public policies and shipping, for its page.
final storeInfoProvider = FutureProvider.autoDispose
    .family<(StorePolicies, ShippingSettings), String>(
      (ref, sellerId) =>
          storeCall(() => ref.watch(sellerStoreApiProvider).storeInfo(sellerId)),
    );
