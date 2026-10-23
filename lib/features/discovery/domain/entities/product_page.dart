import 'package:reem/core/domain/pagination/paginated_data.dart';
import 'package:reem/core/shared/entities/product.dart';
import 'package:reem/features/discovery/domain/entities/sponsored_product.dart';

/// A page of products plus the cursor needed for infinite scrolling.
class ProductPage {
  final List<Product> items;
  final int page;
  final bool hasNextPage;

  /// Paid slots for this page, labelled and shown above [items] — never mixed
  /// into them. Only the first page carries any.
  final List<SponsoredProduct> sponsored;

  const ProductPage({
    required this.items,
    required this.page,
    required this.hasNextPage,
    this.sponsored = const [],
  });

  static const empty = ProductPage(items: [], page: 0, hasNextPage: false);

  PaginatedData<Product> toPaginatedData({int limit = 20}) {
    return PaginatedData<Product>(
      items: items,
      pageInfo: PageInfo(page: page, limit: limit, hasNextPage: hasNextPage),
    );
  }
}
