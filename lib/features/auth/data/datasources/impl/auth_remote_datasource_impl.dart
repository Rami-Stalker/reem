import 'package:dio/dio.dart';
import 'package:reem/core/network/api_endpoints.dart';
import 'package:reem/core/network/base_remote_datasource.dart';
import 'package:reem/core/shared/models/user_model.dart';
import 'package:reem/features/auth/data/datasources/auth_remote_datasource.dart';
import 'package:reem/features/auth/data/models/auth_response_model.dart';

final class AuthRemoteDataSourceImpl extends BaseRemoteDataSource
    implements AuthRemoteDataSource {
  const AuthRemoteDataSourceImpl(super.dio);

  @override
  Future<AuthResponseModel> login({
    required String email,
    required String password,
  }) async {
    final json = await postJson(
      ApiEndpoints.authLogin,
      body: {'email': email, 'password': password},
    );
    return AuthResponseModel.fromJson(json);
  }

  @override
  Future<AuthResponseModel> register({
    required String name,
    required String email,
    required String password,
  }) async {
    final json = await postJson(
      ApiEndpoints.authRegister,
      body: {'name': name, 'email': email, 'password': password},
    );
    return AuthResponseModel.fromJson(json);
  }

  @override
  Future<AuthResponseModel> refreshToken(String refreshToken) async {
    final json = await postJson(
      ApiEndpoints.authRefresh,
      body: {'refresh_token': refreshToken},
    );
    return AuthResponseModel.fromJson(json);
  }

  @override
  Future<UserModel> getCurrentUser() async {
    final json = await getJson(ApiEndpoints.authMe);
    final userJson = json['user'] is Map<String, dynamic>
        ? json['user'] as Map<String, dynamic>
        : json;
    return UserModel.fromJson(userJson);
  }

  @override
  Future<void> forgotPassword({required String email}) async {
    await postJson(ApiEndpoints.authForgotPassword, body: {'email': email});
  }
}
