import '../../../discovery/data/models/product_page_model.dart';

abstract interface class SearchRemoteDataSource {
  Future<ProductPageModel> searchProducts(
    String query, {
    int page,
    int limit,
  });
}
