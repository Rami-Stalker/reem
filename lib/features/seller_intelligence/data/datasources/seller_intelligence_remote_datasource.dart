import 'package:reem/features/seller_intelligence/domain/entities/intelligence.dart';

/// `/seller/intelligence/*`.
///
/// None of these methods takes a seller id, and that is the point: the server
/// scopes every route to the token and would refuse one anyway. A signature
/// without the parameter is a signature nobody can pass the wrong value to.
abstract interface class SellerIntelligenceRemoteDataSource {
  Future<DemandRadar> radar({int? days});

  Future<ProductHealthList> products({int? days, int? limit});

  Future<ProductHealth> product(String productId, {int? days});

  Future<SellerHealth> health({int? days});

  Future<List<HealthPoint>> healthHistory({int? days});

  /// Freeze today's figures so the history chart has a point for today.
  Future<void> snapshot();
}
