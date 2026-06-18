import 'product_status.dart';

/// One media item being authored.
class MediaDraft {
  final String url;
  final bool isVideo;
  const MediaDraft(this.url, {this.isVideo = false});
}

/// One variant being authored.
class VariantDraft {
  final String name;
  final String? sku;
  final double? price;
  final int stock;
  const VariantDraft({
    required this.name,
    this.sku,
    this.price,
    this.stock = 0,
  });
}

/// Editable product payload shared by create & edit flows.
class ProductDraft {
  final String title;
  final String description;
  final String category;
  final double price;
  final double? oldPrice;
  final int stock;
  final ProductStatus status;
  final bool isFeatured;
  final bool showInFeed;
  final List<MediaDraft> media;
  final List<VariantDraft> variants;

  const ProductDraft({
    required this.title,
    required this.description,
    required this.category,
    required this.price,
    this.oldPrice,
    this.stock = 0,
    this.status = ProductStatus.draft,
    this.isFeatured = false,
    this.showInFeed = true,
    this.media = const [],
    this.variants = const [],
  });
}
