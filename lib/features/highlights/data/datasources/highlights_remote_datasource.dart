import 'package:reem/core/network/api_endpoints.dart';
import 'package:reem/core/network/base_remote_datasource.dart';
import 'package:reem/core/shared/models/story_model.dart';
import 'package:reem/features/highlights/data/models/highlight_model.dart';

/// `/highlights` — «الأبرز».
final class HighlightsRemoteDataSource extends BaseRemoteDataSource {
  const HighlightsRemoteDataSource(super.dio);

  /// One person's rail. Her own id returns empty shelves too, which nobody
  /// else is shown.
  Future<List<HighlightModel>> listFor(String? userId) async {
    final list = await getList(
      userId == null
          ? ApiEndpoints.highlightsMine
          : ApiEndpoints.highlightsOf(userId),
    );
    return _parse(list);
  }

  Future<HighlightModel> detail(String id) async =>
      HighlightModel.fromJson(await getJson(ApiEndpoints.highlightDetail(id)));

  /// Her own stories, live and expired — what a shelf can be filled from.
  Future<List<StoryModel>> archive() async {
    final list = await getList(ApiEndpoints.highlightsArchive);
    return list
        .whereType<Map>()
        .map((raw) => StoryModel.fromJson(Map<String, dynamic>.from(raw)))
        .toList(growable: false);
  }

  Future<HighlightModel> create({
    required String title,
    String? coverUrl,
    List<String> contentIds = const [],
  }) async {
    final json = await postJson(
      ApiEndpoints.highlights,
      body: {
        'title': title,
        'cover_url': ?coverUrl,
        if (contentIds.isNotEmpty) 'content_ids': contentIds,
      },
    );
    return HighlightModel.fromJson(json);
  }

  Future<HighlightModel> update(
    String id, {
    String? title,
    String? coverUrl,
  }) async {
    final json = await patchJson(
      ApiEndpoints.highlightById(id),
      body: {'title': ?title, 'cover_url': ?coverUrl},
    );
    return HighlightModel.fromJson(json);
  }

  Future<void> remove(String id) async {
    await deleteJson(ApiEndpoints.highlightById(id));
  }

  Future<HighlightModel> addItem(String id, String contentId) async {
    final json = await postJson(
      ApiEndpoints.highlightItems(id),
      body: {'content_id': contentId},
    );
    return HighlightModel.fromJson(json);
  }

  Future<HighlightModel> removeItem(String id, String contentId) async {
    final json = await deleteJson(ApiEndpoints.highlightItem(id, contentId));
    return HighlightModel.fromJson(json);
  }

  /// The whole rail in one request: dragging one shelf past another moves
  /// both, and two requests can leave a visibly half-applied order.
  Future<List<HighlightModel>> reorder(List<String> ids) async {
    final list = await patchList(
      ApiEndpoints.highlightsOrder,
      body: {'highlight_ids': ids},
    );
    return _parse(list);
  }

  List<HighlightModel> _parse(List<dynamic> list) => list
      .whereType<Map>()
      .map((raw) => HighlightModel.fromJson(Map<String, dynamic>.from(raw)))
      .toList(growable: false);
}
