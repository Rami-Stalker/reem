// shared/entities/user.dart

import 'package:equatable/equatable.dart';

class User extends Equatable {
  final String id;
  final String name;
  final String username;
  final String email;
  final String? bio;
  final String? imageUrl;
  final bool isVerified;
  final DateTime createdAt;

  const User({
    required this.id,
    required this.name,
    required this.username,
    required this.email,
    this.bio,
    this.imageUrl,
    this.isVerified = false,
    required this.createdAt,
  });

  @override
  List<Object?> get props => [
        id,
        name,
        username,
        email,
        bio,
        imageUrl,
        isVerified,
        createdAt,
      ];
}