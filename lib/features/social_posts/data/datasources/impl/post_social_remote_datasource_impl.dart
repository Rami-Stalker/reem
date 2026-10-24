import 'package:ohara/core/network/api_endpoints.dart';
import 'package:ohara/core/network/base_remote_datasource.dart';
import 'package:ohara/core/shared/models/comment_model.dart';
import 'package:ohara/features/social_posts/data/datasources/post_social_remote_datasource.dart';
import 'package:ohara/features/social_posts/data/models/comment_page_model.dart';
import 'package:ohara/features/social_posts/data/models/post_engagement_model.dart';
import 'package:ohara/features/social_posts/domain/entities/comment_thread.dart';

final class PostSocialRemoteDataSourceImpl extends BaseRemoteDataSource
    implements PostSocialRemoteDataSource {
  const PostSocialRemoteDataSourceImpl(super.dio);

  /// One contract, two addresses — see [CommentThread].
  static String _comments(CommentThread thread) => switch (thread.kind) {
    CommentThreadKind.post => ApiEndpoints.postComments(thread.id),
    CommentThreadKind.product => ApiEndpoints.productComments(thread.id),
  };

  static String _comment(CommentThread thread, String commentId) =>
      switch (thread.kind) {
        CommentThreadKind.post => ApiEndpoints.postComment(thread.id, commentId),
        CommentThreadKind.product => ApiEndpoints.productComment(
          thread.id,
          commentId,
        ),
      };

  @override
  Future<CommentPageModel> getComments(
    CommentThread thread, {
    int page = 1,
    int limit = 20,
  }) async {
    final json = await getJson(
      _comments(thread),
      query: {'page': page, 'limit': limit},
    );
    return CommentPageModel.fromJson(json);
  }

  @override
  Future<CommentModel> addComment(CommentThread thread, String content) async {
    final json = await postJson(
      _comments(thread),
      body: {'content': content},
    );
    return CommentModel.fromJson(json);
  }

  @override
  Future<void> deleteComment(CommentThread thread, String commentId) =>
      deleteRequest(_comment(thread, commentId));

  @override
  Future<PostEngagementModel> toggleLike(String postId) async {
    final json = await postJson(ApiEndpoints.postLike(postId));
    return PostEngagementModel.fromJson(json);
  }

  @override
  Future<PostEngagementModel> toggleSave(String postId) async {
    final json = await postJson(ApiEndpoints.postSave(postId));
    return PostEngagementModel.fromJson(json);
  }

  @override
  Future<PostEngagementModel> share(String postId) async {
    final json = await postJson(ApiEndpoints.postShare(postId));
    return PostEngagementModel.fromJson(json);
  }
}
