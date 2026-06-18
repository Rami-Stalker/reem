import 'package:reem/core/result/result.dart';

import '../repositories/post_social_repository.dart';

class DeleteCommentUseCase {
  const DeleteCommentUseCase(this._repository);
  final PostSocialRepository _repository;

  Future<Result<void>> call(String postId, String commentId) =>
      _repository.deleteComment(postId, commentId);
}
