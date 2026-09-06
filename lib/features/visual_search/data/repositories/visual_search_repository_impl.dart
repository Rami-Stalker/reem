import 'dart:typed_data';

import 'package:reem/core/base/repository_handler.dart';
import 'package:reem/core/result/result.dart';
import 'package:reem/features/ai_stylist/domain/entities/stylist_recommendation.dart';
import 'package:reem/features/visual_search/data/datasources/visual_search_remote_datasource.dart';
import 'package:reem/features/visual_search/domain/entities/visual_match.dart';
import 'package:reem/features/visual_search/domain/entities/visual_search_session.dart';
import 'package:reem/features/visual_search/domain/repositories/visual_search_repository.dart';

class VisualSearchRepositoryImpl
    with RepositoryHandler
    implements VisualSearchRepository {
  const VisualSearchRepositoryImpl(this.remote);

  final VisualSearchRemoteDataSource remote;

  @override
  Future<Result<VisualSearchBootstrap>> bootstrap() => guard(remote.bootstrap);

  @override
  Future<Result<VisualSearchSession>> search({
    required Uint8List bytes,
    required String filename,
    required VisualSearchSource source,
    String? note,
    void Function(double progress)? onProgress,
  }) => guard(
    () => remote.search(
      bytes: bytes,
      filename: filename,
      source: source,
      note: note,
      onProgress: onProgress,
    ),
    operation: 'visual search',
  );

  @override
  Future<Result<VisualSearchSession>> refine({
    required String sessionId,
    required String text,
  }) => guard(
    () => remote.refine(sessionId: sessionId, text: text),
    operation: 'visual refinement',
  );

  @override
  Future<Result<List<VisualSearchSession>>> sessions({int limit = 20}) =>
      guard(() => remote.sessions(limit: limit));

  @override
  Future<Result<VisualSearchSession>> session(String id) =>
      guard(() => remote.session(id));

  @override
  Future<Result<void>> forget(String id) => guard(() => remote.forget(id));

  @override
  Future<Result<StylistFeedback>> sendFeedback({
    required String resultId,
    required StylistFeedback feedback,
  }) => guard(
    () => remote.sendFeedback(resultId: resultId, feedback: feedback),
  );

  @override
  Future<Result<List<VisualMatch>>> similarTo(
    String productId, {
    int limit = 8,
    int? maxPriceSyp,
    bool sameCategory = false,
  }) => guard(
    () => remote.similarTo(
      productId,
      limit: limit,
      maxPriceSyp: maxPriceSyp,
      sameCategory: sameCategory,
    ),
  );

  @override
  Future<Result<TryOnCapability>> tryOnCapability() =>
      guard(remote.tryOnCapability);
}
