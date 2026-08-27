import 'package:reem/core/result/result.dart';
import 'package:reem/core/shared/entities/comment.dart';

import 'package:reem/features/social_posts/domain/entities/comment_page.dart';
import 'package:reem/features/social_posts/domain/entities/post_engagement.dart';

abstract interface class PostSocialRepository {
  Future<Result<CommentPage>> getComments(
    String postId, {
    int page,
    int limit,
  });

  Future<Result<Comment>> addComment(String postId, String content);

  Future<Result<void>> deleteComment(String postId, String commentId);

  Future<Result<PostEngagement>> toggleLike(String postId);

  Future<Result<PostEngagement>> toggleSave(String postId);

  Future<Result<PostEngagement>> share(String postId);
}
