import 'package:ohara/core/base/repository_handler.dart';
import 'package:ohara/core/result/result.dart';
import 'package:ohara/features/seller_products/data/datasources/seller_products_remote_datasource.dart';
import 'package:ohara/features/seller_products/domain/entities/managed_product.dart';
import 'package:ohara/features/seller_products/domain/entities/product_draft.dart';
import 'package:ohara/features/seller_products/domain/entities/product_status.dart';
import 'package:ohara/features/seller_products/domain/repositories/seller_products_repository.dart';

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
  Future<Result<List<ManagedProduct>>> lowStock({int threshold = 5}) =>
      guard(() => remote.lowStock(threshold: threshold));

  @override
  Future<Result<ManagedProduct>> getOffer(String offerId) =>
      guard(() => remote.getOffer(offerId));

  @override
  Future<Result<ManagedProduct>> create(ProductDraft draft) =>
      guard(() => remote.create(draft));

  /// Saves an edit across both halves of the catalogue.
  ///
  /// The shared entry is written first and only when it actually changed and
  /// the seller is still the only one listing it — the server refuses the edit
  /// once a competitor lists the same product, which is the point: one seller
  /// must not be able to rewrite the page another sells from. Her own terms
  /// are then always saved, and it is the offer the caller gets back, because
  /// that is the row this screen renders.
  @override
  Future<Result<ManagedProduct>> updateListing(
    ManagedProduct listing,
    ProductDraft draft,
  ) =>
      guard(() async {
        if (!listing.hasCompetition && _canonicalChanged(listing, draft)) {
          await remote.updateProduct(listing.productId, draft);
        }
        return remote.updateOffer(listing.id, draft);
      });

  @override
  Future<Result<void>> archive(String offerId) =>
      guard(() => remote.archive(offerId));

  @override
  Future<Result<ManagedProduct>> setStatus(
    String offerId,
    ProductStatus status,
  ) =>
      guard(() => remote.setStatus(offerId, status));

  @override
  Future<Result<ManagedProduct>> adjustStock(String offerId, int delta) =>
      guard(() => remote.adjustStock(offerId, delta));

  /// Whether anything on the shared entry differs from what is on screen.
  /// Skipping the call when nothing moved keeps a price edit from touching the
  /// catalogue at all — and from failing on a product she no longer may edit.
  bool _canonicalChanged(ManagedProduct listing, ProductDraft draft) {
    final galleryChanged =
        listing.media.length != draft.media.length ||
        [
          for (var i = 0; i < listing.media.length; i++)
            listing.media[i].url != draft.media[i].url,
        ].contains(true);

    return listing.title != draft.title ||
        listing.description != draft.description ||
        listing.category.id != draft.categoryId ||
        galleryChanged;
  }
}
