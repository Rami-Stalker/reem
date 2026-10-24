import 'package:ohara/core/result/result.dart';
import 'package:ohara/features/intelligence/domain/entities/intelligence_note.dart';
import 'package:ohara/features/intelligence/domain/entities/size_fit.dart';

abstract interface class IntelligenceRepository {
  /// What Ohara has to say about this product. Empty is the common case.
  Future<Result<List<IntelligenceNote>>> notes(String productId);

  /// How often each size was kept. Empty when nothing has sold yet.
  Future<Result<List<SizeFit>>> sizeFit(String productId);
}
