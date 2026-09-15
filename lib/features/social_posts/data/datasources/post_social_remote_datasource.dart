import 'package:reem/core/shared/models/comment_model.dart';
import 'package:reem/features/social_posts/data/models/comment_page_model.dart';
import 'package:reem/features/social_posts/data/models/post_engagement_model.dart';
import 'package:reem/features/social_posts/domain/entities/comment_thread.dart';

abstract interface class PostSocialRemoteDataSource {
  Future<CommentPageModel> getComments(
    CommentThread thread, {
    int page,
    int limit,
  });

  Future<CommentModel> addComment(CommentThread thread, String content);

  Future<void> deleteComment(CommentThread thread, String commentId);

  Future<PostEngagementModel> toggleLike(String postId);

  Future<PostEngagementModel> toggleSave(String postId);

  Future<PostEngagementModel> share(String postId);
}
