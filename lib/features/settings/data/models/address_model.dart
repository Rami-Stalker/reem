import 'package:ohara/features/settings/domain/entities/address_draft.dart';
import 'package:ohara/features/settings/domain/entities/address_entity.dart';

class AddressModel extends AddressEntity {
  const AddressModel({
    required super.id,
    required super.label,
    required super.recipientName,
    required super.recipientPhone,
    required super.governorate,
    required super.city,
    required super.addressLine,
    super.district,
    super.landmark,
    super.isRural,
    super.deliveryInstructions,
    super.isDefault,
  });

  factory AddressModel.fromJson(Map<String, dynamic> json) {
    return AddressModel(
      id: json['id'] as String,
      label: json['label'] as String? ?? 'المنزل',
      recipientName: json['recipient_name'] as String? ?? '',
      recipientPhone: json['recipient_phone'] as String? ?? '',
      governorate: json['governorate'] as String? ?? '',
      district: json['district'] as String?,
      city: json['city'] as String? ?? '',
      addressLine: json['address_line'] as String? ?? '',
      landmark: json['landmark'] as String?,
      isRural: json['is_rural'] as bool? ?? false,
      deliveryInstructions: json['delivery_instructions'] as String?,
      isDefault: json['is_default'] as bool? ?? false,
    );
  }

  /// The body for a create or an edit.
  ///
  /// Every field is sent, including the nullable ones as explicit nulls: the
  /// server's `UpdateAddressDto` treats an absent key as "leave it alone", so
  /// omitting a landmark she has just cleared would silently keep the old one.
  static Map<String, dynamic> bodyFrom(AddressDraft draft) {
    String? trimmed(String? value) {
      final text = value?.trim();
      return text == null || text.isEmpty ? null : text;
    }

    return {
      'label': draft.label.trim(),
      'recipient_name': draft.recipientName.trim(),
      'recipient_phone': draft.recipientPhone.trim(),
      'governorate': draft.governorate.trim(),
      'district': trimmed(draft.district),
      'city': draft.city.trim(),
      'address_line': draft.addressLine.trim(),
      'landmark': trimmed(draft.landmark),
      'is_rural': draft.isRural,
      'delivery_instructions': trimmed(draft.deliveryInstructions),
      'is_default': draft.isDefault,
    };
  }

  /// What a write sends back. `id` is deliberately absent: the server assigns
  /// it, and echoing one on create is how a client ends up asking to overwrite
  /// a row it does not own.
  Map<String, dynamic> toJson() {
    return {
      'label': label,
      'recipient_name': recipientName,
      'recipient_phone': recipientPhone,
      'governorate': governorate,
      if (district != null) 'district': district,
      'city': city,
      'address_line': addressLine,
      if (landmark != null) 'landmark': landmark,
      'is_rural': isRural,
      if (deliveryInstructions != null)
        'delivery_instructions': deliveryInstructions,
      'is_default': isDefault,
    };
  }
}
