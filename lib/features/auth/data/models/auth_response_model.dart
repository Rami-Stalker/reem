import 'package:ohara/core/shared/models/user_model.dart';

import 'package:ohara/features/auth/data/models/token_model.dart';

class AuthResponseModel {
  final UserModel user;
  final TokenModel tokens;

  const AuthResponseModel({
    required this.user,
    required this.tokens,
  });

  factory AuthResponseModel.fromJson(Map<String, dynamic> json) {
    return AuthResponseModel(
      user: UserModel.fromAuthPayload(json),
      tokens: TokenModel.fromJson(json['tokens'] as Map<String, dynamic>),
    );
  }
}