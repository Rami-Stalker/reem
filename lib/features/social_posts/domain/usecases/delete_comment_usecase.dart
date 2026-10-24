import 'package:ohara/core/result/result.dart';
import 'package:ohara/features/social_posts/domain/entities/comment_thread.dart';

import 'package:ohara/features/social_posts/domain/repositories/post_social_repository.dart';

class DeleteCommentUseCase {
  const DeleteCommentUseCase(this._repository);
  final PostSocialRepository _repository;

  Future<Result<void>> call(CommentThread thread, String commentId) =>
      _repository.deleteComment(thread, commentId);
}
