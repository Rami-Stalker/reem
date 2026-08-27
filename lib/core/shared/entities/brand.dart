// shared/entities/brand.dart

import 'package:equatable/equatable.dart';

/// A brand, with its own page. First-class because the client asked for one
/// (Q25): "نعم، صفحة لكل ماركة".
class Brand extends Equatable {
  final String id;
  final String slug;
  final String nameAr;
  final String nameEn;
  final String? logoUrl;
  final bool isVerified;

  const Brand({
    required this.id,
    required this.slug,
    required this.nameAr,
    required this.nameEn,
    this.logoUrl,
    this.isVerified = false,
  });

  String name({bool arabic = true}) =>
      arabic ? nameAr : (nameEn.isEmpty ? nameAr : nameEn);

  @override
  List<Object?> get props => [id, slug, nameAr, nameEn, logoUrl, isVerified];
}
