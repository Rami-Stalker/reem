import 'package:reem/core/result/result.dart';
import 'package:reem/core/shared/entities/post.dart';

import '../repositories/create_repository.dart';

class CreatePostUseCase {
  const CreatePostUseCase(this._repository);
  final CreateRepository _repository;

  Future<Result<Post>> call({
    required String caption,
    required String productId,
  }) =>
      _repository.createPost(caption: caption, productId: productId);
}
