import 'package:reem/core/shared/models/product_model.dart';

import 'package:reem/features/discovery/domain/entities/product_page.dart';

class ProductPageModel extends ProductPage {
  const ProductPageModel({
    required super.items,
    required super.page,
    required super.hasNextPage,
  });

  factory ProductPageModel.fromJson(Map<String, dynamic> json) {
    final items = (json['data'] as List? ?? [])
        .map((e) => ProductModel.fromJson(e as Map<String, dynamic>))
        .toList();
    final meta = json['pagination'] as Map<String, dynamic>? ?? const {};
    return ProductPageModel(
      items: items,
      page: meta['page'] as int? ?? 1,
      hasNextPage: meta['has_next_page'] as bool? ?? false,
    );
  }
}
