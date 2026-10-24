import 'dart:typed_data';

import 'package:ohara/core/result/result.dart';
import 'package:ohara/features/ai_stylist/domain/entities/stylist_recommendation.dart';
import 'package:ohara/features/visual_search/domain/entities/visual_match.dart';
import 'package:ohara/features/visual_search/domain/entities/visual_search_session.dart';

/// Ohara Visual Shopping, from the app's side.
///
/// One method per thing she does, and nothing that leaks the transport. The
/// photograph travels as bytes rather than as a path: the picker's temporary
/// file can be cleared by the OS mid-flight, and a retry that finds the file
/// gone is worse than the memory one image costs — the same reasoning
/// `MediaUploadService` already applies to product photographs.
abstract interface class VisualSearchRepository {
  Future<Result<VisualSearchBootstrap>> bootstrap();

  /// Upload a photograph and get the matches back in one round trip.
  ///
  /// [note] is a sentence typed with the upload; the server folds it on as a
  /// refinement using the same path a later sentence takes.
  Future<Result<VisualSearchSession>> search({
    required Uint8List bytes,
    required String filename,
    required VisualSearchSource source,
    String? note,
    void Function(double progress)? onProgress,
  });

  /// Fold one sentence onto an existing search.
  ///
  /// Runs against the descriptor the server already stored, so this works even
  /// after her photograph has been deleted by the retention clock.
  Future<Result<VisualSearchSession>> refine({
    required String sessionId,
    required String text,
  });

  Future<Result<List<VisualSearchSession>>> sessions({int limit = 20});

  Future<Result<VisualSearchSession>> session(String id);

  /// Delete the search and the photograph behind it, now.
  Future<Result<void>> forget(String id);

  Future<Result<StylistFeedback>> sendFeedback({
    required String resultId,
    required StylistFeedback feedback,
  });

  /// "قطع شبيهة" for a product page.
  Future<Result<List<VisualMatch>>> similarTo(
    String productId, {
    int limit,
    int? maxPriceSyp,
    bool sameCategory,
  });

  /// Whether virtual try-on can actually render anything.
  Future<Result<TryOnCapability>> tryOnCapability();
}
