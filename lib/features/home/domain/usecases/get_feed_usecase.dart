import 'package:reem/core/result/result.dart';
import 'package:reem/core/shared/entities/post.dart';

import 'package:reem/features/home/domain/repositories/home_repository.dart';

class GetFeedUseCase {
  const GetFeedUseCase(this._repository);
  final HomeRepository _repository;

  Future<Result<List<Post>>> call() => _repository.getFeed();
}
