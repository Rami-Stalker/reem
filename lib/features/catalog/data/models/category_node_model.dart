import 'package:ohara/core/shared/models/category_model.dart';
import 'package:ohara/features/catalog/domain/entities/category_node.dart';

/// Parses `GET /categories`, which answers with the roots and nests the rest.
///
/// The server sends `path` only on the flattened `?leaves=true` form, so the
/// nested form builds it on the way down — a leaf without its ancestry reads
/// as «فساتين سهرة» with no clue which department it belongs to, and two
/// departments may well both have one.
abstract final class CategoryNodeModel {
  static List<CategoryNode> listFromJson(List<dynamic> json) => [
        for (final row in json)
          if (row is Map) fromJson(row.cast<String, dynamic>(), const []),
      ];

  static CategoryNode fromJson(
    Map<String, dynamic> json,
    List<String> ancestry,
  ) {
    final category = CategoryModel.fromJson(json);
    final name = category.nameAr.isEmpty ? category.nameEn : category.nameAr;
    final path = [...ancestry, name];

    final rawChildren = json['children'];
    final children = rawChildren is List
        ? [
            for (final child in rawChildren)
              if (child is Map) fromJson(child.cast<String, dynamic>(), path),
          ]
        : const <CategoryNode>[];

    return CategoryNode(
      category: category,
      children: children,
      // Trust the server's flag when it sends one; fall back to the shape.
      isLeaf: json['is_leaf'] as bool? ?? children.isEmpty,
      path: (json['path'] as List?)?.cast<String>() ?? path,
    );
  }
}
