import 'package:reem/core/shared/models/product_model.dart';

import 'package:reem/features/discovery/domain/entities/product_page.dart';
import 'package:reem/features/discovery/domain/entities/sponsored_product.dart';

class ProductPageModel extends ProductPage {
  const ProductPageModel({
    required super.items,
    required super.page,
    required super.hasNextPage,
    super.sponsored,
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
      sponsored: _sponsored(json['sponsored']),
    );
  }

  /// A slot without the offer that paid for it cannot be credited, so it is
  /// dropped rather than shown as an unattributable advert.
  static List<SponsoredProduct> _sponsored(Object? raw) {
    if (raw is! List) return const [];
    final out = <SponsoredProduct>[];
    for (final entry in raw.whereType<Map>()) {
      final json = Map<String, dynamic>.from(entry);
      final offerId = json['sponsored_offer_id']?.toString() ?? '';
      if (offerId.isEmpty) continue;
      out.add(
        SponsoredProduct(
          product: ProductModel.fromJson(json),
          offerId: offerId,
          placement: json['sponsored_placement']?.toString() ?? 'search',
        ),
      );
    }
    return out;
  }
}
