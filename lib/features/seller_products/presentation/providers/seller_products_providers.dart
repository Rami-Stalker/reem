import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../../../../core/presentation/providers/core_providers.dart';
import '../../data/datasources/impl/seller_products_remote_datasource_impl.dart';
import '../../data/datasources/seller_products_remote_datasource.dart';
import '../../data/repositories/seller_products_repository_impl.dart';
import '../../domain/repositories/seller_products_repository.dart';
import '../../domain/usecases/adjust_stock_usecase.dart';
import '../../domain/usecases/create_product_usecase.dart';
import '../../domain/usecases/delete_product_usecase.dart';
import '../../domain/usecases/get_my_products_usecase.dart';
import '../../domain/usecases/set_product_status_usecase.dart';
import '../../domain/usecases/update_product_usecase.dart';
import 'my_products_notifier.dart';
import 'my_products_state.dart';
import 'product_form_notifier.dart';
import 'product_form_state.dart';

final sellerProductsRemoteDataSourceProvider =
    Provider<SellerProductsRemoteDataSource>(
  (ref) => SellerProductsRemoteDataSourceImpl(ref.watch(dioProvider)),
);

final sellerProductsRepositoryProvider = Provider<SellerProductsRepository>(
  (ref) => SellerProductsRepositoryImpl(
    ref.watch(sellerProductsRemoteDataSourceProvider),
  ),
);

final getMyProductsUseCaseProvider = Provider(
  (ref) => GetMyProductsUseCase(ref.watch(sellerProductsRepositoryProvider)),
);
final createProductUseCaseProvider = Provider(
  (ref) => CreateProductUseCase(ref.watch(sellerProductsRepositoryProvider)),
);
final updateProductUseCaseProvider = Provider(
  (ref) => UpdateProductUseCase(ref.watch(sellerProductsRepositoryProvider)),
);
final deleteProductUseCaseProvider = Provider(
  (ref) => DeleteProductUseCase(ref.watch(sellerProductsRepositoryProvider)),
);
final setProductStatusUseCaseProvider = Provider(
  (ref) => SetProductStatusUseCase(ref.watch(sellerProductsRepositoryProvider)),
);
final adjustStockUseCaseProvider = Provider(
  (ref) => AdjustStockUseCase(ref.watch(sellerProductsRepositoryProvider)),
);

final myProductsNotifierProvider =
    StateNotifierProvider.autoDispose<MyProductsNotifier, MyProductsState>(
  (ref) => MyProductsNotifier(
    getMyProducts: ref.watch(getMyProductsUseCaseProvider),
    deleteProduct: ref.watch(deleteProductUseCaseProvider),
    setProductStatus: ref.watch(setProductStatusUseCaseProvider),
  )..load(),
);

final productFormNotifierProvider =
    StateNotifierProvider.autoDispose<ProductFormNotifier, ProductFormState>(
  (ref) => ProductFormNotifier(
    createProduct: ref.watch(createProductUseCaseProvider),
    updateProduct: ref.watch(updateProductUseCaseProvider),
  ),
);
