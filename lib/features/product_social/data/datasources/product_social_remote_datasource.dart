import 'package:dio/dio.dart';

import 'package:reem/core/errors/error_mapper.dart';
import 'package:reem/core/network/api_endpoints.dart';
import 'package:reem/core/network/base_remote_datasource.dart';
import 'package:reem/features/discovery/data/models/product_page_model.dart';
import 'package:reem/features/product_social/domain/entities/product_engagement.dart';

/// The wire half of product social.
final class ProductSocialRemoteDataSource extends BaseRemoteDataSource {
  const ProductSocialRemoteDataSource(super.dio);

  /// Tallies and this viewer's own state for a screen of products.
  Future<Map<String, ProductEngagement>> engagement(List<String> ids) async {
    if (ids.isEmpty) return const {};
    final json = await getJson(
      ApiEndpoints.productEngagementBatch,
      query: {'ids': ids.join(',')},
    );
    final data = json['data'];
    if (data is! Map) return const {};
    return {
      for (final entry in data.entries)
        if (entry.value is Map)
          entry.key as String: engagementFromJson(
            Map<String, dynamic>.from(entry.value as Map),
          ),
    };
  }

  static ProductEngagement engagementFromJson(Map<String, dynamic> json) {
    return ProductEngagement(
      likes: json['likes_count'] as int? ?? 0,
      comments: json['comments_count'] as int? ?? 0,
      shares: json['shares_count'] as int? ?? 0,
      picks: json['picks_count'] as int? ?? 0,
      isLiked: json['is_liked'] as bool? ?? false,
      isSaved: json['is_saved'] as bool? ?? false,
      isPicked: json['is_picked'] as bool? ?? false,
      viewerKnown: true,
    );
  }

  /// Returns the tally after the write.
  Future<int> setLiked(String productId, {required bool liked}) async {
    final json = liked
        ? await _put(ApiEndpoints.productLike(productId))
        : await deleteJson(ApiEndpoints.productLike(productId));
    return json['likes_count'] as int? ?? 0;
  }

  Future<int> setPicked(
    String productId, {
    required bool picked,
    String? note,
  }) async {
    final json = picked
        ? await _put(
            ApiEndpoints.productPick(productId),
            body: {if (note != null && note.trim().isNotEmpty) 'note': note},
          )
        : await deleteJson(ApiEndpoints.productPick(productId));
    return json['picks_count'] as int? ?? 0;
  }

  /// The bookmark: a favourite, written as a desired state.
  Future<void> setSaved(String productId, {required bool saved}) async {
    if (saved) {
      await postJson(ApiEndpoints.favoriteByProduct(productId));
    } else {
      await deleteRequest(ApiEndpoints.favoriteByProduct(productId));
    }
  }

  Future<int> recordShare(String productId) async {
    final json = await postJson(ApiEndpoints.productShare(productId));
    return json['shares_count'] as int? ?? 0;
  }

  Future<void> report(String productId, String reason, {String? detail}) {
    return postJson(
      ApiEndpoints.productReport(productId),
      body: {
        'reason': reason,
        if (detail != null && detail.trim().isNotEmpty) 'detail': detail,
      },
    );
  }

  /// The pieces a woman added to her page.
  Future<ProductPageModel> picksOf(
    String userId, {
    int page = 1,
    int limit = 20,
  }) async {
    final json = await getJson(
      ApiEndpoints.userPicks(userId),
      query: {'page': page, 'limit': limit},
    );
    return ProductPageModel.fromJson(json);
  }

  Future<Map<String, dynamic>> _put(
    String path, {
    Map<String, dynamic>? body,
  }) async {
    try {
      final response = await dio.put<dynamic>(path, data: body);
      final data = response.data;
      if (data is Map<String, dynamic>) return data;
      if (data is Map) return Map<String, dynamic>.from(data);
      return const {};
    } on DioException catch (e) {
      throw ErrorMapper.fromDio(e);
    }
  }
}
