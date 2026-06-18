import 'package:equatable/equatable.dart';

/// A category surfaced in the home "Shop by category" showcase. Backed by an
/// image medallion; [productCount] powers a subtle "1.2k pieces" caption.
class HomeCategory extends Equatable {
  const HomeCategory({
    required this.id,
    required this.label,
    required this.imageUrl,
    this.productCount = 0,
    this.isFeatured = false,
  });

  final String id;
  final String label;
  final String imageUrl;
  final int productCount;

  /// Featured categories get a gold accent ring in the showcase.
  final bool isFeatured;

  @override
  List<Object?> get props => [id, label, imageUrl, productCount, isFeatured];
}
