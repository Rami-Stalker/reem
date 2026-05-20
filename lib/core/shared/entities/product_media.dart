// shared/entities/product_media.dart

import 'package:equatable/equatable.dart';

enum MediaType {
  image,
  video,
}

class ProductMedia extends Equatable {
  final String url;
  final MediaType type;

  const ProductMedia({
    required this.url,
    required this.type,
  });

  @override
  List<Object?> get props => [
        url,
        type,
      ];
}