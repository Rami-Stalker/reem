import 'package:equatable/equatable.dart';

/// A category surfaced in the home "Shop by category" showcase. Backed by an
/// image medallion; [productCount] powers a subtle "1.2k pieces" caption.
class HomeCategory extends Equatable {
  const HomeCategory({
    required this.id,
    required this.slug,
    required this.label,
    required this.imageUrl,
    this.productCount = 0,
    this.isFeatured = false,
  });

  final String id;

  /// What the department is addressed by. The tile used to route on [label],
  /// which is the Arabic display name — `/category/أزياء` matched no route and
  /// no category, so every tile on the rail was a dead end.
  final String slug;
  final String label;
  final String imageUrl;
  final int productCount;

  /// Featured categories get a gold accent ring in the showcase.
  final bool isFeatured;

  @override
  List<Object?> get props => [
    id,
    slug,
    label,
    imageUrl,
    productCount,
    isFeatured,
  ];
}
