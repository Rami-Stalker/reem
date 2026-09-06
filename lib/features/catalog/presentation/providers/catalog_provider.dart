import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import 'package:reem/core/presentation/providers/core_providers.dart';
import 'package:reem/features/catalog/data/datasources/catalog_remote_datasource.dart';
import 'package:reem/features/catalog/data/datasources/impl/catalog_remote_datasource_impl.dart';
import 'package:reem/features/catalog/data/repositories/catalog_repository_impl.dart';
import 'package:reem/features/catalog/domain/repositories/catalog_repository.dart';
import 'package:reem/features/catalog/domain/usecases/get_product_details_usecase.dart';
import 'package:reem/features/catalog/domain/usecases/get_products_usecase.dart';
import 'package:reem/features/catalog/domain/usecases/get_trending_products_usecase.dart';
import 'package:reem/features/catalog/presentation/providers/catalog_notifier.dart';
import 'package:reem/features/catalog/presentation/providers/catalog_state.dart';

final catalogRemoteDataSourceProvider = Provider<CatalogRemoteDataSource>(
  (ref) => CatalogRemoteDataSourceImpl(ref.watch(dioProvider)),
);

final catalogRepositoryProvider = Provider<CatalogRepository>(
  (ref) => CatalogRepositoryImpl(
    remote: ref.watch(catalogRemoteDataSourceProvider),
  ),
);

final getTrendingProductsUseCaseProvider = Provider(
  (ref) => GetTrendingProductsUseCase(ref.watch(catalogRepositoryProvider)),
);

final getProductDetailsUseCaseProvider = Provider(
  (ref) => GetProductDetailsUseCase(ref.watch(catalogRepositoryProvider)),
);

final getProductsUseCaseProvider = Provider(
  (ref) => GetProductsUseCase(ref.watch(catalogRepositoryProvider)),
);

final catalogNotifierProvider =
    StateNotifierProvider<CatalogNotifier, CatalogState>((ref) {
  return CatalogNotifier(
    getProductsUseCase: ref.watch(getProductsUseCaseProvider),
    getTrendingProductsUseCase: ref.watch(getTrendingProductsUseCaseProvider),
  );
});

/// One product page, one state — keyed by the product it is showing.
///
/// This was a single global notifier, which meant every product page in the
/// navigation stack shared one slot. Opening a piece from "you may also like"
/// overwrote it, so pressing back returned to a screen that had already been
/// repainted as the product she had just left: the stack went back, the page
/// did not.
final productDetailsNotifierProvider = StateNotifierProvider.autoDispose
    .family<ProductDetailsNotifier, ProductDetailsState, String>((
      ref,
      productId,
    ) {
      return ProductDetailsNotifier(
        getProductDetailsUseCase: ref.watch(getProductDetailsUseCaseProvider),
      )..load(productId);
    });
