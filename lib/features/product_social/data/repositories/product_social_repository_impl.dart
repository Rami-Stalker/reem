import 'package:ohara/core/base/repository_handler.dart';
import 'package:ohara/core/result/result.dart';
import 'package:ohara/features/discovery/domain/entities/product_page.dart';
import 'package:ohara/features/product_social/data/datasources/product_social_remote_datasource.dart';
import 'package:ohara/features/product_social/domain/entities/product_engagement.dart';
import 'package:ohara/features/product_social/domain/repositories/product_social_repository.dart';

final class ProductSocialRepositoryImpl
    with RepositoryHandler
    implements ProductSocialRepository {
  const ProductSocialRepositoryImpl(this._remote);

  final ProductSocialRemoteDataSource _remote;

  @override
  Future<Result<Map<String, ProductEngagement>>> engagement(List<String> ids) =>
      guard(() => _remote.engagement(ids), operation: 'product engagement');

  @override
  Future<Result<int>> setLiked(String productId, {required bool liked}) =>
      guard(() => _remote.setLiked(productId, liked: liked));

  @override
  Future<Result<void>> setSaved(String productId, {required bool saved}) =>
      guard(() => _remote.setSaved(productId, saved: saved));

  @override
  Future<Result<int>> setPicked(
    String productId, {
    required bool picked,
    String? note,
  }) => guard(() => _remote.setPicked(productId, picked: picked, note: note));

  @override
  Future<Result<int>> recordShare(String productId) =>
      guard(() => _remote.recordShare(productId));

  @override
  Future<Result<void>> report(
    String productId,
    String reason, {
    String? detail,
  }) => guard(() => _remote.report(productId, reason, detail: detail));

  @override
  Future<Result<ProductPage>> picksOf(String userId, {int page = 1}) =>
      guard(() => _remote.picksOf(userId, page: page));
}
