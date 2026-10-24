import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ohara/core/network/api_endpoints.dart';
import 'package:ohara/core/presentation/providers/core_providers.dart';

final aiHomeFeedProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final dio = ref.watch(dioProvider);
  final response = await dio.get<dynamic>(ApiEndpoints.aiHomeFeed);
  return response.data is Map
      ? Map<String, dynamic>.from(response.data as Map)
      : <String, dynamic>{};
});

final aiSmartSuggestionsProvider =
    FutureProvider.family<List<String>, String>((ref, query) async {
  final dio = ref.watch(dioProvider);
  final response = await dio.get<dynamic>(
    ApiEndpoints.aiSearchSuggestions,
    queryParameters: {'q': query},
  );
  final data = response.data;
  if (data is! List) return const [];
  return data
      .whereType<Map>()
      .map((item) => (item['text'] ?? '').toString())
      .where((text) => text.isNotEmpty)
      .toList();
});

final aiSimilarProductsProvider =
    FutureProvider.family<List<Map<String, dynamic>>, String>((ref, productId) async {
  final dio = ref.watch(dioProvider);
  final response = await dio.get<dynamic>(
    ApiEndpoints.aiSimilarProducts(productId),
  );
  final data = response.data;
  if (data is! List) return const [];
  return data
      .whereType<Map>()
      .map((item) => Map<String, dynamic>.from(item))
      .toList();
});

final aiAssistantActionsProvider = Provider<AiAssistantActions>((ref) {
  return AiAssistantActions(ref.watch(dioProvider));
});

class AiAssistantActions {
  const AiAssistantActions(this._dio);

  final Dio _dio;

  Future<Map<String, dynamic>> generateDescription({
    required String title,
    required String category,
    String? productId,
    String? tone,
    String? audience,
    List<String> attributes = const [],
  }) async {
    final response = await _dio.post<dynamic>(
      ApiEndpoints.aiGenerateProductDescription,
      data: {
        'title': title,
        'category': category,
        'product_id': ?productId,
        'tone': ?tone,
        'audience': ?audience,
        if (attributes.isNotEmpty) 'attributes': attributes,
      },
    );
    return response.data is Map
        ? Map<String, dynamic>.from(response.data as Map)
        : <String, dynamic>{};
  }

  Future<List<String>> generateTags({
    required String title,
    required String category,
    String? productId,
    String? description,
    List<String> seedTags = const [],
  }) async {
    final response = await _dio.post<dynamic>(
      ApiEndpoints.aiGenerateTags,
      data: {
        'title': title,
        'category': category,
        'product_id': ?productId,
        'description': ?description,
        if (seedTags.isNotEmpty) 'seed_tags': seedTags,
      },
    );
    final data = response.data;
    if (data is! Map || data['tags'] is! List) return const [];
    return (data['tags'] as List).map((tag) => tag.toString()).toList();
  }
}
