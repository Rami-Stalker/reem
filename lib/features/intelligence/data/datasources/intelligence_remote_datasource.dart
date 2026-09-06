import 'package:reem/features/intelligence/domain/entities/intelligence_note.dart';

abstract interface class IntelligenceRemoteDataSource {
  Future<List<IntelligenceNote>> notes(String productId);
}
