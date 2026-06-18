import 'package:reem/core/result/result.dart';

import '../entities/comment_page.dart';
import '../repositories/post_social_repository.dart';

class GetCommentsUseCase {
  const GetCommentsUseCase(this._repository);
  final PostSocialRepository _repository;

  Future<Result<CommentPage>> call(String postId, {int page = 1}) =>
      _repository.getComments(postId, page: page);
}
