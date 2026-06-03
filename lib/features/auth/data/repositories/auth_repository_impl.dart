import 'package:reem/core/base/repository_handler.dart';
import 'package:reem/core/errors/app_exception.dart';
import 'package:reem/core/result/result.dart';
import 'package:reem/core/shared/entities/user.dart';

import '../../domain/repositories/auth_repository.dart';
import '../datasources/auth_local_datasource.dart';
import '../datasources/auth_remote_datasource.dart';

class AuthRepositoryImpl with RepositoryHandler implements AuthRepository {
  const AuthRepositoryImpl({
    required this.remote,
    required this.local,
  });

  final AuthRemoteDataSource remote;
  final AuthLocalDataSource local;

  Future<void> _persistTokens({
    required String access,
    required String refresh,
  }) async {
    await local.saveAccessToken(access);
    await local.saveRefreshToken(refresh);
  }

  @override
  Future<Result<User>> login({
    required String email,
    required String password,
  }) =>
      guard(() async {
        final response = await remote.login(email: email, password: password);
        await _persistTokens(
          access: response.tokens.accessToken,
          refresh: response.tokens.refreshToken,
        );
        return response.user;
      });

  @override
  Future<Result<User>> register({
    required String name,
    required String email,
    required String password,
  }) =>
      guard(() async {
        final response = await remote.register(
          name: name,
          email: email,
          password: password,
        );
        await _persistTokens(
          access: response.tokens.accessToken,
          refresh: response.tokens.refreshToken,
        );
        return response.user;
      });

  @override
  Future<Result<void>> logout() => guard(() async {
        await local.clear();
      });

  @override
  Future<Result<User?>> getCurrentUser() => guard(() async {
        final token = await local.getAccessToken();
        if (token == null || token.isEmpty) return null;
        return remote.getCurrentUser();
      });

  @override
  Future<Result<User>> refreshSession() => guard(() async {
        final refresh = await local.getRefreshToken();
        if (refresh == null || refresh.isEmpty) {
          throw const UnauthorizedException(
            'Session expired. Please sign in again.',
          );
        }
        final response = await remote.refreshToken(refresh);
        await _persistTokens(
          access: response.tokens.accessToken,
          refresh: response.tokens.refreshToken,
        );
        return response.user;
      });

  @override
  Future<Result<void>> forgotPassword({required String email}) =>
      guard(() => remote.forgotPassword(email: email));
}
