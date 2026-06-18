// shared/entities/user.dart

import 'package:equatable/equatable.dart';

/// Application roles. Mirrors the backend `UserRole` enum (lowercased on the wire).
enum UserRole { superAdmin, admin, support, seller, customer }

extension UserRoleX on UserRole {
  String get wire => switch (this) {
        UserRole.superAdmin => 'super_admin',
        UserRole.admin => 'admin',
        UserRole.support => 'support',
        UserRole.seller => 'seller',
        UserRole.customer => 'customer',
      };

  String get label => switch (this) {
        UserRole.superAdmin => 'Super Admin',
        UserRole.admin => 'Admin',
        UserRole.support => 'Support',
        UserRole.seller => 'Seller',
        UserRole.customer => 'Customer',
      };

  static UserRole fromWire(String? value) => switch (value?.toLowerCase()) {
        'super_admin' || 'superadmin' => UserRole.superAdmin,
        'admin' => UserRole.admin,
        'support' => UserRole.support,
        'seller' => UserRole.seller,
        _ => UserRole.customer,
      };
}

class User extends Equatable {
  final String id;
  final String name;
  final String username;
  final String phone;
  final String? email;
  final String? bio;
  final String? imageUrl;
  final String? location;
  final UserRole role;
  final bool isVerified;
  final bool mfaEnabled;
  final bool deviceVerificationRequired;
  final int followersCount;
  final int followingCount;
  final DateTime createdAt;

  const User({
    required this.id,
    required this.name,
    required this.username,
    required this.phone,
    this.email,
    this.bio,
    this.imageUrl,
    this.location,
    this.role = UserRole.customer,
    this.isVerified = false,
    this.mfaEnabled = false,
    this.deviceVerificationRequired = true,
    this.followersCount = 0,
    this.followingCount = 0,
    required this.createdAt,
  });

  bool get isAdmin =>
      role == UserRole.superAdmin || role == UserRole.admin;
  bool get isSupport => role == UserRole.support;
  bool get isSeller => role == UserRole.seller;
  bool get isCustomer => role == UserRole.customer;

  @override
  List<Object?> get props => [
        id,
        name,
        username,
        phone,
        email,
        bio,
        imageUrl,
        location,
        role,
        isVerified,
        mfaEnabled,
        deviceVerificationRequired,
        followersCount,
        followingCount,
        createdAt,
      ];
}
