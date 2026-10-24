import 'package:ohara/core/result/result.dart';
import 'package:ohara/core/shared/entities/story.dart';

import 'package:ohara/features/home/domain/repositories/home_repository.dart';

class GetStoriesUseCase {
  const GetStoriesUseCase(this._repository);
  final HomeRepository _repository;

  Future<Result<List<Story>>> call() => _repository.getStories();
}
