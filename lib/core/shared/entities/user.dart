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
  /// The public badge: Reem has checked who this is.
  ///
  /// Granted by a reviewed `AccountVerification` and by nothing else. It used
  /// to be set the moment an account received a sign-in code, which is why it
  /// appeared beside every name in the app and meant nothing — see
  /// «توثيق الحساب». [phoneVerifiedAt] is the other question.
  final bool isVerified;

  /// When she proved the number she signs in with.
  ///
  /// Only ever populated for the signed-in user: the public shape of another
  /// woman's profile deliberately carries neither her number nor the fact
  /// that she proved it.
  final DateTime? phoneVerifiedAt;

  final bool mfaEnabled;
  final bool deviceVerificationRequired;
  final int followersCount;
  final int followingCount;
  final DateTime createdAt;

  /// What this account is allowed to do, as the server resolved it.
  ///
  /// Only ever populated for the signed-in user (`/auth/me`); it is empty on
  /// every other `User` the app parses, because a shopper's profile does not
  /// carry anybody's permissions. The admin console reads it to decide which
  /// destinations and which actions to *offer* — the server still decides what
  /// to permit, so an empty set here degrades to a plainer console, never to
  /// an unguarded one.
  final Set<String> permissions;

  /// True when a `Courier` row is attached to this account, as `/auth/me` and
  /// the sign-in response report it.
  ///
  /// Carrying parcels is not a role — there is no COURIER in [UserRole] — so
  /// nothing in the role tells the app that this woman has a round today. Only
  /// ever set for the signed-in user, like [permissions].
  final bool isCourier;

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
    this.phoneVerifiedAt,
    this.mfaEnabled = false,
    this.deviceVerificationRequired = true,
    this.followersCount = 0,
    this.followingCount = 0,
    this.permissions = const {},
    this.isCourier = false,
    required this.createdAt,
  });

  /// True when the server said this account holds [permission].
  ///
  /// A `super_admin` holds everything by construction on the server, and the
  /// resolver returns the full set for that role, so no special case is needed
  /// here — the set is the whole answer.
  bool can(String permission) => permissions.contains(permission);

  /// True when any one of [candidates] is held. Used for screens that a couple
  /// of different permissions can each open.
  bool canAny(Iterable<String> candidates) => candidates.any(can);

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
        phoneVerifiedAt,
        mfaEnabled,
        deviceVerificationRequired,
        followersCount,
        followingCount,
        permissions,
        isCourier,
        createdAt,
      ];
}
