import 'package:equatable/equatable.dart';

class AddressEntity extends Equatable {
  const AddressEntity({
    required this.id,
    required this.label,
    required this.street,
    required this.city,
    required this.country,
    this.postalCode,
    this.isDefault = false,
  });

  final String id;
  final String label;
  final String street;
  final String city;
  final String country;
  final String? postalCode;
  final bool isDefault;

  @override
  List<Object?> get props =>
      [id, label, street, city, country, postalCode, isDefault];
}
