import 'package:equatable/equatable.dart';

import 'package:ohara/features/settings/domain/entities/address_entity.dart';

/// An address as she typed it, before the server has one.
///
/// Deliberately not an [AddressEntity] with a blank id. A draft has no id
/// because it does not exist yet, and giving it an empty one is how a create
/// ends up being sent to `PATCH /addresses/` — the shape should make the
/// mistake unsayable rather than merely unlikely.
class AddressDraft extends Equatable {
  const AddressDraft({
    required this.label,
    required this.recipientName,
    required this.recipientPhone,
    required this.governorate,
    required this.city,
    required this.addressLine,
    this.district,
    this.landmark,
    this.isRural = false,
    this.deliveryInstructions,
    this.isDefault = false,
  });

  /// The values already on a saved address, for the edit form to open with.
  factory AddressDraft.from(AddressEntity address) => AddressDraft(
    label: address.label,
    recipientName: address.recipientName,
    recipientPhone: address.recipientPhone,
    governorate: address.governorate,
    city: address.city,
    addressLine: address.addressLine,
    district: address.district,
    landmark: address.landmark,
    isRural: address.isRural,
    deliveryInstructions: address.deliveryInstructions,
    isDefault: address.isDefault,
  );

  final String label;
  final String recipientName;
  final String recipientPhone;
  final String governorate;
  final String? district;
  final String city;
  final String addressLine;
  final String? landmark;
  final bool isRural;
  final String? deliveryInstructions;
  final bool isDefault;

  AddressDraft copyWith({
    String? label,
    String? recipientName,
    String? recipientPhone,
    String? governorate,
    String? district,
    String? city,
    String? addressLine,
    String? landmark,
    bool? isRural,
    String? deliveryInstructions,
    bool? isDefault,
  }) {
    return AddressDraft(
      label: label ?? this.label,
      recipientName: recipientName ?? this.recipientName,
      recipientPhone: recipientPhone ?? this.recipientPhone,
      governorate: governorate ?? this.governorate,
      district: district ?? this.district,
      city: city ?? this.city,
      addressLine: addressLine ?? this.addressLine,
      landmark: landmark ?? this.landmark,
      isRural: isRural ?? this.isRural,
      deliveryInstructions: deliveryInstructions ?? this.deliveryInstructions,
      isDefault: isDefault ?? this.isDefault,
    );
  }

  @override
  List<Object?> get props => [
    label,
    recipientName,
    recipientPhone,
    governorate,
    district,
    city,
    addressLine,
    landmark,
    isRural,
    deliveryInstructions,
    isDefault,
  ];
}
