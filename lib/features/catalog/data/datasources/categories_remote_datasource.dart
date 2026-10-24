import 'package:ohara/features/catalog/domain/entities/category_attributes.dart';
import 'package:ohara/features/catalog/domain/entities/category_node.dart';

abstract interface class CategoriesRemoteDataSource {
  /// The whole tree, nested, roots first.
  Future<List<CategoryNode>> tree();

  /// The extra fields one category governs, with inheritance already resolved
  /// by the server.
  Future<CategoryAttributeSchema> attributeSchema(String categoryId);
}
