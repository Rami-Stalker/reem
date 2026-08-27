import 'package:reem/core/result/result.dart';
import 'package:reem/features/home/domain/entities/home_content.dart';
import 'package:reem/features/home/domain/repositories/home_content_repository.dart';

/// Fetches the aggregated home merchandising content.
class GetHomeContentUseCase {
  const GetHomeContentUseCase(this._repository);

  final HomeContentRepository _repository;

  Future<Result<HomeContent>> call() => _repository.getHomeContent();
}
