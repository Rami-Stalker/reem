import 'package:reem/core/domain/pagination/paginated_data.dart';
import 'package:reem/core/shared/entities/product.dart';

/// A page of products plus the cursor needed for infinite scrolling.
class ProductPage {
  final List<Product> items;
  final int page;
  final bool hasNextPage;

  const ProductPage({
    required this.items,
    required this.page,
    required this.hasNextPage,
  });

  static const empty = ProductPage(items: [], page: 0, hasNextPage: false);

  PaginatedData<Product> toPaginatedData({int limit = 20}) {
    return PaginatedData<Product>(
      items: items,
      pageInfo: PageInfo(page: page, limit: limit, hasNextPage: hasNextPage),
    );
  }
}
