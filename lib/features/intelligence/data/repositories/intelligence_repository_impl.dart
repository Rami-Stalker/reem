import 'package:reem/core/base/repository_handler.dart';
import 'package:reem/core/result/result.dart';
import 'package:reem/features/intelligence/data/datasources/intelligence_remote_datasource.dart';
import 'package:reem/features/intelligence/domain/entities/intelligence_note.dart';
import 'package:reem/features/intelligence/domain/entities/size_fit.dart';
import 'package:reem/features/intelligence/domain/repositories/intelligence_repository.dart';

class IntelligenceRepositoryImpl
    with RepositoryHandler
    implements IntelligenceRepository {
  const IntelligenceRepositoryImpl(this.remote);

  final IntelligenceRemoteDataSource remote;

  @override
  Future<Result<List<IntelligenceNote>>> notes(String productId) =>
      guard(() => remote.notes(productId), operation: 'intelligence notes');

  @override
  Future<Result<List<SizeFit>>> sizeFit(String productId) =>
      guard(() => remote.sizeFit(productId), operation: 'size fit');
}
