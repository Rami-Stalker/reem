import 'package:reem/core/base/repository_handler.dart';
import 'package:reem/core/result/result.dart';
import 'package:reem/features/seller_products/data/datasources/seller_products_remote_datasource.dart';
import 'package:reem/features/seller_products/domain/entities/managed_product.dart';
import 'package:reem/features/seller_products/domain/entities/product_draft.dart';
import 'package:reem/features/seller_products/domain/entities/product_status.dart';
import 'package:reem/features/seller_products/domain/repositories/seller_products_repository.dart';

class SellerProductsRepositoryImpl
    with RepositoryHandler
    implements SellerProductsRepository {
  const SellerProductsRepositoryImpl(this.remote);

  final SellerProductsRemoteDataSource remote;

  @override
  Future<Result<ManagedProductPage>> getMyProducts({
    int page = 1,
    int limit = 20,
    ProductStatus? status,
    String? query,
    String? sort,
  }) =>
      guard(() => remote.getMyProducts(
            page: page,
            limit: limit,
            status: status,
            query: query,
            sort: sort,
          ));

  @override
  Future<Result<ManagedProduct>> getProduct(String id) =>
      guard(() => remote.getProduct(id));

  @override
  Future<Result<ManagedProduct>> create(ProductDraft draft) =>
      guard(() => remote.create(draft));

  @override
  Future<Result<ManagedProduct>> update(String id, ProductDraft draft) =>
      guard(() => remote.update(id, draft));

  @override
  Future<Result<void>> delete(String id) => guard(() => remote.delete(id));

  @override
  Future<Result<ManagedProduct>> setStatus(String id, ProductStatus status) =>
      guard(() => remote.setStatus(id, status));

  @override
  Future<Result<ManagedProduct>> adjustStock(String id, int delta) =>
      guard(() => remote.adjustStock(id, delta));
}
