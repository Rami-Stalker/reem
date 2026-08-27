import 'package:reem/core/shared/models/comment_model.dart';

import 'package:reem/features/social_posts/data/models/comment_page_model.dart';
import 'package:reem/features/social_posts/data/models/post_engagement_model.dart';

abstract interface class PostSocialRemoteDataSource {
  Future<CommentPageModel> getComments(String postId, {int page, int limit});

  Future<CommentModel> addComment(String postId, String content);

  Future<void> deleteComment(String postId, String commentId);

  Future<PostEngagementModel> toggleLike(String postId);

  Future<PostEngagementModel> toggleSave(String postId);

  Future<PostEngagementModel> share(String postId);
}
