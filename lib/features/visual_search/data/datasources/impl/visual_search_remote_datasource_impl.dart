import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:reem/core/errors/app_exception.dart';
import 'package:reem/core/errors/error_mapper.dart';
import 'package:reem/core/network/api_endpoints.dart';
import 'package:reem/core/network/base_remote_datasource.dart';
import 'package:reem/features/ai_stylist/domain/entities/stylist_recommendation.dart';
import 'package:reem/features/visual_search/data/datasources/visual_search_remote_datasource.dart';
import 'package:reem/features/visual_search/data/models/visual_search_models.dart';
import 'package:reem/features/visual_search/domain/entities/visual_match.dart';
import 'package:reem/features/visual_search/domain/entities/visual_search_session.dart';

final class VisualSearchRemoteDataSourceImpl extends BaseRemoteDataSource
    implements VisualSearchRemoteDataSource {
  const VisualSearchRemoteDataSourceImpl(super.dio);

  @override
  Future<VisualSearchBootstrap> bootstrap() async {
    final json = await getJson(ApiEndpoints.visualSearchBootstrap);
    return bootstrapFromJson(json);
  }

  /// The one request that is not JSON in and JSON out.
  ///
  /// Written against Dio directly rather than through the base helpers because
  /// it needs three things they do not offer: a multipart body, upload
  /// progress for a spinner she is watching, and its own timeouts. A
  /// photograph over a Syrian mobile connection is not a thirty-second
  /// request, and the default client timeout would abandon searches that were
  /// going to succeed.
  @override
  Future<VisualSearchSession> search({
    required Uint8List bytes,
    required String filename,
    required VisualSearchSource source,
    String? note,
    void Function(double progress)? onProgress,
  }) async {
    try {
      final form = FormData.fromMap({
        'source': source.wire,
        if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
        'image': MultipartFile.fromBytes(bytes, filename: filename),
      });

      final response = await dio.post<dynamic>(
        ApiEndpoints.visualSearches,
        data: form,
        options: Options(
          sendTimeout: const Duration(minutes: 2),
          // Generous on the receive side too: the server decodes the image,
          // scores several thousand vectors and may call a vision model.
          receiveTimeout: const Duration(minutes: 2),
        ),
        onSendProgress: (sent, total) {
          if (total > 0) onProgress?.call(sent / total);
        },
      );

      final data = response.data;
      if (data is! Map) {
        throw const ServerException('Visual search returned an unexpected response.');
      }
      return sessionFromJson(Map<String, dynamic>.from(data));
    } on DioException catch (error) {
      throw ErrorMapper.fromDio(error);
    }
  }

  @override
  Future<VisualSearchSession> refine({
    required String sessionId,
    required String text,
  }) async {
    final json = await postJson(
      ApiEndpoints.visualRefine(sessionId),
      body: {'text': text},
    );
    return sessionFromJson(json);
  }

  @override
  Future<List<VisualSearchSession>> sessions({int limit = 20}) async {
    final list = await getList(
      ApiEndpoints.visualSessions,
      query: {'limit': limit},
    );
    return list
        .whereType<Map>()
        .map((item) => sessionFromJson(Map<String, dynamic>.from(item)))
        .toList(growable: false);
  }

  @override
  Future<VisualSearchSession> session(String id) async {
    final json = await getJson(ApiEndpoints.visualSession(id));
    return sessionFromJson(json);
  }

  @override
  Future<void> forget(String id) =>
      deleteRequest(ApiEndpoints.visualSession(id));

  @override
  Future<StylistFeedback> sendFeedback({
    required String resultId,
    required StylistFeedback feedback,
  }) async {
    final json = await postJson(
      ApiEndpoints.visualResultFeedback(resultId),
      body: {'feedback': feedback.wire},
    );
    return StylistFeedback.fromWire(json['feedback']?.toString());
  }

  @override
  Future<List<VisualMatch>> similarTo(
    String productId, {
    int limit = 8,
    int? maxPriceSyp,
    bool sameCategory = false,
  }) async {
    final list = await getList(
      ApiEndpoints.visualSimilarProducts(productId),
      query: {
        'limit': limit,
        'max_price': ?maxPriceSyp,
        if (sameCategory) 'same_category': true,
      },
    );
    return matchesFromJson(list);
  }

  @override
  Future<TryOnCapability> tryOnCapability() async {
    final json = await getJson(ApiEndpoints.visualTryOnCapability);
    return tryOnCapabilityFromJson(json);
  }
}
