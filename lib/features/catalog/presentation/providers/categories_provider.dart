import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ohara/core/presentation/providers/core_providers.dart';
import 'package:ohara/features/catalog/data/datasources/categories_remote_datasource.dart';
import 'package:ohara/features/catalog/data/datasources/impl/categories_remote_datasource_impl.dart';
import 'package:ohara/features/catalog/domain/entities/category_attributes.dart';
import 'package:ohara/features/catalog/domain/entities/category_node.dart';

final categoriesRemoteDataSourceProvider = Provider<CategoriesRemoteDataSource>(
  (ref) => CategoriesRemoteDataSourceImpl(ref.watch(dioProvider)),
);

/// The catalogue's category tree.
///
/// Kept alive rather than auto-disposed: it is small, it changes about as often
/// as the shop's departments do, and it is read every time a product form opens.
/// Re-fetching it per keystroke would be the only thing about this screen that
/// touched the network.
final categoryTreeProvider = FutureProvider<List<CategoryNode>>((ref) async {
  ref.keepAlive();
  return ref.watch(categoriesRemoteDataSourceProvider).tree();
});

/// Every selectable end of the tree, flattened, each carrying its ancestry.
final categoryLeavesProvider = Provider<AsyncValue<List<CategoryNode>>>((ref) {
  return ref.watch(categoryTreeProvider).whenData(
        (tree) => [for (final root in tree) ...root.leaves],
      );
});

/// The leaf behind an id, for rendering a saved product's category by name.
final categoryByIdProvider = Provider.family<CategoryNode?, String>((ref, id) {
  final leaves = switch (ref.watch(categoryLeavesProvider)) {
    AsyncData(:final value) => value,
    _ => const <CategoryNode>[],
  };
  for (final leaf in leaves) {
    if (leaf.id == id) return leaf;
  }
  return null;
});

/// The extra fields a chosen category asks for (Q27 P2).
///
/// Kept alive per category for the same reason the tree is: the product form
/// reads it on every rebuild while she fills the rest of the page in, and it
/// changes about as often as the department list does. A category that governs
/// nothing extra answers with an empty schema, not an error.
final categoryAttributesProvider = FutureProvider.family
    .autoDispose<CategoryAttributeSchema, String>((ref, categoryId) async {
      ref.keepAlive();
      return ref
          .watch(categoriesRemoteDataSourceProvider)
          .attributeSchema(categoryId);
    });
