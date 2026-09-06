import 'package:reem/core/base/repository_handler.dart';
import 'package:reem/core/result/result.dart';
import 'package:reem/features/seller_intelligence/data/datasources/seller_intelligence_remote_datasource.dart';
import 'package:reem/features/seller_intelligence/domain/entities/intelligence.dart';
import 'package:reem/features/seller_intelligence/domain/repositories/seller_intelligence_repository.dart';

class SellerIntelligenceRepositoryImpl
    with RepositoryHandler
    implements SellerIntelligenceRepository {
  const SellerIntelligenceRepositoryImpl(this.remote);

  final SellerIntelligenceRemoteDataSource remote;

  @override
  Future<Result<DemandRadar>> radar({int? days}) =>
      guard(() => remote.radar(days: days), operation: 'demand radar');

  @override
  Future<Result<ProductHealthList>> products({int? days, int? limit}) => guard(
    () => remote.products(days: days, limit: limit),
    operation: 'product intelligence',
  );

  @override
  Future<Result<ProductHealth>> product(String productId, {int? days}) => guard(
    () => remote.product(productId, days: days),
    operation: 'product health',
  );

  @override
  Future<Result<SellerHealth>> health({int? days}) =>
      guard(() => remote.health(days: days), operation: 'seller health');

  @override
  Future<Result<List<HealthPoint>>> healthHistory({int? days}) => guard(
    () => remote.healthHistory(days: days),
    operation: 'seller health history',
  );

  @override
  Future<Result<void>> snapshot() =>
      guard(remote.snapshot, operation: 'health snapshot');
}
