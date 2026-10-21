// shared/models/user_model.dart

import 'package:reem/core/shared/entities/user.dart';

class UserModel extends User {
  const UserModel({
    required super.id,
    required super.name,
    required super.username,
    required super.phone,
    super.email,
    super.bio,
    super.imageUrl,
    super.location,
    super.role,
    super.isVerified,
    super.phoneVerifiedAt,
    super.mfaEnabled,
    super.deviceVerificationRequired,
    super.followersCount,
    super.followingCount,
    super.permissions,
    super.isCourier,
    required super.createdAt,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] as String,
      name: json['name'] as String,
      username: json['username'] as String? ?? '',
      phone: json['phone'] as String? ?? '',
      email: json['email'] as String?,
      bio: json['bio'] as String?,
      imageUrl: json['image_url'] as String?,
      location: json['location'] as String?,
      role: UserRoleX.fromWire(json['role'] as String?),
      isVerified: json['is_verified'] as bool? ?? false,
      phoneVerifiedAt: DateTime.tryParse(
        json['phone_verified_at'] as String? ?? '',
      ),
      mfaEnabled: json['mfa_enabled'] as bool? ?? false,
      deviceVerificationRequired:
          json['device_verification_required'] as bool? ?? true,
      followersCount: json['followers_count'] as int? ?? 0,
      followingCount: json['following_count'] as int? ?? 0,
      permissions: {
        for (final permission in (json['permissions'] as List? ?? const []))
          if (permission is String) permission,
      },
      isCourier: json['is_courier'] as bool? ?? false,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  /// The signed-in user out of an auth envelope.
  ///
  /// Every endpoint that hands back a session — `login`, `otp/login/verify`,
  /// `register`, `refresh`, `me` — returns `{user, permissions, …}` with the
  /// permission set *beside* the user rather than inside it, because it is
  /// resolved per request and is not part of the public user shape.
  ///
  /// Three call sites folded that in by hand and one of them forgot, which is
  /// the whole bug: an administrator who signed in through the code flow got a
  /// console with an empty sidebar, because the nav is drawn from a permission
  /// set the client had thrown away. One fold, so a fourth entry point cannot
  /// repeat it.
  factory UserModel.fromAuthPayload(Map<String, dynamic> envelope) {
    final user = envelope['user'];
    final json = user is Map
        ? Map<String, dynamic>.from(user)
        : Map<String, dynamic>.from(envelope);
    return UserModel.fromJson({
      ...json,
      if (envelope['permissions'] is List)
        'permissions': envelope['permissions'],
    });
  }

  factory UserModel.fromEntity(User user) => UserModel(
        id: user.id,
        name: user.name,
        username: user.username,
        phone: user.phone,
        email: user.email,
        bio: user.bio,
        imageUrl: user.imageUrl,
        location: user.location,
        role: user.role,
        isVerified: user.isVerified,
        phoneVerifiedAt: user.phoneVerifiedAt,
        mfaEnabled: user.mfaEnabled,
        deviceVerificationRequired: user.deviceVerificationRequired,
        followersCount: user.followersCount,
        followingCount: user.followingCount,
        permissions: user.permissions,
        isCourier: user.isCourier,
        createdAt: user.createdAt,
      );

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'username': username,
      'phone': phone,
      'email': email,
      'bio': bio,
      'image_url': imageUrl,
      'location': location,
      'role': role.wire,
      'is_verified': isVerified,
      'phone_verified_at': phoneVerifiedAt?.toIso8601String(),
      'mfa_enabled': mfaEnabled,
      'device_verification_required': deviceVerificationRequired,
      'followers_count': followersCount,
      'following_count': followingCount,
      'permissions': permissions.toList(),
      'created_at': createdAt.toIso8601String(),
    };
  }

  UserModel copyWith({
    String? id,
    String? name,
    String? username,
    String? phone,
    String? email,
    String? bio,
    String? imageUrl,
    String? location,
    UserRole? role,
    bool? isVerified,
    DateTime? phoneVerifiedAt,
    bool? mfaEnabled,
    bool? deviceVerificationRequired,
    int? followersCount,
    int? followingCount,
    Set<String>? permissions,
    DateTime? createdAt,
  }) {
    return UserModel(
      id: id ?? this.id,
      name: name ?? this.name,
      username: username ?? this.username,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      bio: bio ?? this.bio,
      imageUrl: imageUrl ?? this.imageUrl,
      location: location ?? this.location,
      role: role ?? this.role,
      isVerified: isVerified ?? this.isVerified,
      phoneVerifiedAt: phoneVerifiedAt ?? this.phoneVerifiedAt,
      mfaEnabled: mfaEnabled ?? this.mfaEnabled,
      deviceVerificationRequired:
          deviceVerificationRequired ?? this.deviceVerificationRequired,
      followersCount: followersCount ?? this.followersCount,
      followingCount: followingCount ?? this.followingCount,
      permissions: permissions ?? this.permissions,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
