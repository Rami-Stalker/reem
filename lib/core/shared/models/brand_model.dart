// shared/models/brand_model.dart

import 'package:reem/core/shared/entities/brand.dart';

class BrandModel extends Brand {
  const BrandModel({
    required super.id,
    required super.slug,
    required super.nameAr,
    required super.nameEn,
    super.logoUrl,
    super.isVerified,
  });

  factory BrandModel.fromJson(Map<String, dynamic> json) {
    final nameAr = json['name_ar'] as String? ?? '';
    return BrandModel(
      id: json['id'] as String? ?? '',
      slug: json['slug'] as String? ?? '',
      nameAr: nameAr,
      nameEn: json['name_en'] as String? ?? nameAr,
      logoUrl: json['logo_url'] as String?,
      isVerified: json['is_verified'] as bool? ?? false,
    );
  }

  factory BrandModel.fromEntity(Brand brand) => BrandModel(
        id: brand.id,
        slug: brand.slug,
        nameAr: brand.nameAr,
        nameEn: brand.nameEn,
        logoUrl: brand.logoUrl,
        isVerified: brand.isVerified,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'slug': slug,
        'name_ar': nameAr,
        'name_en': nameEn,
        'logo_url': logoUrl,
        'is_verified': isVerified,
      };
}
