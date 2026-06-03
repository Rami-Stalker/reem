import 'package:equatable/equatable.dart';

class CouponEntity extends Equatable {
  const CouponEntity({
    required this.id,
    required this.code,
    required this.title,
    required this.discountPercent,
    required this.expiresAt,
    this.isActive = true,
  });

  final String id;
  final String code;
  final String title;
  final double discountPercent;
  final DateTime expiresAt;
  final bool isActive;

  @override
  List<Object?> get props =>
      [id, code, title, discountPercent, expiresAt, isActive];
}
