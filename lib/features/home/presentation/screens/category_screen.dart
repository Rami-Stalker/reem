import 'package:flutter/material.dart';

import '../../../discovery/presentation/providers/discovery_providers.dart';
import '../../../discovery/presentation/screens/collection_screen.dart';

/// A category page is just a discovery collection scoped to one category —
/// real, paginated, infinite-scrolling products from the backend.
class CategoryScreen extends StatelessWidget {
  const CategoryScreen({super.key, required this.category});

  final String category;

  @override
  Widget build(BuildContext context) {
    final normalized = category.toLowerCase();
    final title = category.isEmpty
        ? 'Category'
        : '${category[0].toUpperCase()}${category.substring(1)}';

    return CollectionScreen(
      provider: categoryProductsProvider(normalized),
      title: title,
    );
  }
}
