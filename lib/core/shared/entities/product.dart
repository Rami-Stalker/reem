// shared/entities/product.dart

import 'package:equatable/equatable.dart';
import 'product_media.dart';
import 'user.dart';

class Product extends Equatable {
  final String id;
  final User seller;

  final String title;
  final String description;

  final double price;
  final double? oldPrice;

  final List<ProductMedia> media;

  final bool isAvailable;
  final bool isFeatured;

  final int viewsCount;
  final int likesCount;

  final DateTime createdAt;

  const Product({
    required this.id,
    required this.seller,
    required this.title,
    required this.description,
    required this.price,
    this.oldPrice,
    required this.media,
    required this.isAvailable,
    required this.isFeatured,
    required this.viewsCount,
    required this.likesCount,
    required this.createdAt,
  });

  @override
  List<Object?> get props => [
        id,
        seller,
        title,
        description,
        price,
        oldPrice,
        media,
        isAvailable,
        isFeatured,
        viewsCount,
        likesCount,
        createdAt,
      ];
}