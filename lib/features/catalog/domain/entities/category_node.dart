import 'package:equatable/equatable.dart';

import 'package:reem/core/shared/entities/category.dart';

/// A category with the branch beneath it — root → section → leaf.
///
/// Products attach to leaves only, and `POST /seller/products` takes a leaf's
/// UUID and nothing else, so [path] carries the ancestry a picker shows as a
/// crumb («ملابس › فساتين › فساتين سهرة») and [isLeaf] says whether this node
/// may be chosen at all.
class CategoryNode extends Equatable {
  const CategoryNode({
    required this.category,
    this.children = const [],
    this.isLeaf = true,
    this.path = const [],
  });

  final Category category;
  final List<CategoryNode> children;
  final bool isLeaf;

  /// The ancestor names, outermost first, this node included.
  final List<String> path;

  String get id => category.id;
  String get name => category.nameAr.isEmpty
      ? category.nameEn
      : category.nameAr;

  String get crumb => path.isEmpty ? name : path.join(' › ');

  /// Every selectable end below this node, flattened.
  Iterable<CategoryNode> get leaves sync* {
    if (isLeaf) {
      yield this;
      return;
    }
    for (final child in children) {
      yield* child.leaves;
    }
  }

  /// Whether this node or anything under it answers to [query].
  bool matches(String query) {
    final needle = query.trim().toLowerCase();
    if (needle.isEmpty) return true;
    if (category.nameAr.toLowerCase().contains(needle)) return true;
    if (category.nameEn.toLowerCase().contains(needle)) return true;
    if (category.slug.toLowerCase().contains(needle)) return true;
    return children.any((child) => child.matches(needle));
  }

  @override
  List<Object?> get props => [category, children, isLeaf, path];
}
