import 'package:reem/core/network/api_endpoints.dart';
import 'package:reem/core/network/base_remote_datasource.dart';
import 'package:reem/core/shared/models/comment_model.dart';

import '../../models/comment_page_model.dart';
import '../../models/post_engagement_model.dart';
import '../post_social_remote_datasource.dart';

final class PostSocialRemoteDataSourceImpl extends BaseRemoteDataSource
    implements PostSocialRemoteDataSource {
  const PostSocialRemoteDataSourceImpl(super.dio);

  @override
  Future<CommentPageModel> getComments(
    String postId, {
    int page = 1,
    int limit = 20,
  }) async {
    final json = await getJson(
      ApiEndpoints.postComments(postId),
      query: {'page': page, 'limit': limit},
    );
    return CommentPageModel.fromJson(json);
  }

  @override
  Future<CommentModel> addComment(String postId, String content) async {
    final json = await postJson(
      ApiEndpoints.postComments(postId),
      body: {'content': content},
    );
    return CommentModel.fromJson(json);
  }

  @override
  Future<void> deleteComment(String postId, String commentId) =>
      deleteRequest(ApiEndpoints.postComment(postId, commentId));

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
