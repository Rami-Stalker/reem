import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:reem/core/localization/l10n_extension.dart';
import 'package:reem/features/catalog/domain/entities/category_node.dart';
import 'package:reem/features/catalog/presentation/providers/categories_provider.dart';
import 'package:reem/features/discovery/presentation/providers/discovery_providers.dart';
import 'package:reem/features/discovery/presentation/providers/sponsored_providers.dart';
import 'package:reem/features/discovery/presentation/screens/collection_screen.dart';

/// A category page is just a discovery collection scoped to one category —
/// real, paginated, infinite-scrolling products from the backend.
class CategoryScreen extends ConsumerWidget {
  const CategoryScreen({super.key, required this.category});

  /// The department's slug, as it travels in the route.
  final String category;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final slug = category.toLowerCase();

    return CollectionScreen(
      provider: categoryProductsProvider(slug),
      title: _title(context, ref, slug),
      sponsoredKey: categorySponsoredKey(slug),
    );
  }

  /// The department's own name, looked up in the catalogue tree.
  ///
  /// The title used to be the slug with its first letter capitalised, which
  /// put "Baby-clothing" at the head of an otherwise Arabic page. The tree is
  /// already cached for the product form, so this costs nothing; while it
  /// loads, or for a slug it does not know, the generic heading stands in.
  String _title(BuildContext context, WidgetRef ref, String slug) {
    final match = _find(switch (ref.watch(categoryTreeProvider)) {
      AsyncData(:final value) => value,
      _ => const <CategoryNode>[],
    }, slug);
    return match?.name ?? context.l10n.categoryTitle;
  }

  static CategoryNode? _find(List<CategoryNode> nodes, String slug) {
    for (final node in nodes) {
      if (node.category.slug.toLowerCase() == slug) return node;
      final inChildren = _find(node.children, slug);
      if (inChildren != null) return inChildren;
    }
    return null;
  }
}
