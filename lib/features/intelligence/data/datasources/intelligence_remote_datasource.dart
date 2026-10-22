import 'package:reem/features/intelligence/domain/entities/intelligence_note.dart';
import 'package:reem/features/intelligence/domain/entities/size_fit.dart';

abstract interface class IntelligenceRemoteDataSource {
  Future<List<IntelligenceNote>> notes(String productId);

  Future<List<SizeFit>> sizeFit(String productId);
}
