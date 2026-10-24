import 'package:ohara/core/result/result.dart';
import 'package:ohara/core/shared/entities/post.dart';

import 'package:ohara/features/home/domain/repositories/home_repository.dart';

class GetFeedUseCase {
  const GetFeedUseCase(this._repository);
  final HomeRepository _repository;

  Future<Result<List<Post>>> call() => _repository.getFeed();
}
