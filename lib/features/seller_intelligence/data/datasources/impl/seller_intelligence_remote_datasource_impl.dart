import 'package:reem/core/network/api_endpoints.dart';
import 'package:reem/core/network/base_remote_datasource.dart';
import 'package:reem/features/seller_intelligence/data/datasources/seller_intelligence_remote_datasource.dart';
import 'package:reem/features/seller_intelligence/data/models/intelligence_mappers.dart';
import 'package:reem/features/seller_intelligence/domain/entities/intelligence.dart';

final class SellerIntelligenceRemoteDataSourceImpl extends BaseRemoteDataSource
    implements SellerIntelligenceRemoteDataSource {
  const SellerIntelligenceRemoteDataSourceImpl(super.dio);

  @override
  Future<DemandRadar> radar({int? days}) async {
    final json = await getJson(
      ApiEndpoints.sellerIntelligenceRadar,
      query: {'days': ?days},
    );
    return IntelligenceMappers.radar(json);
  }

  @override
  Future<ProductHealthList> products({int? days, int? limit}) async {
    final json = await getJson(
      ApiEndpoints.sellerIntelligenceProducts,
      query: {'days': ?days, 'limit': ?limit},
    );
    return IntelligenceMappers.productList(json);
  }

  @override
  Future<ProductHealth> product(String productId, {int? days}) async {
    final json = await getJson(
      ApiEndpoints.sellerIntelligenceProduct(productId),
      query: {'days': ?days},
    );
    return IntelligenceMappers.productDetail(json);
  }

  @override
  Future<List<DecliningListing>> declining() async {
    final rows = await getList(ApiEndpoints.sellerIntelligenceDeclining);
    return IntelligenceMappers.declining(rows);
  }

  @override
  Future<SellerHealth> health({int? days}) async {
    final json = await getJson(
      ApiEndpoints.sellerIntelligenceHealth,
      query: {'days': ?days},
    );
    return IntelligenceMappers.sellerHealth(json);
  }

  @override
  Future<List<HealthPoint>> healthHistory({int? days}) async {
    final json = await getJson(
      ApiEndpoints.sellerIntelligenceHealthHistory,
      query: {'days': ?days},
    );
    return IntelligenceMappers.healthHistory(json);
  }

  @override
  Future<void> snapshot() async {
    await postJson(ApiEndpoints.sellerIntelligenceSnapshot, body: const {});
  }
}
