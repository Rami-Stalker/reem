import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import 'package:ohara/core/presentation/providers/core_providers.dart';
import 'package:ohara/core/result/result.dart';
import 'package:ohara/features/discovery/data/datasources/discovery_remote_datasource.dart';
import 'package:ohara/features/discovery/data/datasources/impl/discovery_remote_datasource_impl.dart';
import 'package:ohara/features/discovery/data/repositories/discovery_repository_impl.dart';
import 'package:ohara/features/discovery/domain/entities/product_collection.dart';
import 'package:ohara/features/discovery/domain/repositories/discovery_repository.dart';
import 'package:ohara/features/discovery/domain/usecases/discovery_usecases.dart';
import 'package:ohara/features/discovery/presentation/providers/collection_notifier.dart';
import 'package:ohara/features/discovery/presentation/providers/collection_state.dart';
import 'package:ohara/features/discovery/presentation/providers/sponsored_providers.dart';

// ── Infrastructure / use cases ──────────────────────────────────────────────

final discoveryRemoteDataSourceProvider = Provider<DiscoveryRemoteDataSource>(
  (ref) => DiscoveryRemoteDataSourceImpl(ref.watch(dioProvider)),
);

final discoveryRepositoryProvider = Provider<DiscoveryRepository>(
  (ref) =>
      DiscoveryRepositoryImpl(ref.watch(discoveryRemoteDataSourceProvider)),
);

final getCollectionUseCaseProvider = Provider(
  (ref) => GetCollectionUseCase(ref.watch(discoveryRepositoryProvider)),
);
final getCategoryProductsUseCaseProvider = Provider(
  (ref) => GetCategoryProductsUseCase(ref.watch(discoveryRepositoryProvider)),
);
final getSellerProductsUseCaseProvider = Provider(
  (ref) => GetSellerProductsUseCase(ref.watch(discoveryRepositoryProvider)),
);
final getSimilarProductsUseCaseProvider = Provider(
  (ref) => GetSimilarProductsUseCase(ref.watch(discoveryRepositoryProvider)),
);
final getRecommendedUseCaseProvider = Provider(
  (ref) => GetRecommendedUseCase(ref.watch(discoveryRepositoryProvider)),
);

// ── Independent provider per collection (own loading / error / paging) ──────

/// Static collection (or recommended) — one independent state per collection.
final collectionProductsProvider = StateNotifierProvider.autoDispose
    .family<CollectionNotifier, CollectionState, ProductCollection>((
      ref,
      collection,
    ) {
      final ProductPageFetcher fetch =
          collection == ProductCollection.recommended
          ? (page) => ref.read(getRecommendedUseCaseProvider)(page: page)
          : (page) => ref.read(getCollectionUseCaseProvider)(
              collection.key,
              page: page,
            );
      return CollectionNotifier(fetch)..load();
    });

final categoryProductsProvider = StateNotifierProvider.autoDispose
    .family<CollectionNotifier, CollectionState, String>((ref, category) {
      return CollectionNotifier((page) async {
        final result = await ref.read(getCategoryProductsUseCaseProvider)(
          category,
          page: page,
        );
        if (page == 1 && ref.mounted) {
          if (result case Success(:final data)) {
            ref
                    .read(
                      sponsoredSlotsProvider(
                        categorySponsoredKey(category),
                      ).notifier,
                    )
                    .state =
                data.sponsored;
          }
        }
        return result;
      })..load();
    });

final sellerProductsProvider = StateNotifierProvider.autoDispose
    .family<CollectionNotifier, CollectionState, String>((ref, sellerId) {
      return CollectionNotifier(
        (page) =>
            ref.read(getSellerProductsUseCaseProvider)(sellerId, page: page),
      )..load();
    });

final similarProductsProvider = StateNotifierProvider.autoDispose
    .family<CollectionNotifier, CollectionState, String>((ref, productId) {
      return CollectionNotifier(
        (page) =>
            ref.read(getSimilarProductsUseCaseProvider)(productId, page: page),
      )..load();
    });
