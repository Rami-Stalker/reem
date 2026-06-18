import 'package:reem/core/shared/models/product_model.dart';

import '../models/product_page_model.dart';

abstract interface class DiscoveryRemoteDataSource {
  Future<ProductPageModel> getCollection(String key,
      {int page, int limit, String? sort});
  Future<ProductPageModel> getCategory(String category,
      {int page, int limit, String? sort});
  Future<ProductPageModel> getSeller(String sellerId, {int page, int limit});
  Future<ProductPageModel> getSimilar(String productId, {int page, int limit});
  Future<ProductPageModel> getRecommended({int page, int limit});
  Future<Map<String, List<ProductModel>>> getHome();
}
