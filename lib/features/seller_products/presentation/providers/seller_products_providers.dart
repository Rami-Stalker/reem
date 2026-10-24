import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import 'package:ohara/core/presentation/providers/core_providers.dart';
import 'package:ohara/features/seller_products/data/datasources/impl/seller_products_remote_datasource_impl.dart';
import 'package:ohara/features/seller_products/data/datasources/seller_products_remote_datasource.dart';
import 'package:ohara/features/seller_products/data/repositories/seller_products_repository_impl.dart';
import 'package:ohara/features/seller_products/domain/repositories/seller_products_repository.dart';
import 'package:ohara/features/seller_products/domain/usecases/adjust_stock_usecase.dart';
import 'package:ohara/features/seller_products/domain/usecases/archive_listing_usecase.dart';
import 'package:ohara/features/seller_products/domain/usecases/create_product_usecase.dart';
import 'package:ohara/features/seller_products/domain/usecases/get_low_stock_usecase.dart';
import 'package:ohara/features/seller_products/domain/usecases/get_my_products_usecase.dart';
import 'package:ohara/features/seller_products/domain/usecases/set_product_status_usecase.dart';
import 'package:ohara/features/seller_products/domain/usecases/update_product_usecase.dart';
import 'package:ohara/features/seller_products/presentation/providers/my_products_notifier.dart';
import 'package:ohara/features/seller_products/presentation/providers/my_products_state.dart';
import 'package:ohara/features/seller_products/presentation/providers/product_form_notifier.dart';
import 'package:ohara/features/seller_products/presentation/providers/product_form_state.dart';

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
final archiveListingUseCaseProvider = Provider(
  (ref) => ArchiveListingUseCase(ref.watch(sellerProductsRepositoryProvider)),
);
final getLowStockUseCaseProvider = Provider(
  (ref) => GetLowStockUseCase(ref.watch(sellerProductsRepositoryProvider)),
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
    archiveListing: ref.watch(archiveListingUseCaseProvider),
    setProductStatus: ref.watch(setProductStatusUseCaseProvider),
    adjustStock: ref.watch(adjustStockUseCaseProvider),
  )..load(),
);

final productFormNotifierProvider =
    StateNotifierProvider.autoDispose<ProductFormNotifier, ProductFormState>(
  (ref) => ProductFormNotifier(
    createProduct: ref.watch(createProductUseCaseProvider),
    updateProduct: ref.watch(updateProductUseCaseProvider),
  ),
);
