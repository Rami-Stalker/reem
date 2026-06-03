import 'package:reem/core/shared/models/user_model.dart';

import '../models/auth_response_model.dart';

abstract interface class AuthRemoteDataSource {
  Future<AuthResponseModel> login({
    required String email,
    required String password,
  });

  Future<AuthResponseModel> register({
    required String name,
    required String email,
    required String password,
  });

  Future<AuthResponseModel> refreshToken(
    String refreshToken,
  );

  Future<UserModel> getCurrentUser();

  Future<void> forgotPassword({required String email});
}