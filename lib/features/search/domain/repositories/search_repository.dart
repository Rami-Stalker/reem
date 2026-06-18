import 'package:reem/core/result/result.dart';

import '../../../discovery/domain/entities/product_page.dart';

abstract interface class SearchRepository {
  Future<Result<ProductPage>> searchProducts(
    String query, {
    int page,
    int limit,
  });
}
