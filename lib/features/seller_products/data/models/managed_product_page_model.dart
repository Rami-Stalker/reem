import 'package:ohara/features/seller_products/data/models/managed_product_model.dart';
import 'package:ohara/features/seller_products/domain/entities/managed_product.dart';

class ManagedProductPageModel extends ManagedProductPage {
  const ManagedProductPageModel({
    required super.items,
    required super.page,
    required super.totalPages,
    required super.hasNextPage,
  });

  factory ManagedProductPageModel.fromJson(Map<String, dynamic> json) {
    final items = (json['data'] as List? ?? [])
        .map((e) => ManagedProductModel.fromJson(e as Map<String, dynamic>))
        .toList();
    final meta = json['pagination'] as Map<String, dynamic>? ?? const {};
    return ManagedProductPageModel(
      items: items,
      page: meta['page'] as int? ?? 1,
      totalPages: meta['total_pages'] as int? ?? 1,
      hasNextPage: meta['has_next_page'] as bool? ?? false,
    );
  }
}
