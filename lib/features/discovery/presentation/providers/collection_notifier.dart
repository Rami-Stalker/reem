import 'package:reem/core/presentation/providers/paginated_notifier.dart';
import 'package:reem/core/result/result.dart';
import 'package:reem/core/shared/entities/product.dart';

import 'package:reem/features/discovery/domain/entities/product_page.dart';

/// Fetches one page of a collection. Each collection wires a different fetcher,
/// but they all share this paginating notifier (DRY + independent state).
typedef ProductPageFetcher = Future<Result<ProductPage>> Function(int page);

class CollectionNotifier extends PaginatedNotifier<Product> {
  CollectionNotifier(ProductPageFetcher fetch)
    : super((request) async {
        final result = await fetch(request.page);
        return result.map((page) => page.toPaginatedData(limit: request.limit));
      });
}
