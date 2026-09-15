import 'package:reem/core/result/result.dart';
import 'package:reem/core/shared/entities/comment.dart';
import 'package:reem/features/social_posts/domain/entities/comment_thread.dart';

import 'package:reem/features/social_posts/domain/repositories/post_social_repository.dart';

class AddCommentUseCase {
  const AddCommentUseCase(this._repository);
  final PostSocialRepository _repository;

  Future<Result<Comment>> call(CommentThread thread, String content) =>
      _repository.addComment(thread, content);
}
