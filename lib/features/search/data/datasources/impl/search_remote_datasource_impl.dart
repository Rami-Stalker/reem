import 'package:reem/core/network/api_endpoints.dart';
import 'package:reem/core/network/base_remote_datasource.dart';

import '../../../../discovery/data/models/product_page_model.dart';
import '../search_remote_datasource.dart';

final class SearchRemoteDataSourceImpl extends BaseRemoteDataSource
    implements SearchRemoteDataSource {
  const SearchRemoteDataSourceImpl(super.dio);

  @override
  Future<ProductPageModel> searchProducts(
    String query, {
    int page = 1,
    int limit = 20,
  }) async {
    final json = await getJson(
      ApiEndpoints.searchProducts,
      query: {'q': query, 'page': page, 'limit': limit},
    );
    return ProductPageModel.fromJson(json);
  }
}
