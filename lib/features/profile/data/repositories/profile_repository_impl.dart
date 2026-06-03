import 'package:reem/core/base/repository_handler.dart';
import 'package:reem/core/result/result.dart';
import 'package:reem/core/shared/entities/product.dart';
import 'package:reem/core/shared/entities/user.dart';

import '../../domain/entities/order_entity.dart';
import '../../domain/repositories/profile_repository.dart';
import '../datasources/profile_remote_datasource.dart';

class ProfileRepositoryImpl with RepositoryHandler implements ProfileRepository {
  const ProfileRepositoryImpl({required this.remote});

  final ProfileRemoteDataSource remote;

  @override
  Future<Result<User>> getProfile() => guard(() => remote.getProfile());

  @override
  Future<Result<List<Product>>> getFavorites() =>
      guard(() => remote.getFavorites());

  @override
  Future<Result<List<OrderEntity>>> getOrders() =>
      guard(() => remote.getOrders());

  @override
  Future<Result<void>> toggleFavorite(String productId) =>
      guard(() => remote.toggleFavorite(productId));
}
