import 'package:reem/core/result/result.dart';
import 'package:reem/core/shared/entities/user.dart';

abstract interface class AuthRepository {
  Future<Result<User>> login({
    required String email,
    required String password,
  });

  Future<Result<User>> register({
    required String name,
    required String email,
    required String password,
  });

  Future<Result<void>> logout();

  Future<Result<User?>> getCurrentUser();

  Future<Result<User>> refreshSession();

  Future<Result<void>> forgotPassword({required String email});
}
