import 'package:reem/core/network/api_endpoints.dart';
import 'package:reem/core/network/base_remote_datasource.dart';

import '../seller_products_remote_datasource.dart';
import '../../../domain/entities/product_draft.dart';
import '../../../domain/entities/product_status.dart';
import '../../models/managed_product_model.dart';
import '../../models/managed_product_page_model.dart';
import '../../models/product_draft_request.dart';

final class SellerProductsRemoteDataSourceImpl extends BaseRemoteDataSource
    implements SellerProductsRemoteDataSource {
  const SellerProductsRemoteDataSourceImpl(super.dio);

  @override
  Future<ManagedProductPageModel> getMyProducts({
    int page = 1,
    int limit = 20,
    ProductStatus? status,
    String? query,
    String? sort,
  }) async {
    final json = await getJson(
      ApiEndpoints.sellerProducts,
      query: {
        'page': page,
        'limit': limit,
        if (status != null) 'status': status.wire,
        if (query != null && query.isNotEmpty) 'q': query,
        if (sort != null) 'sort': sort,
      },
    );
    return ManagedProductPageModel.fromJson(json);
  }

  @override
  Future<ManagedProductModel> getProduct(String id) async {
    final json = await getJson(ApiEndpoints.sellerProductById(id));
    return ManagedProductModel.fromJson(json);
  }

  @override
  Future<ManagedProductModel> create(ProductDraft draft) async {
    final json = await postJson(
      ApiEndpoints.sellerProducts,
      body: ProductDraftRequest(draft).toCreateJson(),
    );
    return ManagedProductModel.fromJson(json);
  }

  @override
  Future<ManagedProductModel> update(String id, ProductDraft draft) async {
    final json = await patchJson(
      ApiEndpoints.sellerProductById(id),
      body: ProductDraftRequest(draft).toUpdateJson(),
    );
    return ManagedProductModel.fromJson(json);
  }

  @override
  Future<void> delete(String id) =>
      deleteRequest(ApiEndpoints.sellerProductById(id));

  @override
  Future<ManagedProductModel> setStatus(String id, ProductStatus status) async {
    final json = await patchJson(
      ApiEndpoints.sellerProductStatus(id),
      body: {'status': status.wire},
    );
    return ManagedProductModel.fromJson(json);
  }

  @override
  Future<ManagedProductModel> adjustStock(String id, int delta) async {
    final json = await postJson(
      ApiEndpoints.sellerProductStock(id),
      body: {'delta': delta},
    );
    return ManagedProductModel.fromJson(json);
  }
}
