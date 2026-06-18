import 'package:reem/core/shared/entities/user.dart';

class RegisterRequestModel {
  final String name;
  final String? email;
  final String phone;
  final String password;
  final UserRole role;

  const RegisterRequestModel({
    required this.name,
    this.email,
    required this.phone,
    required this.password,
    this.role = UserRole.customer,
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        if (email != null) 'email': email,
        'phone': phone,
        'password': password,
        'role': role.wire,
      };
}
