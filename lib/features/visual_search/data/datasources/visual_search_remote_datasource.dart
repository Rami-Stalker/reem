import 'dart:typed_data';

import 'package:reem/features/ai_stylist/domain/entities/stylist_recommendation.dart';
import 'package:reem/features/visual_search/domain/entities/visual_match.dart';
import 'package:reem/features/visual_search/domain/entities/visual_search_session.dart';

abstract interface class VisualSearchRemoteDataSource {
  Future<VisualSearchBootstrap> bootstrap();

  Future<VisualSearchSession> search({
    required Uint8List bytes,
    required String filename,
    required VisualSearchSource source,
    String? note,
    void Function(double progress)? onProgress,
  });

  Future<VisualSearchSession> refine({
    required String sessionId,
    required String text,
  });

  Future<List<VisualSearchSession>> sessions({int limit});

  Future<VisualSearchSession> session(String id);

  Future<void> forget(String id);

  Future<StylistFeedback> sendFeedback({
    required String resultId,
    required StylistFeedback feedback,
  });

  Future<List<VisualMatch>> similarTo(
    String productId, {
    int limit,
    int? maxPriceSyp,
    bool sameCategory,
  });

  Future<TryOnCapability> tryOnCapability();
}
