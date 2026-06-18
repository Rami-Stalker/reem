import '../../../../core/result/result.dart';
import '../entities/home_content.dart';
import '../repositories/home_content_repository.dart';

/// Fetches the aggregated home merchandising content.
class GetHomeContentUseCase {
  const GetHomeContentUseCase(this._repository);

  final HomeContentRepository _repository;

  Future<Result<HomeContent>> call() => _repository.getHomeContent();
}
