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
    super.mfaEnabled,
    super.deviceVerificationRequired,
    super.followersCount,
    super.followingCount,
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
      mfaEnabled: json['mfa_enabled'] as bool? ?? false,
      deviceVerificationRequired:
          json['device_verification_required'] as bool? ?? true,
      followersCount: json['followers_count'] as int? ?? 0,
      followingCount: json['following_count'] as int? ?? 0,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
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
        mfaEnabled: user.mfaEnabled,
        deviceVerificationRequired: user.deviceVerificationRequired,
        followersCount: user.followersCount,
        followingCount: user.followingCount,
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
      'mfa_enabled': mfaEnabled,
      'device_verification_required': deviceVerificationRequired,
      'followers_count': followersCount,
      'following_count': followingCount,
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
    bool? mfaEnabled,
    bool? deviceVerificationRequired,
    int? followersCount,
    int? followingCount,
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
      mfaEnabled: mfaEnabled ?? this.mfaEnabled,
      deviceVerificationRequired:
          deviceVerificationRequired ?? this.deviceVerificationRequired,
      followersCount: followersCount ?? this.followersCount,
      followingCount: followingCount ?? this.followingCount,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
