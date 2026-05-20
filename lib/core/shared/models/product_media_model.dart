// shared/models/product_media_model.dart

import '../entities/product_media.dart';

class ProductMediaModel extends ProductMedia {
  const ProductMediaModel({
    required super.url,
    required super.type,
  });

  factory ProductMediaModel.fromJson(Map<String, dynamic> json) {
    return ProductMediaModel(
      url: json['url'],
      type: _mapType(json['type']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'url': url,
      'type': type.name,
    };
  }

  static MediaType _mapType(String type) {
    switch (type) {
      case 'video':
        return MediaType.video;

      default:
        return MediaType.image;
    }
  }
}