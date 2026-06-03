import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../../../../core/providers/core_providers.dart';
import '../../data/datasources/catalog_remote_datasource.dart';
import '../../data/datasources/impl/catalog_remote_datasource_impl.dart';
import '../../data/repositories/catalog_repository_impl.dart';
import '../../domain/repositories/catalog_repository.dart';
import '../../domain/usecases/get_product_details_usecase.dart';
import '../../domain/usecases/get_products_usecase.dart';
import '../../domain/usecases/get_trending_products_usecase.dart';
import 'catalog_notifier.dart';
import 'catalog_state.dart';

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

final productDetailsNotifierProvider =
    StateNotifierProvider<ProductDetailsNotifier, ProductDetailsState>((ref) {
  return ProductDetailsNotifier(
    getProductDetailsUseCase: ref.watch(getProductDetailsUseCaseProvider),
  );
});
