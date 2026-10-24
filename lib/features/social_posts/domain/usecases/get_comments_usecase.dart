import 'package:ohara/core/result/result.dart';

import 'package:ohara/features/social_posts/domain/entities/comment_page.dart';
import 'package:ohara/features/social_posts/domain/entities/comment_thread.dart';
import 'package:ohara/features/social_posts/domain/repositories/post_social_repository.dart';

class GetCommentsUseCase {
  const GetCommentsUseCase(this._repository);
  final PostSocialRepository _repository;

  Future<Result<CommentPage>> call(CommentThread thread, {int page = 1}) =>
      _repository.getComments(thread, page: page);
}
