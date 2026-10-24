import 'package:ohara/core/result/result.dart';
import 'package:ohara/core/shared/entities/comment.dart';

import 'package:ohara/features/social_posts/domain/entities/comment_page.dart';
import 'package:ohara/features/social_posts/domain/entities/comment_thread.dart';
import 'package:ohara/features/social_posts/domain/entities/post_engagement.dart';

abstract interface class PostSocialRepository {
  Future<Result<CommentPage>> getComments(
    CommentThread thread, {
    int page,
    int limit,
  });

  Future<Result<Comment>> addComment(CommentThread thread, String content);

  Future<Result<void>> deleteComment(CommentThread thread, String commentId);

  Future<Result<PostEngagement>> toggleLike(String postId);

  Future<Result<PostEngagement>> toggleSave(String postId);

  Future<Result<PostEngagement>> share(String postId);
}
