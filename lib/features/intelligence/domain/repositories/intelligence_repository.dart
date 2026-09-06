import 'package:reem/core/result/result.dart';
import 'package:reem/features/intelligence/domain/entities/intelligence_note.dart';

abstract interface class IntelligenceRepository {
  /// What Reem has to say about this product. Empty is the common case.
  Future<Result<List<IntelligenceNote>>> notes(String productId);
}
