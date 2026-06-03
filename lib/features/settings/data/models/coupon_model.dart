import '../../domain/entities/coupon_entity.dart';

class CouponModel extends CouponEntity {
  const CouponModel({
    required super.id,
    required super.code,
    required super.title,
    required super.discountPercent,
    required super.expiresAt,
    super.isActive,
  });

  factory CouponModel.fromJson(Map<String, dynamic> json) {
    return CouponModel(
      id: json['id'] as String,
      code: json['code'] as String,
      title: json['title'] as String? ?? json['code'] as String,
      discountPercent: (json['discount_percent'] as num?)?.toDouble() ??
          (json['discount'] as num?)?.toDouble() ??
          0,
      expiresAt: DateTime.parse(
        json['expires_at'] as String? ?? DateTime.now().toIso8601String(),
      ),
      isActive: json['is_active'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'code': code,
      'title': title,
      'discount_percent': discountPercent,
      'expires_at': expiresAt.toIso8601String(),
      'is_active': isActive,
    };
  }
}
