// shared/models/category_model.dart

import 'package:ohara/core/shared/entities/category.dart';

class CategoryModel extends Category {
  const CategoryModel({
    required super.id,
    required super.slug,
    required super.nameAr,
    required super.nameEn,
    super.level,
    super.parentId,
    super.iconUrl,
    super.imageUrl,
    super.isSensitive,
    super.returnsAllowed,
  });

  factory CategoryModel.fromJson(Map<String, dynamic> json) {
    final nameAr = json['name_ar'] as String? ?? '';
    return CategoryModel(
      id: json['id'] as String? ?? '',
      slug: json['slug'] as String? ?? '',
      nameAr: nameAr,
      nameEn: json['name_en'] as String? ?? nameAr,
      level: json['level'] as int? ?? 2,
      parentId: json['parent_id'] as String?,
      iconUrl: json['icon_url'] as String?,
      imageUrl: json['image_url'] as String?,
      isSensitive: json['is_sensitive'] as bool? ?? false,
      returnsAllowed: json['returns_allowed'] as bool? ?? true,
    );
  }

  /// A placeholder for the rare payload that omits the category (a deleted
  /// catalogue entry referenced from an old order, for instance). Rendering an
  /// empty chip beats crashing the screen.
  static const CategoryModel unknown = CategoryModel(
    id: '',
    slug: '',
    nameAr: '',
    nameEn: '',
  );

  factory CategoryModel.fromEntity(Category category) => CategoryModel(
        id: category.id,
        slug: category.slug,
        nameAr: category.nameAr,
        nameEn: category.nameEn,
        level: category.level,
        parentId: category.parentId,
        iconUrl: category.iconUrl,
        imageUrl: category.imageUrl,
        isSensitive: category.isSensitive,
        returnsAllowed: category.returnsAllowed,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'slug': slug,
        'name_ar': nameAr,
        'name_en': nameEn,
        'level': level,
        'parent_id': parentId,
        'icon_url': iconUrl,
        'image_url': imageUrl,
        'is_sensitive': isSensitive,
        'returns_allowed': returnsAllowed,
      };
}
