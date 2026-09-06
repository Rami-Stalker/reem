import 'package:reem/core/network/api_endpoints.dart';
import 'package:reem/core/network/base_remote_datasource.dart';
import 'package:reem/features/reputation/data/datasources/reputation_remote_datasource.dart';
import 'package:reem/features/reputation/data/models/reputation_models.dart';

final class ReputationRemoteDataSourceImpl extends BaseRemoteDataSource
    implements ReputationRemoteDataSource {
  const ReputationRemoteDataSourceImpl(super.dio);

  @override
  Future<List<ReviewModel>> getProductReviews(String productId) async {
    final list = await getList(ApiEndpoints.productReviews(productId));
    return list
        .whereType<Map>()
        .map((item) => ReviewModel.fromJson(Map<String, dynamic>.from(item)))
        .toList();
  }

  @override
  Future<MyReviewsModel> getMyReviews() async =>
      MyReviewsModel.fromJson(await getJson(ApiEndpoints.myReviews));

  @override
  Future<ReviewModel> submitProductReview({
    required String productId,
    required int rating,
    String? title,
    String? body,
    String? orderId,
  }) async {
    final json = await postJson(
      ApiEndpoints.productReviews(productId),
      body: _reviewBody(
        rating: rating,
        title: title,
        body: body,
        orderId: orderId,
      ),
    );
    return ReviewModel.fromJson(json);
  }

  @override
  Future<List<ReviewModel>> getSellerReviews(String sellerId) async {
    final list = await getList(ApiEndpoints.sellerReviews(sellerId));
    return list
        .whereType<Map>()
        .map((item) => ReviewModel.fromJson(Map<String, dynamic>.from(item)))
        .toList();
  }

  @override
  Future<ReviewModel> submitSellerReview({
    required String sellerId,
    required int rating,
    String? title,
    String? body,
    String? orderId,
  }) async {
    final json = await postJson(
      ApiEndpoints.sellerReviews(sellerId),
      body: _reviewBody(
        rating: rating,
        title: title,
        body: body,
        orderId: orderId,
      ),
    );
    return ReviewModel.fromJson(json);
  }

  @override
  Future<SellerReputationSummaryModel> getSellerReputation(
    String sellerId,
  ) async {
    final json = await getJson(ApiEndpoints.sellerReputation(sellerId));
    return SellerReputationSummaryModel.fromJson(json);
  }

  @override
  Future<void> requestTrustedSellerVerification({Object? evidence}) async {
    await postJson(
      ApiEndpoints.trustedSellerVerification,
      body: evidence == null ? null : {'evidence': evidence},
    );
  }

  Map<String, dynamic> _reviewBody({
    required int rating,
    String? title,
    String? body,
    String? orderId,
  }) {
    return {
      'rating': rating,
      if (title != null && title.trim().isNotEmpty) 'title': title.trim(),
      if (body != null && body.trim().isNotEmpty) 'body': body.trim(),
      if (orderId != null && orderId.trim().isNotEmpty) 'order_id': orderId,
    };
  }
}
