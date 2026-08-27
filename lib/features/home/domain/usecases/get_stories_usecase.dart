import 'package:reem/core/result/result.dart';
import 'package:reem/core/shared/entities/story.dart';

import 'package:reem/features/home/domain/repositories/home_repository.dart';

class GetStoriesUseCase {
  const GetStoriesUseCase(this._repository);
  final HomeRepository _repository;

  Future<Result<List<Story>>> call() => _repository.getStories();
}
