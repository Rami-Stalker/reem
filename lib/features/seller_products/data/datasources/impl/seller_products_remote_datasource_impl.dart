import 'package:ohara/core/network/api_endpoints.dart';
import 'package:ohara/core/network/base_remote_datasource.dart';
import 'package:ohara/features/seller_products/data/datasources/seller_products_remote_datasource.dart';
import 'package:ohara/features/seller_products/data/models/managed_product_model.dart';
import 'package:ohara/features/seller_products/data/models/managed_product_page_model.dart';
import 'package:ohara/features/seller_products/data/models/product_draft_request.dart';
import 'package:ohara/features/seller_products/domain/entities/product_draft.dart';
import 'package:ohara/features/seller_products/domain/entities/product_status.dart';

/// The seller's catalogue, spoken in the contract the server actually serves.
///
/// Reading was migrated to offers when the central catalogue landed; writing
/// was not, and had been calling three routes that no longer existed
/// (`/seller/products/:id/status`, `/seller/products/:id/stock`, and
/// `DELETE /seller/products/:id`) plus posting a flat body that
/// `POST /seller/products` rejects outright. Publishing a listing, restocking
/// one, removing one and creating one had all been silently failing.
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
      ApiEndpoints.sellerOffers,
      query: {
        'page': page,
        'limit': limit,
        'status': ?status?.wire,
        if (query != null && query.isNotEmpty) 'q': query,
        'sort': ?sort,
      },
    );
    return ManagedProductPageModel.fromJson(json);
  }

  @override
  Future<List<ManagedProductModel>> lowStock({int threshold = 5}) async {
    final json = await getList(
      ApiEndpoints.sellerOffersLowStock,
      query: {'threshold': threshold},
    );
    return [
      for (final row in json.whereType<Map>())
        ManagedProductModel.fromJson(row.cast<String, dynamic>()),
    ];
  }

  @override
  Future<ManagedProductModel> getOffer(String offerId) async =>
      ManagedProductModel.fromJson(
        await getJson(ApiEndpoints.sellerOfferById(offerId)),
      );

  @override
  Future<ManagedProductModel> create(ProductDraft draft) async {
    final request = ProductDraftRequest(draft);
    final json = await postJson(
      ApiEndpoints.sellerProducts,
      body: request.toCreateJson(),
    );

    var created = ManagedProductModel.fromCreateResponse(json);

    // Canonical variants only receive their ids when the product is written,
    // so per-variant price and stock cannot ride along on the create call.
    // They are attached here, in the one moment those ids are first known.
    final offerVariants = request.offerVariantsFor(created.variants);
    final wantsPublished = draft.status != ProductStatus.draft;

    if (offerVariants.isNotEmpty || wantsPublished) {
      created = ManagedProductModel.fromJson(
        await patchJson(
          ApiEndpoints.sellerOfferById(created.id),
          body: {
            if (offerVariants.isNotEmpty) 'variants': offerVariants,
            if (wantsPublished) 'status': draft.status.wire,
          },
        ),
        fallbackProduct: created,
      );
    }

    return created;
  }

  @override
  Future<ManagedProductModel> updateOffer(
    String offerId,
    ProductDraft draft,
  ) async =>
      ManagedProductModel.fromJson(
        await patchJson(
          ApiEndpoints.sellerOfferById(offerId),
          body: ProductDraftRequest(draft).toOfferJson(),
        ),
      );

  @override
  Future<void> updateProduct(String productId, ProductDraft draft) =>
      patchJson(
        ApiEndpoints.sellerProductById(productId),
        body: ProductDraftRequest(draft).toProductJson(),
      );

  @override
  Future<void> archive(String offerId) =>
      deleteRequest(ApiEndpoints.sellerOfferById(offerId));

  @override
  Future<ManagedProductModel> setStatus(
    String offerId,
    ProductStatus status,
  ) async =>
      ManagedProductModel.fromJson(
        await patchJson(
          ApiEndpoints.sellerOfferById(offerId),
          body: {'status': status.wire},
        ),
      );

  @override
  Future<ManagedProductModel> adjustStock(String offerId, int delta) async =>
      ManagedProductModel.fromJson(
        await postJson(
          ApiEndpoints.sellerOfferStock(offerId),
          body: {'delta': delta},
        ),
      );
}
