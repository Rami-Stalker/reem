import 'package:reem/core/base/repository_handler.dart';
import 'package:reem/core/result/result.dart';
import 'package:reem/core/shared/entities/product.dart';
import 'package:reem/features/catalog/data/datasources/catalog_remote_datasource.dart';
import 'package:reem/features/catalog/domain/repositories/catalog_repository.dart';

class CatalogRepositoryImpl with RepositoryHandler implements CatalogRepository {
  const CatalogRepositoryImpl({required this.remote});

  final CatalogRemoteDataSource remote;

  @override
  Future<Result<List<Product>>> getTrendingProducts() =>
      guard(() => remote.getTrendingProducts());

  @override
  Future<Result<Product>> getProductById(String id) =>
      guard(() => remote.getProductById(id));

  @override
  Future<Result<List<Product>>> getProducts() =>
      guard(() => remote.getProducts());
}
