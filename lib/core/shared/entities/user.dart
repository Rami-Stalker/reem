// shared/entities/user.dart

import 'package:equatable/equatable.dart';

/// Application roles. Mirrors the backend `UserRole` enum (lowercased on the wire).
enum UserRole {
  superAdmin,
  operationsAdmin,
  supportAdmin,
  financeAdmin,
  contentModerator,
  admin,
  support,
  seller,
  customer,
}

extension UserRoleX on UserRole {
  String get wire => switch (this) {
        UserRole.superAdmin => 'super_admin',
        UserRole.operationsAdmin => 'operations_admin',
        UserRole.supportAdmin => 'support_admin',
        UserRole.financeAdmin => 'finance_admin',
        UserRole.contentModerator => 'content_moderator',
        UserRole.admin => 'admin',
        UserRole.support => 'support',
        UserRole.seller => 'seller',
        UserRole.customer => 'customer',
      };

  String get label => switch (this) {
        UserRole.superAdmin => 'Super Admin',
        UserRole.operationsAdmin => 'Operations Admin',
        UserRole.supportAdmin => 'Support Admin',
        UserRole.financeAdmin => 'Finance Admin',
        UserRole.contentModerator => 'Content Moderator',
        UserRole.admin => 'Admin',
        UserRole.support => 'Support',
        UserRole.seller => 'Seller',
        UserRole.customer => 'Customer',
      };

  static UserRole fromWire(String? value) => switch (value?.toLowerCase()) {
        'super_admin' || 'superadmin' => UserRole.superAdmin,
        'operations_admin' || 'operationsadmin' => UserRole.operationsAdmin,
        'support_admin' || 'supportadmin' => UserRole.supportAdmin,
        'finance_admin' || 'financeadmin' => UserRole.financeAdmin,
        'content_moderator' || 'contentmoderator' => UserRole.contentModerator,
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
      role == UserRole.superAdmin ||
      role == UserRole.operationsAdmin ||
      role == UserRole.supportAdmin ||
      role == UserRole.financeAdmin ||
      role == UserRole.contentModerator ||
      role == UserRole.admin ||
      role == UserRole.support;
  bool get isSupport =>
      role == UserRole.support || role == UserRole.supportAdmin;
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
