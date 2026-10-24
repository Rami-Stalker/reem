import 'package:equatable/equatable.dart';

/// A saved delivery address, in the shape a Syrian delivery takes.
///
/// The governorate prices the journey and decides whether it can be delivered
/// at all; the district and [isRural] pick between Q53's two tiers; and the
/// landmark carries the way an address here is usually given — by what it is
/// near, not by a street number.
class AddressEntity extends Equatable {
  const AddressEntity({
    required this.id,
    required this.label,
    required this.recipientName,
    required this.recipientPhone,
    required this.governorate,
    required this.city,
    required this.addressLine,
    this.district,
    this.landmark,
    this.latitude,
    this.longitude,
    this.isRural = false,
    this.deliveryInstructions,
    this.isDefault = false,
  });

  final String id;
  final String label;

  /// Who receives it, which is not always the woman who ordered it.
  final String recipientName;
  final String recipientPhone;

  final String governorate;
  final String? district;
  final String city;
  final String addressLine;
  final String? landmark;

  /// The map pin, when she dropped one. Both or neither.
  final double? latitude;
  final double? longitude;

  bool get hasPin => latitude != null && longitude != null;

  /// Q53 P2 — the rural tier costs more and takes longer.
  final bool isRural;

  /// Q55 — «اتصلي قبل الوصول», kept with the address so she types it once.
  final String? deliveryInstructions;

  final bool isDefault;

  /// One line for a card: «دمشق، المزة — شارع الجلاء، بناء 12».
  String get summary {
    final place = [
      governorate,
      if (district != null && district!.trim().isNotEmpty) district,
      if (city.trim().isNotEmpty && city != governorate) city,
    ].join('، ');
    return '$place — $addressLine';
  }

  @override
  List<Object?> get props => [
    id,
    label,
    recipientName,
    recipientPhone,
    governorate,
    district,
    city,
    addressLine,
    landmark,
    latitude,
    longitude,
    isRural,
    deliveryInstructions,
    isDefault,
  ];
}
