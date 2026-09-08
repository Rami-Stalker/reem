import 'package:reem/core/result/result.dart';
import 'package:reem/features/seller_intelligence/domain/entities/intelligence.dart';

abstract interface class SellerIntelligenceRepository {
  Future<Result<DemandRadar>> radar({int? days});
  Future<Result<ProductHealthList>> products({int? days, int? limit});
  Future<Result<ProductHealth>> product(String productId, {int? days});
  Future<Result<List<DecliningListing>>> declining();
  Future<Result<SellerHealth>> health({int? days});
  Future<Result<List<HealthPoint>>> healthHistory({int? days});
  Future<Result<void>> snapshot();
}
